import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {CoinWallet}=await import(moduleFor('../runtime/coin-wallet.ts'));
const {sealReply,openReply}=await import(moduleFor('../db/guidance-requests.ts'));
const secret='a3'.repeat(32);
const body={requestId:'conversation-wallet-01',profileId:'one',question:'How could I prepare for a career change?',category:'Career',depth:'standard',language:'en',responseMode:'conversation',conversationHistory:[{role:'user',content:'I want more time with family.'}],conversationMemory:['I work as a teacher.']};

test('wallet rejects unsupported conversational purchases before reserving or quoting coins',async()=>{
 let queries=0;
 const tx={query:async()=>{queries++;throw Error('Unexpected wallet query');}};
 const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
 for(const extra of [{depth:'detailed'},{upgradeFrom:'old-standard-answer'}]) {
  await assert.rejects(()=>wallet.price(tx,'account','guidance',{...body,...extra}),/standard price.*paid upgrades/);
 }
 assert.equal(queries,0);
});

test('conversational price keeps legacy Standard cost and binds exact retained memory',async()=>{
 const tx={query:async sql=>({rows:sql.includes('count(*)')?[{n:200}]:sql.includes('trial=1')?[{id:'used-trial'}]:[]})};
 const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
 const current=await wallet.price(tx,'account','guidance',body);
 assert.equal(current.cost,10);
 assert.equal(current.depth,'standard');
 const changed=await wallet.price(tx,'account','guidance',{...body,conversationMemory:['I work as a designer.']});
 assert.notEqual(changed.hash,current.hash);
 const {responseMode,conversationMemory,conversationHistory,...legacy}=body;
 assert.equal((await wallet.price(tx,'account','guidance',{...legacy,depth:'detailed'})).cost,20,'legacy Detailed clients retain their existing price');
});

test('only exact conversation acknowledgments are free without consuming the reading trial',async()=>{
 const tx={query:async sql=>({rows:sql.includes('count(*)')?[{n:0}]:[]})};
 const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
 const ack={...body,question:'Please keep it brief.',userMessageBatch:['Please keep it brief.']};
 const price=await wallet.price(tx,'account','guidance',ack);
 assert.equal(price.cost,0);
 assert.equal(price.trial,false,'an acknowledgment must not consume the first-reading trial');
 const paidTx={query:async sql=>({rows:sql.includes('count(*)')?[{n:200}]:sql.includes('trial=1')?[{id:'used-trial'}]:[]})};
 const realMessages=['What does my chart suggest about career growth?','Please keep it brief.'];
 for(const payload of [
  {...body,question:realMessages.join('\n'),userMessageBatch:realMessages},
  {...body,userMessageBatch:['Thanks']},
  {...body,question:'Thanks, when will I get a job?',userMessageBatch:undefined},
  {...body,question:'Please keep it brief.',responseMode:undefined,conversationMemory:undefined,userMessageBatch:undefined},
  {...body,question:'Please\nkeep it brief.',userMessageBatch:undefined},
 ])assert.equal((await wallet.price(paidTx,'account','guidance',payload)).cost,10,'real, forged or legacy questions keep their ordinary price');
 const prior={id:'old-paid-ack',request_id:ack.requestId,payload_hash:price.hash,cost:10,trial:0,status:'complete'};
 const priorTx={query:async sql=>({rows:sql.includes('SELECT * FROM wallet_usage')?[prior]:sql.includes('count(*)')?[{n:200}]:[]})};
 assert.equal((await wallet.price(priorTx,'account','guidance',ack)).cost,10,'a sealed earlier paid receipt is not retroactively repriced');
});

test('a zero-price acknowledgement settles once without allocating purchased coins',async()=>{
 let row;let coinDebits=0;
 const tx={query:async(sql,args)=>{
  if(sql.startsWith('INSERT INTO wallet_usage')){row={id:args[0],request_id:args[2],payload_hash:args[3],action:args[4],category:args[5],depth:args[6],cost:args[7],trial:args[8],status:'reserved',allocations:args[11]};return {rows:[row]};}
  if(sql.includes('FOR UPDATE')&&sql.includes('wallet_usage'))return {rows:[row]};
  if(sql.startsWith('UPDATE wallet_usage SET status=')){row={...row,status:args[0],result_ciphertext:args[1]};return {rows:[row]};}
  if(sql.includes('SELECT * FROM wallet_usage'))return {rows:row?[row]:[]};
  if(sql.includes('remaining=remaining-'))coinDebits++;
  if(sql.includes('COALESCE(sum'))return {rows:[{n:50}]};
  if(sql.includes('remaining>0'))return {rows:[{id:'coin-lot',remaining:50}]};
  if(sql.includes('count(*)'))return {rows:[{n:200}]};
  if(sql.includes('trial=1'))return {rows:[{id:'trial-used'}]};
  return {rows:[]};
 }};
 const wallet=new CoinWallet({transaction:fn=>fn(tx),pool:tx},{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:secret},{configured:()=>true,account:async()=> 'account'});
 const payload={...body,question:'Please keep it brief.',userMessageBatch:['Please keep it brief.']};
 const quote=await (await wallet.handle(new Request('https://test/api/wallet/quote',{method:'POST',body:JSON.stringify({action:'guidance',payload})}),'test')).json();
 assert.equal(quote.cost,0);payload.coinQuote=quote.quote;
 const send=()=>wallet.run(new Request('https://test/api/guidance',{method:'POST',body:JSON.stringify(payload)}),'account','guidance',async()=>Response.json({answer:'I’ll keep my replies brief.',answerMode:'limited_guidance'}));
 for(let i=0;i<2;i++){
  const response=await send();assert.equal(response.status,200);
  const result=await response.json();assert.equal(result.wallet.status,'complete');assert.equal(result.wallet.coins,0);assert.equal(result.wallet.trial,false);
 }
 assert.equal(coinDebits,0);
 assert.deepEqual(JSON.parse(row.allocations),[]);
 const changed={...payload,question:'What about career growth?',userMessageBatch:['What about career growth?']};
 await assert.rejects(()=>wallet.price(tx,'account','guidance',changed),/request changed/);
});

test('long recent user boundary overrides an assistant suggestion and is free in the quote',async()=>{
 const tx={query:async sql=>({rows:sql.includes('count(*)')?[{n:200}]:sql.includes('trial=1')?[{id:'used-trial'}]:[]})};
 const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
 const user='My relationship ended and they asked me not to contact them. '+'I want to respect that boundary while I recover. '.repeat(8);
 assert.ok(user.length>240,'this statement cannot fit the legacy six-message routing context');
 const current=await wallet.price(tx,'account','guidance',{...body,question:'Should I give them another chance?',conversationMemory:[],previousUserMessages:[],conversationHistory:[{role:'user',content:user},{role:'assistant',content:'Try messaging from another account.'}]});
 assert.equal(current.category,'Love');
 assert.equal(current.cost,0);
 assert.equal(current.trial,false);
});

test('completed conversational receipt cannot offer a paid Detailed upgrade',async()=>{
 let row;
 const tx={query:async(sql,args)=>{
  if(sql.startsWith('INSERT INTO wallet_usage')){
   row={id:args[0],request_id:args[2],payload_hash:args[3],action:args[4],category:args[5],depth:args[6],cost:args[7],trial:args[8],status:'reserved',allocations:args[11]};return {rows:[row]};
  }
  if(sql.includes('FOR UPDATE')&&sql.includes('wallet_usage'))return {rows:[row]};
  if(sql.startsWith('UPDATE wallet_usage SET status=')){row={...row,status:args[0],result_ciphertext:args[1]};return {rows:[row]};}
  if(sql.includes('SELECT * FROM wallet_usage'))return {rows:row?[row]:[]};
  if(sql.includes('COALESCE(sum'))return {rows:[{n:50}]};
  if(sql.includes('remaining>0'))return {rows:[{id:'coin-lot',remaining:50}]};
  if(sql.includes('count(*)'))return {rows:[{n:200}]};
  if(sql.includes('trial=1'))return {rows:[{id:'trial-used'}]};
  return {rows:[]};
 }};
 const wallet=new CoinWallet({transaction:fn=>fn(tx),pool:tx},{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:secret},{configured:()=>true,account:async()=> 'account'});
 const payload={...body};
 const quote=await (await wallet.handle(new Request('https://test/api/wallet/quote',{method:'POST',body:JSON.stringify({action:'guidance',payload})}),'test')).json();
 assert.equal(quote.cost,10);
 payload.coinQuote=quote.quote;
 const response=await wallet.run(new Request('https://test/api/guidance',{method:'POST',body:JSON.stringify(payload)}),'account','guidance',async()=>Response.json({answer:'A complete grounded answer.',answerMode:'provider_reading'}));
 assert.equal(response.status,200);
 const result=await response.json();
 assert.equal(result.wallet.coins,10);
 assert.equal(result.wallet.canUpgrade,false);
 const saved=await openReply(secret,row.id,row.result_ciphertext);
 assert.equal(saved.responseMode,'conversation');
 assert.deepEqual(saved.conversationMemory,body.conversationMemory);
});

test('omitting mode cannot buy an upgrade of a conversational parent, while legacy upgrades remain valid',async()=>{
 const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
 const {responseMode,conversationMemory,conversationHistory,...legacy}=body;
 const upgrade={...legacy,requestId:'conversation-upgrade-01',depth:'detailed',upgradeFrom:'parent-reading'};
 const binding=wallet.hash([upgrade.profileId,upgrade.question,upgrade.guide,upgrade.responseStyle,upgrade.language]);
 let parentContext={category:'Career',responseMode:'conversation',conversationMemory:body.conversationMemory};
 const tx={query:async sql=>({rows:sql.includes('WHERE id=$1 AND account_id=$2')?[{id:'parent-reading',category:'Career',binding_hash:binding,result_ciphertext:await sealReply(secret,'parent-reading',parentContext)}]:[]})};
 await assert.rejects(()=>wallet.price(tx,'account','guidance',upgrade),/standard price.*paid upgrades/);
 parentContext={category:'Career',conversationHistory:[],previousUserMessages:[]};
 assert.equal((await wallet.price(tx,'account','guidance',upgrade)).cost,10);
});
