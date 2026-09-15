import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['runtime/answer-reports.ts'],bundle:true,write:false,platform:'node',format:'esm'});
const {reportAnswer}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
const secret='ab'.repeat(32),token='12'.repeat(32);
const req=(body={},auth=true)=>new Request('https://example.test/api/answers/report',{method:'POST',headers:auth?{Authorization:'Bearer '+token}:{},body:JSON.stringify({answer:'Synthetic answer',guide:'Guide',reason:'misleading',consent:true,...body})});
test('reports require authentication and explicit consent before storage',async()=>{
 const db={transaction:()=>{throw Error('Must not touch DB');}};
 assert.equal((await reportAnswer(req({},false),db,secret,'tester')).status,401);
 for(const body of [{consent:false},{reason:'invented'},{answer:' '},{answer:'a'.repeat(20001)}])assert.equal((await reportAnswer(req(body),db,secret,'tester')).status,422);
});
test('reports encrypt selected content, deduplicate retries and reject expired sessions',async()=>{
 let saved,authenticated=true;
 const db={transaction:fn=>fn({query:async(sql,args)=>{
  if(sql.startsWith('SELECT account_id'))return {rows:authenticated?[{account_id:'owner'}]:[]};
  if(sql.startsWith('SELECT id'))return {rowCount:saved?1:0};
  if(sql.startsWith('SELECT count'))return {rows:[{total:0}]};
  if(sql.startsWith('INSERT'))saved=args;
  return {rows:[],rowCount:0};
 }})};
 assert.deepEqual(await (await reportAnswer(req(),db,secret,'tester')).json(),{reported:true});
 assert.equal(saved[1],'owner');assert.ok(!saved[3].includes('Synthetic'));
 assert.match(saved[3],/^[a-f0-9]{24}\.[a-f0-9]+$/);
 const first=saved;assert.equal((await reportAnswer(req(),db,secret,'tester')).status,200);assert.equal(saved,first);
 authenticated=false;assert.equal((await reportAnswer(req(),db,secret,'tester')).status,401);
});
test('report rate limit rejects without retaining content',async()=>{
 const db={transaction:fn=>fn({query:async(sql)=>{
  if(sql.startsWith('SELECT account_id'))return {rows:[{account_id:'owner'}]};
  if(sql.startsWith('SELECT id'))return {rowCount:0};
  if(sql.startsWith('SELECT count'))return {rows:[{total:30}]};
  if(sql.startsWith('INSERT'))throw Error('Should not save');
  return {rowCount:0};
 }})};
 assert.equal((await reportAnswer(req(),db,secret,'tester')).status,429);
});
