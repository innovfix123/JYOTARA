import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,generateKeyPairSync} from 'node:crypto';
import {writeFileSync,unlinkSync} from 'node:fs';
import {PostgresDatabase} from './postgres';
import {CoinWallet,minuteCoinPacks} from './coin-wallet';
import {EngagementNotifications,chooseReminder,notificationClock} from './engagement-notifications';

for(const mode of ['test','live'] as const)test(mode+' started-minute charges: retries, latency, idle, failure, ownership and legacy orders',async()=>{
 if(!process.env.DATABASE_URL?.includes('jyotara_qa_payments146'))throw Error('Isolated QA database required');
 const db=new PostgresDatabase(process.env.DATABASE_URL);const owner='minute-'+mode,secret='e'.repeat(64);
 const env={JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:secret};
 const wallet=new CoinWallet(db,env,{configured:()=>true,account:async()=>owner,provider:async()=>{throw Error('No real payments');}},mode);
 const req=(action:string,body:any={},catalog=true)=>new Request('https://example.test/api/wallet/'+action,{method:'POST',headers:catalog?{'x-jyotara-wallet-catalog':'2'}:{},body:JSON.stringify(body)});
 let now=Date.now();const actual=Date.now;Date.now=()=>now;
 const question=(id:string,patch:any={})=>({requestId:'minute-question-'+id,profileId:'p1',guide:'Vetri',question:'What does my chart suggest about career?',category:'Career',depth:'standard',responseMode:'conversation',responseStyle:'english',language:'en',billingVersion:2,billingSession:'a'.repeat(32),...patch});
 const quote=async(body:any)=>{const r=await wallet.handle(req('quote',{action:'guidance',payload:body}),'qa');assert.equal(r.status,200,await r.clone().text());return await r.json() as any;};
 const run=async(body:any,handler:any=async()=>Response.json({answer:'A useful reading.',answerMode:'provider_reading'}))=>{const q=await quote(body);return wallet.run(req('guidance',{...body,coinQuote:q.quote}),owner,'guidance',handler);};
 try{
  await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[owner,'0000',now]);
  await db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,created_at,updated_at) VALUES($1,$2,$1,'regular',14900,200,200,'paid',$3,$3)`,[owner+'-old',owner,now]);
  const old:any=await (await wallet.handle(req('status',{},false),'qa')).json();assert.equal(old.packs.length,5);
  const newer:any=await (await wallet.handle(req('status'),'qa')).json();assert.deepEqual(newer.packs,minuteCoinPacks);assert.equal(newer.balance,200);
  assert.equal((await quote(question('first'))).cost,40);
  const first:any=await (await run(question('first'),async()=>{now+=120000;return Response.json({answer:'A useful reading.',answerMode:'provider_reading'});})).json();
  assert.equal(first.wallet.coins,40);assert.equal(first.wallet.trial,false);assert.equal(first.wallet.billingVersion,2);assert.equal(await wallet.balance(db.pool,owner),160);
  assert.equal((await quote(question('second'))).cost,0);now+=20000;
  const second:any=await (await run(question('second'),async()=>{now+=45000;return Response.json({answer:'A follow-up.',answerMode:'provider_reading'});})).json();assert.equal(second.wallet.coins,0);
  assert.equal((await quote(question('third'))).cost,0);
  now+=300000;assert.equal(await wallet.balance(db.pool,owner),160);assert.equal((await quote(question('expired'))).cost,40);
  const failed:any=await (await run(question('failed'),async()=>Response.json({answer:'Unavailable.',answerMode:'reading_unavailable'}))).json();assert.equal(failed.wallet.status,'failed');assert.equal(await wallet.balance(db.pool,owner),160);
  const refundedRetry=await run(question('failed'),async()=>{throw Error('A refunded request must not generate an unbilled answer');});assert.equal(refundedRetry.status,422);assert.equal(await wallet.balance(db.pool,owner),160);
  const q=await quote(question('paid'));const response=await wallet.run(req('guidance',{...question('paid'),coinQuote:q.quote}),owner,'guidance',async()=>Response.json({answer:'A useful reading.',answerMode:'provider_reading'}));assert.equal(response.status,200);assert.equal(await wallet.balance(db.pool,owner),120);
  await run(question('paid'));assert.equal(await wallet.balance(db.pool,owner),120);
  assert.equal((await wallet.handle(req('quote',{action:'guidance',payload:question('wrong-guide',{guide:'Nila'})}),'qa')).status,422);
  const foreign=await wallet.run(req('guidance',{...question('paid'),coinQuote:q.quote}),owner+'-other','guidance',async()=>{throw Error('Foreign quote ran');});assert.equal(foreign.status,409);
  const end=await wallet.handle(req('end-chat',{billingSession:'a'.repeat(32)}),'qa');assert.equal(end.status,200);
  assert.equal((await wallet.handle(req('quote',{action:'guidance',payload:question('after-end')}),'qa')).status,422);
  await run(question('paid'));assert.equal(await wallet.balance(db.pool,owner),120);
  assert.equal((await quote(question('new-session',{billingSession:'b'.repeat(32)}))).cost,40);
  const personal=(id:string)=>({requestId:'personal-reading-'+id,profileId:'p1',question:'Explain my personality and strengths based on my birth chart.',category:'Daily',depth:'standard',responseStyle:'english',language:'en'});
  const report=personal('complete');assert.equal((await quote(report)).cost,5);
  assert.equal((await (await run(report)).json() as any).wallet.coins,5);assert.equal(await wallet.balance(db.pool,owner),115);
  await run(report);assert.equal(await wallet.balance(db.pool,owner),115);
  const reportFailed=personal('failure');
  assert.equal((await (await run(reportFailed,async()=>Response.json({answer:'Unavailable.',answerMode:'reading_unavailable'}))).json() as any).wallet.status,'failed');
  assert.equal(await wallet.balance(db.pool,owner),115);
  assert.equal((await run(reportFailed,async()=>{throw Error('Refunded personal reading must not call the provider');})).status,422);
  const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:true};
  const match={boy:birth,girl:{...birth,datetime:'2001-05-18T08:30:00+05:30'},consent:true,language:'en'};
  const matchQuote=async(payload:any,catalog=true)=>await (await wallet.handle(req('quote',{action:'matching',payload},catalog),'qa')).json() as any;
  assert.equal((await matchQuote(match,false)).cost,20);assert.equal((await matchQuote(match)).cost,15);
  let matches=0;const mq=await matchQuote(match);
  const matched:any=await (await wallet.run(req('matching',{...match,coinQuote:mq.quote}),owner,'matching',async()=>{matches++;return Response.json({score:20,language:'en',factors:[]});})).json();
  assert.equal(matched.wallet.coins,15);assert.equal(await wallet.balance(db.pool,owner),100);
  const reopen=await matchQuote({...match,language:'ta',boy:{...birth,nickname:'Renamed'}});assert.equal(reopen.cost,0);assert.equal(reopen.reopening,true);
  await wallet.run(req('matching',{...match,coinQuote:reopen.quote}),owner,'matching',async()=>{throw Error('Saved matching must not call the provider');});
  assert.equal(matches,1);assert.equal(await wallet.balance(db.pool,owner),100);
  // No provider call for insufficient balance; all residual coins are retained.
  await db.pool.query(`UPDATE ${wallet.ordersTable} SET remaining=10 WHERE account_id=$1`,[owner]);
  const insufficient=await quote(question('low',{billingSession:'b'.repeat(32)}));assert.equal(insufficient.canProceed,false);
  assert.equal((await wallet.run(req('guidance',{...question('low',{billingSession:'b'.repeat(32)}),coinQuote:insufficient.quote}),owner,'guidance',async()=>{throw Error('Unfunded provider call');})).status,409);
  assert.equal(await wallet.balance(db.pool,owner),10);
 }finally{Date.now=actual;await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);await db.close();}
});

test('notification targeting: five minutes, returning users, cap, quiet hours, activity and open ownership',async()=>{
 const now=Date.parse('2026-10-10T05:00:00Z');assert.equal(notificationClock(now).hour,10);
 const state={created:now-600000,opened:now-300000,used:0,foreground:0,daily:0,matching:0,chat:0,count:0,lastSent:0,kinds:[]};
 assert.deepEqual(chooseReminder(state,now),{kind:'inactivity',feature:'welcome'});
 assert.equal(chooseReminder({...state,count:2},now),null);
 assert.equal(chooseReminder({...state,opened:now-299999,foreground:now},now),null);
 assert.equal(chooseReminder({...state,used:now},now),null);
 assert.equal(chooseReminder(state,Date.parse('2026-10-10T16:00:00Z')),null);
 assert.deepEqual(chooseReminder({...state,created:now-8*86400000},now),{kind:'inactivity',feature:'daily'});
 const db=new PostgresDatabase(process.env.DATABASE_URL!),owner='notification146',token='x'.repeat(160),bearer='c'.repeat(64);
 const keyfile='/tmp/jyotara146-qa-fcm-key.json';const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
 writeFileSync(keyfile,JSON.stringify({project_id:'jyotra-db0f4',client_email:'synthetic@example.test',private_key:privateKey.export({type:'pkcs8',format:'pem'})}),{mode:0o600});
 const env={JYOTARA_CHART_TICKET_KEY:'e'.repeat(64),JYOTARA_ENGAGEMENT_NOTIFICATIONS:'true',JYOTARA_FCM_CREDENTIAL_FILE:keyfile};
 let sends=0;
 const service=new EngagementNotifications(db,env,async(url,options)=>{
  if(String(url).includes('oauth2'))return Response.json({access_token:'synthetic',expires_in:3600});
  sends++;const body=JSON.parse(options!.body as string);assert.equal(body.message.token,token);assert.equal(body.message.data.feature,'welcome');return Response.json({name:'synthetic-message'});
 });
 const req=(action:string,body:any)=>new Request('https://example.test/api/notifications/'+action,{method:'POST',headers:{authorization:'Bearer '+bearer},body:JSON.stringify(body)});
 try{
  await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[owner,'0000',now-600000]);
  await db.pool.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[createHash('sha256').update(bearer).digest('hex'),owner,'qa',Date.now()+86400000]);
  assert.equal((await service.handle(req('register',{token,language:'en',build:146}),owner)).status,200);
  const stored=(await db.pool.query('SELECT token_ciphertext FROM notification_devices WHERE account_id=$1',[owner])).rows[0];assert.equal(stored.token_ciphertext.includes(token),false);
  assert.equal((await service.handle(req('register',{token,language:'en',build:146}),'other-owner')).status,409);
  await db.pool.query("INSERT INTO user_journey_events(account_id,event_id,app_session_id,sequence,event_name,screen,occurred_at,received_at,metadata_json,server_sequence) VALUES($1,$2,$2,1,'app.open','home',$3,$3,'{}',1)",[owner,'f'.repeat(32),now-300000]);
  await service.tick(now);assert.equal(sends,1);await service.tick(now+60000);assert.equal(sends,1);
  const campaign=(await db.pool.query('SELECT * FROM notification_campaigns WHERE account_id=$1',[owner])).rows[0];assert.equal(campaign.status,'accepted');assert.equal(campaign.opened_at,null);
  const foreign:any=await (await service.handle(req('event',{id:campaign.id,event:'opened'}),'other-owner')).json();assert.equal(foreign.accepted,false);
  const own:any=await (await service.handle(req('event',{id:campaign.id,event:'opened'}),owner)).json();assert.equal(own.accepted,true);
  await service.handle(req('disable',{}),owner);assert.equal((await db.pool.query('SELECT enabled FROM notification_devices WHERE account_id=$1',[owner])).rows[0].enabled,0);
  await db.pool.query('DELETE FROM phone_login_sessions WHERE account_id=$1',[owner]);await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);assert.equal((await db.pool.query('SELECT * FROM notification_campaigns WHERE account_id=$1',[owner])).rows.length,0);
 }finally{await db.pool.query('DELETE FROM phone_login_sessions WHERE account_id=$1',[owner]);await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);await db.close();unlinkSync(keyfile);}
});
