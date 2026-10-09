import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {build} from 'esbuild';
const built=await build({entryPoints:[new URL('../runtime/user-journey.ts',import.meta.url).pathname],bundle:true,write:false,platform:'node',format:'esm',target:'node22'});
const {parseJourneyEvents,userJourney}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
const now=Date.now();
const event=(overrides={})=>({id:'ab'.repeat(16),sessionId:'cd'.repeat(16),sequence:1,name:'chat.answer',screen:'chat',at:now,metadata:{outcome:'success',feature:'chat',language:'ta'},...overrides});
const request=(events,token='a'.repeat(64),extra={})=>new Request('https://example.test/api/user-journey',{method:'POST',headers:token?{authorization:'Bearer '+token}:{},body:JSON.stringify({events,...extra})});

test('chat delivery trace accepts opaque request reference without accepting content or bearer tokens',()=>{
 const requestRef='ab'.repeat(16);
 for(const name of ['chat.receipt','chat.present'])assert.equal(parseJourneyEvents({events:[event({name,metadata:{requestRef,count:2,status:3}})]})[0].metadata.requestRef,requestRef);
 for(const requestRef of ['a'.repeat(64),'private question here','9000000000',''])assert.throws(()=>parseJourneyEvents({events:[event({metadata:{requestRef}})]}));
});

test('closed metadata vocabulary rejects raw personal values and forged identities',()=>{
 assert.equal(parseJourneyEvents({events:[event()]}).length,1);
 for(const metadata of [{question:'secret'},{birthTime:'12:00'},{phone:'9000000000'},{outcome:'private name'},{control:'Saran'},{status:200.5},{durationMs:86400001},{feature:'secret'}])assert.throws(()=>parseJourneyEvents({events:[event({metadata})]}));
 for(const extra of [{accountId:'victim'},{token:'secret'},{name:'Private name'}])assert.throws(()=>parseJourneyEvents({events:[event()],...extra}));
 assert.throws(()=>parseJourneyEvents({events:[event({name:'private-question'})]}));
 assert.throws(()=>parseJourneyEvents({events:[event({screen:'secret-name'})]}));
 assert.throws(()=>parseJourneyEvents({events:[event(),event()]}));
 assert.throws(()=>parseJourneyEvents({events:Array.from({length:51},(_,i)=>event({id:i.toString(16).padStart(32,'0')}))}));
});

test('wrong device clock stays diagnostic; timestamp never controls authentication',()=>{
 assert.equal(parseJourneyEvents({events:[event({at:Date.parse('2030-01-01')})]},now)[0].at,Date.parse('2030-01-01'));
 assert.throws(()=>parseJourneyEvents({events:[event({at:-1})]}));
});

test('events require valid verified bearer session, not a client account id',async()=>{
 const calls=[];
 const query=async(sql,args=[])=>{calls.push([sql,args]);return {rows:sql.startsWith('SELECT account_id')?[{account_id:'verified-owner'}]:sql.startsWith('SELECT count')?[{count:0}]:[]};};
 const db={transaction:fn=>fn({query})};
 assert.equal((await userJourney(request([event()],null),db,'public-v1',now)).status,401);
 assert.equal(calls.length,0);
 assert.equal((await userJourney(request([event()],'a'.repeat(64),{accountId:'victim'}),db,'public-v1',now)).status,422);
 assert.equal(calls.length,0);
 const response=await userJourney(request([event()]),db,'public-v1',now);
 assert.equal(response.status,200);assert.deepEqual(await response.json(),{accepted:['ab'.repeat(16)]});
 const insert=calls.find(([sql])=>sql.startsWith('INSERT INTO user_journey_events'));
 assert.equal(insert[1][0],'verified-owner');assert.equal(insert[1][7],now);
 assert.match(insert[0],/ON CONFLICT\(account_id,event_id\) DO NOTHING/);
 assert.equal(calls[0][1][1],'public-v1');assert.equal(calls[0][1][2],now);
 assert.equal(JSON.stringify(calls).includes('victim'),false);
});

test('expired or foreign tester session stores nothing',async()=>{
 const calls=[];const query=async(sql,args)=>{calls.push([sql,args]);return {rows:[]};};
 const response=await userJourney(request([event()]),{transaction:fn=>fn({query})},'different-tester',now);
 assert.equal(response.status,401);assert.equal(calls.length,1);
});

test('per-user hourly bound prevents unbounded ingestion',async()=>{
 const calls=[];const query=async(sql,args)=>{calls.push([sql,args]);return {rows:sql.startsWith('SELECT account_id')?[{account_id:'owner'}]:sql.startsWith('SELECT count')?[{count:6000}]:[]};};
 const response=await userJourney(request([event()]),{transaction:fn=>fn({query})},'public-v1',now);
 assert.equal(response.status,429);assert.equal(response.headers.get('retry-after'),'3600');
 assert.equal(calls.some(([sql])=>sql.startsWith('INSERT')),false);
});

test('idempotent retries acknowledge existing events without spending hourly budget',async()=>{
 const calls=[];const query=async(sql,args)=>{calls.push([sql,args]);return {rows:sql.startsWith('SELECT account_id')?[{account_id:'owner'}]:sql.startsWith('SELECT event_id')?[{event_id:'ab'.repeat(16)}]:[]};};
 const response=await userJourney(request([event()]),{transaction:fn=>fn({query})},'public-v1',now);
 assert.equal(response.status,200);assert.deepEqual(await response.json(),{accepted:['ab'.repeat(16)]});
 assert.equal(calls.some(([sql])=>sql.startsWith('SELECT count')),false);
 assert.equal(calls.some(([sql])=>sql.startsWith('INSERT')),false);
 assert.ok(calls.some(([sql,args])=>sql.startsWith('SELECT pg_advisory_xact_lock')&&args[0]==='journey:owner'));
});

test('account erasure cascades timeline and retention has indexed server timestamps',()=>{
 const sql=readFileSync(new URL('../drizzle/0026_user_journey.sql',import.meta.url),'utf8');
 assert.match(sql,/REFERENCES `phone_accounts`\(`id`\) ON DELETE CASCADE/);
 assert.match(sql,/PRIMARY KEY \(`account_id`, `event_id`\)/);
 assert.match(sql,/user_journey_retention_idx/);
});
