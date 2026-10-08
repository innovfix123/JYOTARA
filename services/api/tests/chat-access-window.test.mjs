import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../lib/chat-access-window.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {chatAccessWindow}=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const day=86400000,now=Date.UTC(2026,9,3);
test('installed app accepts renewal for phones up to five minutes behind',()=>{
 const result=chatAccessWindow(now,now+day),start=Date.parse(result.chatAuthorizedAt),end=Date.parse(result.chatExpiresAt);
 assert.equal(end-start,day);
 for(const skew of [-300000,-120000,-1,0,120000])assert.ok(now+skew>=start && now+skew<end);
 assert.ok(end<=now+day);
});
test('last renewal day preserves client span without extending server expiry',()=>{
 const expiry=now+60000,result=chatAccessWindow(now,expiry);
 assert.equal(Date.parse(result.chatExpiresAt),expiry);
 assert.equal(Date.parse(result.chatExpiresAt)-Date.parse(result.chatAuthorizedAt),day);
});
test('expired authorization cannot produce a window',()=>{
 for(const expiry of [now,now-1,NaN])assert.throws(()=>chatAccessWindow(now,expiry));
});
