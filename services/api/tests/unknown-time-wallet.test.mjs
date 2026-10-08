import assert from 'node:assert/strict';
import test from 'node:test';
import {createHmac} from 'node:crypto';
import {moduleFor} from './helpers/load.mjs';
const {CoinWallet}=await import(moduleFor('../runtime/coin-wallet.ts'));
const {issueChartTicket}=await import(moduleFor('../lib/chart-ticket.ts'));
const secret='a3'.repeat(32);
const tx={query:async sql=>({rows:sql.includes('count(*)')?[{n:200}]:sql.includes('trial=1')?[{id:'used-trial'}]:[]})};
const wallet=new CoinWallet({}, {JYOTARA_CHART_TICKET_KEY:secret},{});
const chart={rashi:'Meena',planets:[],yogas:[]};
const question={requestId:'unknown-time-wallet-01',profileId:'one',question:'What should I do while waiting for my exam result?',category:'Education',depth:'standard',language:'en'};
const request=session=>new Request('https://test',{headers:{Cookie:`nirayana_pilot_session=${session}`}});
test('limited unknown-time guidance is free even after the trial is used',async()=>{
 const chartTicket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false});
 const p=await wallet.price(tx,'account','guidance',{...question,chartTicket},request('owner'));
 assert.equal(p.cost,0);assert.equal(p.trial,false);
});
test('client unknown-time flag and another session ticket cannot bypass the price',async()=>{
 const chartTicket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:true});
 assert.equal((await wallet.price(tx,'account','guidance',{...question,chartTicket,birthTimeKnown:false},request('owner'))).cost,10);
 const unknown=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false});
 assert.equal((await wallet.price(tx,'account','guidance',{...question,chartTicket:unknown},request('other'))).cost,10);
});

test('installed app quote without a chart cookie matches the owned unknown-time send',async()=>{
 const chartTicket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false});
 const owned={query:async(sql,args)=>sql.includes('FROM phone_profile_owners')?{rows:args[0]==='owner'&&args[1]==='account'?[{exists:1}]:[]}:tx.query(sql,args)};
 const body={...question,chartTicket};
 const quoted=await wallet.price(owned,'account','guidance',body,new Request('https://test/api/wallet/quote'));
 const sent=await wallet.price(owned,'account','guidance',body,request('owner'));
 assert.equal(quoted.cost,0);assert.equal(quoted.trial,false);
 assert.deepEqual(quoted,sent);
 assert.equal((await wallet.price(owned,'another-account','guidance',body,new Request('https://test'))).cost,10);
});

test('deleted or unowned sessions and claimed flags cannot make cookie-free quotes free',async()=>{
 const ticket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false});
 let queried=false;
 const deleted={query:async(sql,args)=>{
  if(sql.includes('FROM phone_profile_owners')){
   queried=true;assert.match(sql,/deleted_chart_sessions/);assert.match(sql,/status='deleted'/);return {rows:[]};
  }
  return tx.query(sql,args);
 }};
 const noCookie=new Request('https://test');
 assert.equal((await wallet.price(deleted,'account','guidance',{...question,chartTicket:ticket},noCookie)).cost,10);
 assert.equal(queried,true);
 assert.equal((await wallet.price(deleted,'account','guidance',{...question,chartTicket:ticket+'=',birthTimeKnown:false},noCookie)).cost,10);
 const known=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:true});
 assert.equal((await wallet.price(deleted,'account','guidance',{...question,chartTicket:known,birthTimeKnown:false},noCookie)).cost,10);
});
test('limited reply completes with zero coins, no upgrade offer, and safe replay',async()=>{
 let row;
 const mock={query:async(sql,args)=>{
  if(sql.startsWith('INSERT INTO wallet_usage')){
   row={id:args[0],request_id:args[2],payload_hash:args[3],action:args[4],category:args[5],depth:args[6],cost:args[7],trial:args[8],status:'reserved',allocations:args[11]};return {rows:[row]};
  }
  if(sql.includes('FOR UPDATE')&&sql.includes('wallet_usage'))return {rows:[row]};
  if(sql.startsWith('UPDATE wallet_usage SET status=')){row={...row,status:args[0],result_ciphertext:args[1]};return {rows:[row]};}
  if(sql.includes('SELECT * FROM wallet_usage'))return {rows:row?[row]:[]};
  if(sql.includes('FROM phone_profile_owners'))return {rows:args[0]==='owner'&&args[1]==='account'?[{exists:1}]:[]};
  if(sql.includes('COALESCE(sum'))return {rows:[{n:0}]};
  if(sql.includes('count(*)'))return {rows:[{n:200}]};
  if(sql.includes('trial=1'))return {rows:[{id:'trial-used'}]};
  return {rows:[]};
 }};
 const w=new CoinWallet({transaction:fn=>fn(mock),pool:mock},{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:secret},{configured:()=>true});
 const body={...question,chartTicket:await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false})};
 const req=()=>new Request('https://test/api/guidance',{method:'POST',headers:{Cookie:'nirayana_pilot_session=owner'},body:JSON.stringify(body)});
 const quoteRequest=new Request('https://test/api/wallet/quote',{method:'POST',body:JSON.stringify({action:'guidance',payload:body})});
 w.gateway={configured:()=>true,account:async()=> 'account'};
 const quoted=await (await w.handle(quoteRequest,'test')).json();
 assert.equal(quoted.cost,0);assert.equal(quoted.canProceed,true);
 body.coinQuote=quoted.quote;
 for(let i=0;i<2;i++){
  const response=await w.run(req(),'account','guidance',async()=>Response.json({answer:'General guidance.',answerMode:'limited_guidance',replayed:i===1}));
  assert.equal(response.status,200);
  const result=await response.json();assert.equal(result.wallet.status,'complete');assert.equal(result.wallet.coins,0);assert.equal(result.wallet.canUpgrade,false);
 }
});
