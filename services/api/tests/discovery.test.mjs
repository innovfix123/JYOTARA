import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const encode = source => 'data:text/javascript;base64,'+Buffer.from(ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText).toString('base64');
const client=encode(readFileSync(new URL('../lib/prokerala-client.ts',import.meta.url),'utf8'));
const source=readFileSync(new URL('../runtime/discovery.ts',import.meta.url),'utf8').replace("'../lib/prokerala-client'",JSON.stringify(client));
const {validDay,validBirth,daily,matching}=await import(encode(source));
test('daily dates use IST and reject outside the three-day window',()=>{
 const now=Date.parse('2026-09-08T20:00:00Z');
 for(const date of ['2026-09-08','2026-09-09','2026-09-10'])assert.equal(validDay(date,now),true);
 for(const date of ['2026-09-07','2026-09-11','bad',null])assert.equal(validDay(date,now),false);
});
test('matching rejects unknown birth times and minors before provider access',async()=>{
 const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:true};
 assert.equal(validBirth(birth),true);
 assert.equal(validBirth({...birth,exactTime:false}),false);
 assert.equal(validBirth({...birth,datetime:'2020-01-01T12:00:00+05:30'}),false);
 const res=await matching(new Request('https://test',{method:'POST',body:JSON.stringify({boy:birth,girl:birth,consent:false})}));
 assert.equal(res.status,400);
});
test('invalid signs never trigger provider calls',async()=>{
 const res=await daily(new Request('https://test',{method:'POST',body:JSON.stringify({sign:'unknown',date:'2026-09-09'})}));
 assert.equal(res.status,400);
});
