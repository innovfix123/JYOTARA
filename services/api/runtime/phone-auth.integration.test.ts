import test from 'node:test';
import assert from 'node:assert/strict';
import {PhoneAuth} from './phone-auth';
import {PostgresDatabase} from './postgres';
test('OTP one-time consumption, attempts, expiry, resend and sessions use atomic PostgreSQL state',async()=>{
 const url=process.env.DATABASE_URL!;
 if(!url||!url.includes('jyotara_qa_otp'))throw Error('Isolated QA database required');
 const db=new PostgresDatabase(url);
 let now=Date.now(),code='';
 const config={JYOTARA_OTP_ENABLED:'true',JYOTARA_PHONE_AUTH_KEY:'synthetic-integration-secret-123456',AUTHKEY_KEY:'synthetic',AUTHKEY_SID:'123'};
 const auth=new PhoneAuth(db,config,async(input)=>{code=new URL(String(input)).searchParams.get('otp')!;return Response.json({Message:'Submitted Successfully'});},()=>now);
 const req=(path:string,body:object={},token?:string)=>new Request('https://example.test/api/auth/'+path,{method:'POST',headers:token?{Authorization:'Bearer '+token}:{},body:JSON.stringify(body)});
 const send=async()=>{const r=await auth.handle(req('send',{mobile:'9000000000'}),'tester');assert.equal(r.status,200);return ((await r.json()) as {challengeId:string}).challengeId;};
 const verify=(id:string,otp=code)=>auth.handle(req('verify',{mobile:'9000000000',challengeId:id,otp}),'tester');
 try{
  const id=await send();
  assert.equal((await auth.handle(req('send',{mobile:'9000000000'}),'tester')).status,429);
  const outcomes=await Promise.all(Array.from({length:8},()=>verify(id)));
  assert.equal(outcomes.filter(r=>r.status===200).length,1);
  const session=await outcomes.find(r=>r.status===200)!.json() as {token:string;accountId:string};
  assert.equal(await auth.account(req('session',{},session.token),'tester'),session.accountId);
  assert.equal(await auth.account(req('session',{},session.token),'other'),null);
  await auth.handle(req('logout',{},session.token),'tester');
  assert.equal(await auth.account(req('session',{},session.token),'tester'),null);
  now+=61000;const wrongId=await send();const right=code;
  const wrong=right==='123456'?'654321':'123456';
  for(let i=0;i<5;i++)assert.equal((await verify(wrongId,wrong)).status,400);
  assert.equal((await verify(wrongId,right)).status,400);
  now+=61000;const expired=await send();now+=300001;
  assert.equal((await verify(expired)).status,400);
  const old=await send();const oldCode=code;now+=61000;
  const fresh=await send();assert.equal((await verify(old,oldCode)).status,400);
  assert.equal((await verify(fresh)).status,200);
 }finally{await db.close();}
});
