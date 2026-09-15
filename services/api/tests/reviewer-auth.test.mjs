import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,createHmac} from 'node:crypto';
import {build} from 'esbuild';
const built=await build({entryPoints:[new URL('../runtime/reviewer-auth.ts',import.meta.url).pathname],bundle:true,write:false,platform:'node',format:'esm'});
const {reviewerLogin}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
const password='synthetic-review-password-for-test-only';
const settings={JYOTARA_PHONE_AUTH_KEY:'synthetic-hmac-key-over-thirty-two-characters',JYOTARA_REVIEW_PASSWORD_SHA256:createHash('sha256').update(password).digest('hex')};
const req=(body)=>new Request('https://example.test/api/auth/reviewer',{method:'POST',body:JSON.stringify(body)});
const forbidden={transaction(){throw Error('Unexpected database');}};
test('review credentials are opt-in and restricted to public realm',async()=>{
 assert.equal((await reviewerLogin(req({}),forbidden,{},'public-v1')).status,503);
 assert.equal((await reviewerLogin(req({}),forbidden,settings,'someone-else')).status,503);
});
test('invalid credentials never create an account or session',async()=>{
 const calls=[];const db={transaction:fn=>fn({query:async(sql,args)=>{calls.push(sql);return {rows:[]};}})};
 assert.equal((await reviewerLogin(req({username:'jyotara-review',password:'wrong'}),db,settings,'public-v1')).status,401);
 assert.ok(calls.every(sql=>!sql.includes('phone_accounts')&&!sql.includes('phone_login_sessions')));
});
test('review login rate limit rejects before account creation',async()=>{
 const db={transaction:fn=>fn({query:async sql=>({rows:sql.startsWith('SELECT')?[{hits:30}]:[]})})};
 assert.equal((await reviewerLogin(req({username:'jyotara-review',password}),db,settings,'public-v1')).status,429);
});
test('login can only create its synthetic account and stores hashed token',async()=>{
 const calls=[];const db={transaction:fn=>fn({query:async(sql,args)=>{calls.push([sql,args]);return {rows:sql.includes('RETURNING id')?[{id:'isolated-review-account'}]:[]};}})};
 const result=await reviewerLogin(req({username:'jyotara-review',password,accountId:'victim',mobile:'9000000000'}),db,settings,'public-v1',1000);
 const body=await result.json();assert.equal(body.accountId,'isolated-review-account');assert.match(body.token,/^[a-f0-9]{64}$/);
 assert.equal(result.headers.get('cache-control'),'no-store');
 const account=calls.find(([sql])=>sql.includes('INSERT INTO phone_accounts'))[1];
 assert.equal(account[1],createHmac('sha256',settings.JYOTARA_PHONE_AUTH_KEY).update('review-account:play-console:v1').digest('hex'));
 assert.equal(account[2],'DEMO');
 const session=calls.find(([sql])=>sql.includes('INSERT INTO phone_login_sessions'))[1];
 assert.equal(session[0],createHash('sha256').update(body.token).digest('hex'));
 assert.equal(session[1],'isolated-review-account');assert.equal(session[2],'public-v1');
 assert.ok(!JSON.stringify(calls).includes(password));assert.ok(!JSON.stringify(calls).includes('victim'));
});
