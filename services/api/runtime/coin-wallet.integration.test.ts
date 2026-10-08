import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,createHmac} from 'node:crypto';
import {PostgresDatabase} from './postgres';
import {LivePayments} from './live-payments';
import {TestPayments} from './test-payments';
import {CoinWallet,coinPacks,coinCost} from './coin-wallet';
import {issueChartTicket} from '../lib/chart-ticket';
for(const mode of ['test','live'] as const)test(mode+' wallet: packs, concurrent captures, quotes, spending, upgrade, retries, refunds and erasure',async()=>{
 const url=process.env.DATABASE_URL!;if(!url?.includes('jyotara_qa_payments'))throw Error('Isolated QA database required');
 const db=new PostgresDatabase(url),token='c'.repeat(64),other='d'.repeat(64),tester='qa-coins';
 const env={JYOTARA_LIVE_PAYMENTS_ENABLED:'true',RAZORPAY_LIVE_KEY_ID:'rzp_live_synthetic',RAZORPAY_LIVE_KEY_SECRET:'qa-private-secret-never-rendered',RAZORPAY_LIVE_WEBHOOK_SECRET:'live-hook',JYOTARA_TEST_PAYMENTS_ENABLED:'true',JYOTARA_COIN_WALLET_ENABLED:'true',RAZORPAY_MODE:'test',RAZORPAY_KEY_ID:'rzp_test_synthetic',RAZORPAY_KEY_SECRET:'qa-private-secret-never-rendered',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64)};
 let qrCreates=0;const qrPayments=new Map<string,any[]>();let creates=0;const providerOrders=new Map<string,any>();
 const gateway=new (mode==='live'?LivePayments:TestPayments)(db,env,async(input,options)=>{
  if(String(input).endsWith('/payments/qr_codes')){qrCreates++;const q={id:'qr_wallet'+qrCreates,...JSON.parse(options!.body as string),image_url:'https://rzp.io/i/synthetic',status:'active'};qrPayments.set(q.id,[]);return Response.json(q);}
  const match=/qr_codes\/(qr_[A-Za-z0-9]+)\/payments$/.exec(String(input));if(match)return Response.json({items:qrPayments.get(match[1])??[]});
  if(String(input).endsWith('/orders')){creates++;const row={id:'order_wallet'+creates,...JSON.parse(options!.body as string)};providerOrders.set(row.id,row);return Response.json(row);}throw Error('Unexpected provider call');
 });
 const wallet=new CoinWallet(db,env,gateway,mode);
 const req=(action:string,body:object={},bearer=token)=>new Request('https://example.test/api/wallet/'+action,{method:'POST',headers:{authorization:'Bearer '+bearer},body:JSON.stringify(body)});
 const status=async()=>(await (await wallet.handle(req('status'),tester)).json()) as any;
 const quote=async(action:string,payload:any)=>{const r=await wallet.handle(req('quote',{action,payload}),tester);assert.equal(r.status,200,await r.clone().text());return await r.json() as any;};
 const run=async(action:string,body:any,handler:any=async()=>Response.json({answer:'Synthetic complete reading.',answerMode:'provider_reading',score:20}))=>{const q=await quote(action,body);return wallet.run(req(action,{...body,coinQuote:q.quote}),'qa-coins-a',action,handler);};
 const question=(id:string,patch:any={})=>({requestId:'wallet-request-'+id,profileId:'p1',question:'How is my career?',category:'Career',depth:'standard',guide:'Vetri',responseStyle:'english',language:'en',...patch});
 try{
  await db.pool.query("DELETE FROM phone_login_sessions WHERE tester_key=$1",[tester]);await db.pool.query("DELETE FROM phone_accounts WHERE id IN ('qa-coins-a','qa-coins-b')");
  for(const [id,t]of [['qa-coins-a',token],['qa-coins-b',other]]){await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[id,'0000',Date.now()]);await db.pool.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[createHash('sha256').update(t).digest('hex'),id,tester,Date.now()+600000]);}
  assert.deepEqual(coinPacks.map(p=>[p.rupees,p.coins]),[[49,50],[149,200],[299,450],[499,800],[999,1800]]);assert.equal(coinCost('Marriage','detailed'),30);
  assert.equal((await status()).balance,0);assert.equal((await status()).mode,mode);
  const opposite=new CoinWallet(db,env,gateway,mode==='live'?'test':'live');
  await db.pool.query(`INSERT INTO ${opposite.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,created_at,updated_at) VALUES('opposite','qa-coins-a','opposite-request','regular',14900,200,200,'paid',1,1)`);
  assert.equal((await status()).balance,0);
  const crossBody=question('mode-cross');
  const crossQuote:any=await (await opposite.handle(req('quote',{action:'guidance',payload:crossBody}),tester)).json();
  assert.equal((await wallet.run(req('guidance',{...crossBody,coinQuote:crossQuote.quote}),'qa-coins-a','guidance',async()=>{throw Error('Cross-mode quote');})).status,409);

  const purchase={requestId:'wallet-purchase-0001',packId:'regular'};
  const rs=await Promise.all(Array.from({length:5},()=>wallet.handle(req('create',purchase),tester)));assert.equal(creates,1);const order:any=await rs.find(r=>r.status===200)!.json();assert.equal(order.amount,14900);
  const p={id:'pay_wallet1',order_id:order.orderId,amount:14900,currency:'INR',status:'captured',captured:true,amount_refunded:0};
  await Promise.all(Array.from({length:6},()=>wallet.recordPayment(p)));assert.equal((await status()).balance,200);
  assert.equal((await wallet.handle(req('verify',{id:order.id,paymentId:p.id,signature:'a'.repeat(64)},other),tester)).status,404);
  await assert.rejects(()=>wallet.recordPayment({...p,amount:1}));assert.equal((await status()).balance,200);
  const intro=question('intro',{question:'Tell me about my marriage.',category:'Marriage',guide:'Nila',responseStyle:'tanglish'});assert.equal((await quote('guidance',intro)).cost,0);const first:any=await (await run('guidance',intro)).json();assert.equal(first.wallet.coins,0);assert.equal(first.wallet.trial,true);assert.equal(first.wallet.status,'complete');assert.equal((await quote('guidance',question('second-relationship',{question:'Tell me about my marriage.',category:'Marriage',guide:'Nila',responseStyle:'tanglish'}))).cost,15);assert.equal((await status()).balance,200);
  // JYOT-26: same guide/language, introductory receipt followed by exactly one paid charge.
  await db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,payment_method,created_at,updated_at) VALUES('qa-b-credit','qa-coins-b','qa-b-credit','regular',14900,100,100,'paid','review_grant',1,1)`);
  const relationshipB=async(id:string,handler:any=async()=>Response.json({answer:'Complete relationship reading.',answerMode:'provider_reading'}),guide='Nila')=>{
   const b=question(id,{question:'Tell me about my marriage.',category:'Marriage',guide,responseStyle:'tanglish'});
   const qr=await wallet.handle(req('quote',{action:'guidance',payload:b},other),tester);
   assert.equal(qr.status,200);const quoteB:any=await qr.json();
   const response=await wallet.run(req('guidance',{...b,coinQuote:quoteB.quote},other),'qa-coins-b','guidance',handler);
   assert.equal(response.status,200);return await response.json() as any;
  };
  const freeB=await relationshipB('nila-b-first');assert.equal(freeB.wallet.trial,true);assert.equal(freeB.wallet.coins,0);
  const paidB=await relationshipB('nila-b-second');assert.equal(paidB.wallet.trial,false);assert.equal(paidB.wallet.coins,15);
  await relationshipB('nila-b-second');
  const failedB=await relationshipB('nila-b-failed',async()=>Response.json({answer:'Unavailable.',answerMode:'reading_unavailable'}),'Janaki');assert.equal(failedB.wallet.status,'failed');assert.equal(failedB.wallet.coins,0);assert.equal(failedB.wallet.trial,false);
  const janakiB=await relationshipB('janaki-b-paid',undefined,'Janaki');assert.equal(janakiB.wallet.coins,15);assert.equal(janakiB.wallet.status,'complete');
  const generalB=await relationshipB('nila-b-general',async()=>Response.json({answer:'Useful general help.',answerMode:'limited_guidance'}));assert.equal(generalB.wallet.coins,0);assert.equal(generalB.wallet.freeReason,'general_guidance');
  const statusB:any=await (await wallet.handle(req('status',{},other),tester)).json();assert.equal(statusB.balance,70);
  const body=question('paid',{conversationHistory:[{role:'user',content:'Earlier career context.'}],previousUserMessages:['Earlier career context.']});const q=await quote('guidance',body);assert.equal(q.cost,10);
  const tampered=await wallet.run(req('guidance',{...body,depth:'detailed',coinQuote:q.quote}),'qa-coins-a','guidance',async()=>{throw Error('Should not run');});assert.equal(tampered.status,409);
  const answers=await Promise.all(Array.from({length:5},()=>wallet.run(req('guidance',{...body,coinQuote:q.quote}),'qa-coins-a','guidance',async()=>Response.json({answer:'Synthetic.',answerMode:'provider_reading'}))));assert.ok(answers.every(r=>r.status===200));assert.equal((await status()).balance,190);
  const parent:any=await answers[0].json();assert.equal(parent.wallet.trial,false);assert.equal(parent.wallet.coins,10);const upgrade=question('upgrade',{depth:'detailed',upgradeFrom:parent.wallet.id});assert.equal((await quote('guidance',upgrade)).cost,10);await run('guidance',{...upgrade,conversationHistory:[{role:'user',content:'Later unrelated context.'}]},async(request:Request)=>{const sent:any=await request.json();assert.deepEqual(sent.conversationHistory,body.conversationHistory);assert.deepEqual(sent.previousUserMessages,body.previousUserMessages);return Response.json({answer:'Detailed synthetic answer.',answerMode:'provider_reading'});});assert.equal((await status()).balance,180);
  const dupe=await wallet.handle(req('quote',{action:'guidance',payload:question('upgrade-again',{depth:'detailed',upgradeFrom:parent.wallet.id})}),tester);assert.equal(dupe.status,422);
  const changed=await wallet.handle(req('quote',{action:'guidance',payload:question('upgrade-other',{profileId:'p2',depth:'detailed',upgradeFrom:first.wallet.id})}),tester);assert.equal(changed.status,422);
  const love=question('love',{question:'Tell me about my marriage.',category:'Career',depth:'detailed'});assert.equal((await quote('guidance',love)).cost,30);await run('guidance',love);assert.equal((await status()).balance,150);
  await run('guidance',question('failed'),async()=>Response.json({answer:'Unavailable.',answerMode:'reading_unavailable'}));assert.equal((await status()).balance,150);
  // Installed clients quote with phone auth only, then send with a chart cookie.
  const unknownSession='qa-quote-unknown-'+mode;
  await db.pool.query('INSERT INTO phone_profile_owners(session_id,account_id) VALUES($1,$2)',[unknownSession,'qa-coins-a']);
  const unknown=question('unknown-cookie',{profileId:'unknown-profile',chartTicket:await issueChartTicket(env.JYOTARA_CHART_TICKET_KEY,{sessionId:unknownSession,profileId:'unknown-profile',birthTimeKnown:false,chart:{rashi:'Meena',planets:[],yogas:[]}})});
  const unknownQuote=await quote('guidance',unknown);assert.equal(unknownQuote.cost,0);assert.equal(unknownQuote.trial,false);
  const unknownRequest=new Request('https://example.test/api/guidance',{method:'POST',headers:{authorization:'Bearer '+token,Cookie:'nirayana_pilot_session='+unknownSession},body:JSON.stringify({...unknown,coinQuote:unknownQuote.quote})});
  const limited:any=await (await wallet.run(unknownRequest,'qa-coins-a','guidance',async()=>Response.json({answer:'General guidance.',answerMode:'limited_guidance'}))).json();
  assert.equal(limited.wallet.coins,0);assert.equal(limited.wallet.status,'complete');assert.equal((await status()).balance,150);
  const otherQuote:any=await (await wallet.handle(req('quote',{action:'guidance',payload:{...unknown,requestId:'other-unknown-quote'},},other),tester)).json();assert.equal(otherQuote.cost,10);
  await db.pool.query('INSERT INTO deleted_chart_sessions(session_id,expires_at) VALUES($1,$2)',[unknownSession,Date.now()+60000]);
  assert.equal((await quote('guidance',{...unknown,requestId:'deleted-unknown-quote'})).cost,10);
  await db.pool.query('DELETE FROM deleted_chart_sessions WHERE session_id=$1',[unknownSession]);
  await db.pool.query('DELETE FROM phone_profile_owners WHERE session_id=$1',[unknownSession]);
  let calls=0;const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:true};const match={boy:birth,girl:{...birth,datetime:'2001-05-18T08:30:00+05:30'},consent:true,language:'en'};const mh=async()=>{calls++;return Response.json({score:20,language:'en',factors:[]});};await run('matching',match,mh);await run('matching',match,mh);assert.equal(calls,1);assert.equal((await status()).balance,130);
  await run('matching',{...match,language:'ta',boy:{...match.boy,nickname:'Renamed'}},mh);assert.equal(calls,1);assert.equal((await status()).balance,130);
  const match2={...match,girl:{...match.girl,latitude:12.97}};await run('matching',match2,async()=>Response.json({error:'Unavailable'},{status:503}));assert.equal((await status()).balance,130);await run('matching',match2,mh);assert.equal((await status()).balance,110);
  // No spend without a quote; account-bound quotes cannot cross accounts.
  assert.equal((await wallet.run(req('guidance',question('no-quote')),'qa-coins-a','guidance',async()=>{throw Error('Must not run');})).status,409);
  const ownQuote=await quote('guidance',question('cross-account'));
  assert.equal((await wallet.run(req('guidance',{...question('cross-account'),coinQuote:ownQuote.quote},other),'qa-coins-b','guidance',async()=>{throw Error('Must not run');})).status,409);
  assert.equal((await quote('guidance',question('safety',{question:'I feel suicidal and need help.'}))).cost,0);
  // Distinct requests racing for the final coins must not overspend.
  const before=await status();
  const burst=await Promise.all(Array.from({length:8},async(_,i)=>{const b=question('burst-'+i,{depth:'detailed'});const q=await quote('guidance',b);return wallet.run(req('guidance',{...b,coinQuote:q.quote}),'qa-coins-a','guidance',async()=>Response.json({answer:'Synthetic.',answerMode:'provider_reading'}));}));
  assert.equal(burst.filter(r=>r.status===200).length,Math.floor(before.balance/20));assert.equal((await status()).balance,before.balance%20);
  const second:any=await (await wallet.handle(req('create',{requestId:'wallet-purchase-0002',packId:'starter'}),tester)).json();await wallet.recordPayment({id:'pay_wallet2',order_id:second.orderId,amount:4900,currency:'INR',status:'captured',captured:true,amount_refunded:0});assert.equal((await status()).balance,60);
  await wallet.recordPayment({...p,status:'refunded',amount_refunded:14900});assert.equal((await status()).balance,50);await wallet.recordPayment(p);assert.equal((await status()).balance,50);
  assert.equal((await status()).orders.find((o:any)=>o.id===order.id).refund_review,1);
  const checkoutUrl=wallet.checkoutUrl(order.id), checkoutToken=checkoutUrl.split('/').pop()!;
  const page=await wallet.checkout(new Request(checkoutUrl),checkoutToken);
  assert.equal(page.status,200);const html=await page.text();assert.ok(html.includes('checkout.razorpay.com/v1/checkout.js'));assert.ok(!html.includes(wallet.keySecret!));
  assert.equal((await wallet.checkout(new Request(checkoutUrl),checkoutToken+'x')).status,403);
  assert.equal((await opposite.checkout(new Request(checkoutUrl),checkoutToken)).status,403);
  const expiredData=Buffer.from(JSON.stringify({id:order.id,mode,expires:Date.now()-1})).toString('base64url');
  assert.equal((await wallet.checkout(new Request(checkoutUrl),expiredData+'.'+createHmac('sha256',wallet.secret).update('checkout:'+expiredData).digest('hex'))).status,403);
  assert.equal((await wallet.checkout(new Request(checkoutUrl,{method:'POST',body:JSON.stringify({paymentId:'pay_fake',signature:'fake'})}),checkoutToken)).status,400);
  const beforeQr=(await status()).balance;
  const qrReq={requestId:'wallet-purchase-qr-001',packId:'starter',paymentMethod:'qr'};
  const qr:any=await (await wallet.handle(req('create',qrReq),tester)).json();assert.equal(qr.amount,4900);assert.equal(qrCreates,1);
  const again:any=await (await wallet.handle(req('create',qrReq),tester)).json();assert.equal(again.qrId,qr.qrId);assert.equal(qrCreates,1);
  assert.equal((await wallet.handle(req('create',{...qrReq,paymentMethod:'checkout'}),tester)).status,409);
  assert.equal((await wallet.handle(req('refresh',{id:qr.id},other),tester)).status,404);
  const qp={id:'pay_qrwallet',order_id:null,amount:4900,currency:'INR',status:'captured',captured:true,amount_refunded:0};
  await assert.rejects(()=>wallet.recordQrPayment(qp,qr.qrId));assert.equal((await status()).balance,beforeQr);
  qrPayments.set(qr.qrId,[qp]);
  await wallet.recordQrPayment({...qp,status:'failed',captured:false},qr.qrId);
  assert.equal((await status()).orders.find((o:any)=>o.id===qr.id).status,'created');
  await assert.rejects(()=>wallet.recordQrPayment({...qp,amount:1},qr.qrId));
  await Promise.all(Array.from({length:5},()=>wallet.recordQrPayment(qp,qr.qrId)));assert.equal((await status()).balance,beforeQr+50);
  await wallet.recordPayment({...qp,status:'refunded',amount_refunded:4900});assert.equal((await status()).balance,beforeQr);
  await wallet.recordQrPayment(qp,qr.qrId);assert.equal((await status()).balance,beforeQr);
  if(mode==='live'){
   await assert.rejects(()=>db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,payment_method,created_at,updated_at) VALUES('invalid-free','qa-coins-a','invalid-free','starter',0,500,500,'paid','checkout',1,1)`));
   const beforeGrant=(await status()).balance;
   await db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,payment_method,created_at,updated_at) VALUES('review-qa','qa-coins-a','review-qa','review',0,500,500,'paid','review_grant',1,1)`);
   assert.equal((await status()).balance,beforeGrant+500);
   const grant=(await status()).orders.find((o:any)=>o.id==='review-qa');assert.equal(grant.amount,0);assert.equal(grant.status,'complimentary');
   assert.equal((await wallet.handle(req('refresh',{id:'review-qa'}),tester)).status,200);
   assert.equal((await wallet.handle(req('refresh',{id:'review-qa'},other),tester)).status,404);
   const used=await run('guidance',question('review-credit',{depth:'detailed'}));assert.equal(used.status,200);assert.equal((await status()).balance,beforeGrant+480);
  }
  // Raw birth details/questions must not appear in the wallet database.
  const rows=(await db.pool.query(`SELECT * FROM ${wallet.usageTable} WHERE account_id='qa-coins-a'`)).rows;assert.ok(!JSON.stringify(rows).includes('How is my career?'));assert.ok(!JSON.stringify(rows).includes('synthetic-one'));
  await db.pool.query('DELETE FROM phone_login_sessions WHERE tester_key=$1',[tester]);await db.pool.query("DELETE FROM phone_accounts WHERE id IN ('qa-coins-a','qa-coins-b')");assert.equal((await db.pool.query(`SELECT count(*) n FROM ${wallet.usageTable} WHERE account_id='qa-coins-a'`)).rows[0].n,0);
 }finally{await db.close();}
});
