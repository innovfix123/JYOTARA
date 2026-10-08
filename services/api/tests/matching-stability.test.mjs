import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {moduleFor} from './helpers/load.mjs';
const {CoinWallet}=await import(moduleFor('../runtime/coin-wallet.ts'));
const {sealReply}=await import(moduleFor('../db/guidance-requests.ts'));
const secret='e'.repeat(64);
const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:true};
const pair={boy:{...birth,nickname:'Arjun',birthplaceLabel:'Erode'},girl:{...birth,datetime:'2001-05-18T08:30:00+05:30',nickname:'Divya'},consent:true,language:'en'};
function wallet(db){return new CoinWallet(db,{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:secret},{configured:()=>true},'live');}

test('repeat matching reuses encrypted result across renamed profiles, labels and languages without recalculating',async()=>{
 const result={score:22,maximum:36,language:'en',interpretation:'Synthetic comparison.',note:'Synthetic note.',factors:[{id:6,score:3,maximum:6}]};
 let row,providerCalls=0;
 const tx={query:async(sql,args)=>{
  assert.match(sql,/SELECT \* FROM live_wallet_usage/);
  return {rows:args[1]===row.request_id?[row]:[]};
 }};
 const w=wallet({transaction:fn=>fn(tx)});
 const hash=w.hash(['matching',w.clean('matching',pair)]);
 row={id:'synthetic-saved-match',request_id:'match-'+hash,payload_hash:hash,status:'complete',action:'matching',cost:20,depth:'standard',category:'Basic matching',result_ciphertext:await sealReply(secret,'synthetic-saved-match',result)};
 const encoded=Buffer.from(JSON.stringify({account:'qa',hash,requestId:row.request_id,cost:20,trial:false,expires:Date.now()+60000})).toString('base64url');
 const coinQuote=encoded+'.'+createHmac('sha256',secret).update(encoded).digest('hex');
 const original=globalThis.fetch;
 process.env.OPENROUTER_API_KEY='synthetic';
 globalThis.fetch=async()=>Response.json({output_text:JSON.stringify(['மாதிரி விளக்கம்.','மாதிரி குறிப்பு.'])});
 try{
  for(const changes of [{},{boy:{...pair.boy,nickname:'New display name',birthplaceLabel:'Erode, Tamil Nadu'},language:'ta'},{language:'en'}]){
   const body={...pair,...changes,coinQuote};
   const response=await w.run(new Request('https://test/api/kundli/matching',{method:'POST',body:JSON.stringify(body)}),'qa','matching',async()=>{providerCalls++;return Response.json({score:35});});
   assert.equal(response.status,200);const value=await response.json();
   assert.equal(value.score,22);assert.equal(value.maximum,36);assert.equal(value.replayed,true);
   assert.equal(value.language,body.language);assert.equal(value.factors[0].score,3);
  }
  assert.equal(providerCalls,0);
 }finally{globalThis.fetch=original;delete process.env.OPENROUTER_API_KEY;}
});

test('birth changes and role swaps are distinct; unknown times share the same noon reference',()=>{
 const w=wallet({});const key=body=>w.hash(['matching',w.clean('matching',body)]);
 assert.notEqual(key(pair),key({...pair,boy:{...pair.boy,datetime:'2002-07-29T06:00:00+05:30'}}));
 assert.notEqual(key(pair),key({...pair,boy:pair.girl,girl:pair.boy}));
 assert.notEqual(key(pair),key({...pair,boy:{...pair.boy,longitude:77.73}}));
 const unknown={...pair,boy:{...pair.boy,exactTime:false}};
 assert.equal(key(unknown),key({...unknown,boy:{...unknown.boy,datetime:'2002-07-29T19:00:00+05:30'}}));
 assert.notEqual(key(pair),key(unknown));
});

test('legacy paid result keeps its receipt and becomes stable without another charge',async()=>{
 const w=wallet({});const legacy={...pair};const oldHash=w.hash(['matching',legacy]);
 const result={score:18,maximum:36,language:'en',interpretation:'Saved comparison.',note:'Chart comparison.',factors:[{id:7,score:3,maximum:7}]};
 const row={id:'legacy-result',account_id:'qa',request_id:'match-'+oldHash,payload_hash:oldHash,status:'complete',action:'matching',cost:20,depth:'standard',category:'Basic matching',result_ciphertext:await sealReply(secret,'legacy-result',result),trial:0};
 const tx={query:async(sql,args)=>{
  if(sql.startsWith('UPDATE')){assert.equal(args[2],row.id);assert.equal(args[3],'qa');row.request_id=args[0];row.payload_hash=args[1];return {rows:[row]};}
  assert.equal(args[0],'qa');
  return {rows:(Array.isArray(args[1])?args[1].includes(row.request_id):args[1]===row.request_id)?[row]:[]};
 }};
 w.db={transaction:fn=>fn(tx)};
 const hash=w.hash(['matching',w.clean('matching',pair)]);const requestId='match-'+hash;
 const encoded=Buffer.from(JSON.stringify({account:'qa',hash,requestId,cost:20,trial:false,expires:Date.now()+60000})).toString('base64url');
 const coinQuote=encoded+'.'+createHmac('sha256',secret).update(encoded).digest('hex');
 for(const body of [pair,{...pair,boy:{...pair.boy,nickname:'Renamed'}}]){
  const response=await w.run(new Request('https://test/api/kundli/matching',{method:'POST',body:JSON.stringify({...body,coinQuote})}),'qa','matching',()=>{throw Error('Must not recalculate');});
  assert.equal(response.status,200);const value=await response.json();assert.equal(value.score,18);assert.equal(value.wallet.id,row.id);assert.equal(value.factors[0].name,'Emotional Connection');
 }
 assert.equal(row.request_id,requestId);assert.equal(row.cost,20);
});
