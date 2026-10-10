import test from 'node:test';
import assert from 'node:assert/strict';
import {PostgresDatabase} from './postgres';
import {CoinWallet} from './coin-wallet';

for(const mode of ['test','live'] as const)test(mode+' introductory trial: eligibility, latency, expiry, recovery, zero coins and ownership',async()=>{
 if(!process.env.DATABASE_URL?.includes('jyotara_qa_trial147'))throw Error('Isolated trial QA database required');
 const db=new PostgresDatabase(process.env.DATABASE_URL),owner='intro147-'+mode;
 const wallet=new CoinWallet(db,{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64)},{configured:()=>true,account:async()=>owner,provider:async()=>{throw Error('No payments permitted');}},mode);
 const actual=Date.now;let now=actual();Date.now=()=>now;
 const req=(action:string,body:any)=>new Request('https://example.test/api/wallet/'+action,{method:'POST',headers:{'x-jyotara-wallet-catalog':'2'},body:JSON.stringify(body)});
 const trial=async(operation:string,patch:any={})=>await wallet.handle(req('intro-trial',{operation,...patch}),'qa');
 const snapshot=async()=>await (await trial('status')).json() as any;
 const question=(id:string,patch:any={})=>({requestId:'intro-question-'+id,profileId:'profile1',guide:'Meera',question:'What does my chart suggest about love?',category:'Love',depth:'standard',responseMode:'conversation',responseStyle:'tanglish',language:'ta',billingVersion:2,billingSession:'a'.repeat(32),...patch});
 const quote=async(body:any)=>await wallet.handle(req('quote',{action:'guidance',payload:body}),'qa');
 const run=async(body:any,handler:any=async()=>Response.json({answer:'Useful reading.',answerMode:'provider_reading'}))=>{
  const q:any=await (await quote(body)).json();assert.ok(q.quote,q.error);
  return wallet.run(req('guidance',{...body,coinQuote:q.quote}),owner,'guidance',handler);
 };
 try{
  await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[owner,'0000',now]);
  assert.equal((await snapshot()).state,'available');
  assert.equal((await trial('offer')).status,200);
  assert.equal((await trial('start',{billingSession:'a'.repeat(32),guide:'Meera'})).status,200);
  const resumed:any=await (await trial('start',{billingSession:'b'.repeat(32),guide:'Nila'})).json();
  assert.equal(resumed.billingSession,'a'.repeat(32));assert.equal(resumed.guide,'Meera');
  now+=600000;assert.equal((await snapshot()).started,false);assert.equal((await snapshot()).remainingMs,60000);
  const unavailable:any=await (await run(question('failed'),async()=>Response.json({answer:'Unavailable.',answerMode:'reading_unavailable'}))).json();
  assert.equal(unavailable.wallet.status,'failed');assert.equal((await snapshot()).started,false);
  const first:any=await (await run(question('first'),async()=>{now+=120000;return Response.json({answer:'Useful reading.',answerMode:'provider_reading'});})).json();
  assert.equal(first.wallet.coins,0);assert.equal(first.wallet.trial,true);assert.equal(first.wallet.introTrial.remainingMs,60000);assert.equal(await wallet.balance(db.pool,owner),0);
  now+=10000;
  await run(question('second'),async()=>{now+=90000;assert.equal((await snapshot()).remainingMs,50000);assert.equal((await snapshot()).pending,true);return Response.json({answer:'Useful follow-up.',answerMode:'provider_reading'});});
  assert.equal((await snapshot()).remainingMs,50000);
  // Editing owned birth details keeps the remaining trial, not another minute.
  await run(question('edited',{profileId:'profile2'}));assert.equal((await snapshot()).remainingMs,50000);
  assert.equal((await quote(question('wrong-guide',{guide:'Nila'}))).status,422);
  const legitimate:any=await (await quote(question('ownership',{profileId:'profile2'}))).json();
  assert.equal((await wallet.run(req('guidance',{...question('ownership',{profileId:'profile2'}),coinQuote:legitimate.quote}),owner+'-foreign','guidance',async()=>{throw Error('Foreign account ran');})).status,409);
  now+=50001;
  const expired=await quote(question('expired',{profileId:'profile2'}));assert.equal(expired.status,422);assert.equal((await expired.json() as any).code,'intro_trial_ended');
  assert.equal((await snapshot()).state,'ended');assert.equal(await wallet.balance(db.pool,owner),0);
  const recovered:any=await (await run(question('first'))).json();assert.equal(recovered.wallet.coins,0);assert.equal((await snapshot()).state,'ended');
  assert.equal((await trial('finish',{billingSession:'b'.repeat(32)})).status,409);
  assert.equal((await trial('finish',{billingSession:'a'.repeat(32)})).status,200);
  assert.equal((await trial('start',{billingSession:'c'.repeat(32),guide:'Meera'})).status,422);
  // The paid chat follows the ordinary catalog; no starter bonus was approved.
  const paid:any=await (await quote(question('paid',{billingSession:'c'.repeat(32)}))).json();assert.equal(paid.cost,40);assert.equal(paid.canProceed,false);assert.equal(paid.trial,false);
  const newProcess=new CoinWallet(db,{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64)},{configured:()=>true,account:async()=>owner,provider:async()=>{throw Error('No payments');}},mode);
  assert.equal((await (await newProcess.handle(req('intro-trial',{operation:'status'}),'qa')).json() as any).state,'ended');
  await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);assert.equal((await db.pool.query('SELECT 1 FROM intro_chat_trials WHERE account_id=$1',[owner])).rows.length,0);
 }finally{Date.now=actual;await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);await db.close();}
});

test('an existing paid account is not placed in onboarding trial; skipping is persistent',async()=>{
 if(!process.env.DATABASE_URL?.includes('jyotara_qa_trial147'))throw Error('Isolated trial QA database required');
 const db=new PostgresDatabase(process.env.DATABASE_URL!),owner='intro147-existing';
 const wallet=new CoinWallet(db,{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64)},{configured:()=>true,account:async()=>owner,provider:async()=>{throw Error('No payments');}},'live');
 const request=(operation:string)=>new Request('https://example.test/api/wallet/intro-trial',{method:'POST',headers:{'x-jyotara-wallet-catalog':'2'},body:JSON.stringify({operation})});
 try{
  await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[owner,'0000',Date.now()]);
  await db.pool.query("INSERT INTO live_wallet_orders(id,account_id,request_id,pack_id,amount,coins,remaining,status,created_at,updated_at) VALUES($1,$2,$1,'minuteentry',2500,40,40,'paid',$3,$3)",[owner+'-order',owner,Date.now()]);
  assert.equal((await (await wallet.handle(request('status'),'qa')).json() as any).state,'unavailable');
  await db.pool.query('DELETE FROM live_wallet_orders WHERE account_id=$1',[owner]);
  assert.equal((await wallet.handle(request('offer'),'qa')).status,200);
  assert.equal((await wallet.handle(request('skip'),'qa')).status,200);
  assert.equal((await (await wallet.handle(request('status'),'qa')).json() as any).state,'skipped');
 }finally{await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);await db.close();}
});
