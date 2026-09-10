import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../runtime/phone-auth.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {PhoneAuth}=await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
const config={JYOTARA_OTP_ENABLED:'true',JYOTARA_PHONE_AUTH_KEY:'synthetic-test-secret-not-production',AUTHKEY_KEY:'synthetic',AUTHKEY_SID:'123'};
const request=(path,body={})=>new Request('https://example.test/api/auth/'+path,{method:'POST',body:JSON.stringify(body)});
const unavailable={pool:{query:()=>{throw Error('Unexpected database');}},transaction:()=>{throw Error('Unexpected database');}};
test('disabled OTP does not contact provider or database',async()=>{
 const auth=new PhoneAuth(unavailable,{},()=>{throw Error('Unexpected SMS');});
 assert.deepEqual(await (await auth.handle(request('config'),'tester')).json(),{enabled:false});
 assert.equal((await auth.handle(request('send',{mobile:'9000000000'}),'tester')).status,503);
});
test('invalid phone and code are rejected before database access',async()=>{
 const auth=new PhoneAuth(unavailable,config);
 assert.equal((await auth.handle(request('send',{mobile:'123'}),'tester')).status,422);
 assert.equal((await auth.handle(request('verify',{mobile:'9000000000',otp:'123',challengeId:'x'}),'tester')).status,400);
});
for(const mode of ['accepted','rejected','timeout'])test('SMS '+mode+' returns no login token or plaintext OTP',async()=>{
 const calls=[];let sends=0,otp;
 const query=async(sql,args)=>{calls.push([sql,args]);return {rows:[],rowCount:0};};
 const db={pool:{query},transaction:fn=>fn({query})};
 const auth=new PhoneAuth(db,config,async url=>{
  sends++;assert.equal(url.origin,'https://api.authkey.io');otp=url.searchParams.get('otp');assert.match(otp,/^\d{6}$/);
  if(mode==='timeout')throw Error('timeout');
  return Response.json({Message:mode==='accepted'?'Submitted Successfully':'Rejected'});
 });
 const result=await auth.handle(request('send',{mobile:'9000000000'}),'tester');
 const body=await result.json();assert.equal(sends,1);assert.equal(body.token,undefined);assert.equal(body.otp,undefined);
 assert.equal(result.status,mode==='rejected'?503:200);
 if(mode!=='rejected')assert.match(body.challengeId,/^[a-f0-9]{48}$/);
 if(mode==='timeout')assert.equal(body.deliveryUnconfirmed,true);
 assert.equal(calls.some(([sql])=>sql==='DELETE FROM phone_challenges WHERE id=$1'),mode==='rejected');
 const inserted=calls.find(([sql])=>sql.startsWith('INSERT INTO phone_challenges'))[1];
 assert.match(inserted[3],/^[a-f0-9]{64}$/);assert.notEqual(inserted[3],otp);
 assert.ok(!JSON.stringify(calls).includes('9000000000'));
});
