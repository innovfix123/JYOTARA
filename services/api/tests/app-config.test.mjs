import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../runtime/app-config.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {defaults,validateConfig,blockedRequest}=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
test('remote settings validate strict schema, bounded pricing and plain content',()=>{
 assert.equal(validateConfig({schema:1,revision:2,features:{detailed:false}}).features.detailed,false);
 for(const x of [{schema:2,revision:1},{schema:1,revision:1,secret:'leak'},{schema:1,revision:1,features:{unknown:true}},{schema:1,revision:1,costs:{matching:-2}},{schema:1,revision:1,languages:[]},{schema:1,revision:1,exploreCards:[{title:'x',body:'x'.repeat(2001)}]}])assert.throws(()=>validateConfig(x));
});
test('maintenance pauses new paid work but leaves settlement and authentication reachable',()=>{
 const c=validateConfig({...defaults,maintenance:true});
 for(const p of ['/api/guidance','/api/kundli/matching','/api/wallet/create'])assert.equal(blockedRequest(p,{},c),true);
 for(const p of ['/api/auth/send','/api/auth/verify','/api/wallet/status','/api/wallet/verify','/api/wallet/refresh','/api/payments/live/webhook'])assert.equal(blockedRequest(p,{},c),false);
});
test('old clients cannot bypass detailed, disabled guide, pack or language rules',()=>{
 const c=validateConfig({...defaults,disabledGuides:['Tharagai'],disabledPacks:['max'],languages:['english']});
 assert.equal(blockedRequest('/api/guidance',{depth:'detailed'},c),true);
 assert.equal(blockedRequest('/api/wallet/quote',{action:'guidance',payload:{depth:'detailed'}},c),true);
 assert.equal(blockedRequest('/api/guidance',{guide:'Tharagai'},c),true);
 assert.equal(blockedRequest('/api/wallet/create',{packId:'max'},c),true);
 assert.equal(blockedRequest('/api/guidance',{responseStyle:'tamil'},c),true);
 assert.equal(blockedRequest('/api/guidance',{responseStyle:'english',depth:'standard'},c),false);
});
