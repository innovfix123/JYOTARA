import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {PostgresDatabase} from './postgres';
import {erasePhoneAccount} from './account-deletion';
import {reportAnswer} from './answer-reports';
import {createHash,createHmac} from 'node:crypto';
import {PhoneAuth} from './phone-auth';
import {admitTesterRequest} from './tester-access';
import {completeProfile} from '../db/profile-recovery';
import {reserveProfile} from '../db/profile-reservation';
import {completeQuestion,reserveQuestion} from '../db/guidance-requests';
import type {D1Database} from '@cloudflare/workers-types';
test('PostgreSQL erasure preserves other accounts and acknowledges concurrent retries',async()=>{
 const url=process.env.DATABASE_URL ?? '';
 if(!url.includes('jyotara_qa_erasure_20260915'))throw Error('Dedicated QA database required');
 const db=new PostgresDatabase(url);
 try {
  const dir=process.env.QA_MIGRATIONS!;
  for(const file of readdirSync(dir).filter(f=>/^\d+_.*\.sql$/.test(f)).sort())
   await db.pool.query(readFileSync(dir+'/'+file,'utf8').replace(/`([a-z_]+)`/gi,'"$1"').replace(/\binteger\b/gi,'bigint'));
  const now=Date.now();
  for(const who of ['owner','other']) {
   await db.pool.query('INSERT INTO phone_accounts VALUES($1,$2,$3,$4)',[who,who+'-hash','0000',now]);
   await db.pool.query('INSERT INTO phone_login_sessions VALUES($1,$2,$3,$4)',[who+'-token',who,'tester',now+600000]);
   await db.pool.query('INSERT INTO phone_profile_owners VALUES($1,$2)',[who+'-chart',who]);
   await db.pool.query("INSERT INTO guide_requests(id,session_id,category,language,support_level,answer_mode,created_at,question_text,response_ciphertext) VALUES($1,$2,'love','en','chart','chart',$3,'private question','private answer')",[who+'-reply',who+'-chart',now]);
   await db.pool.query("INSERT INTO profile_generations(id,session_id,day_key,status,created_at,updated_at,response_ciphertext) VALUES($1,$2,'today','completed',$3,$3,'private chart')",[who+'-generation',who+'-chart',now]);
  }
  const reportToken='12'.repeat(32);
  const auth=new PhoneAuth(db,{});
  assert.equal(await auth.ownProfile('nirayana_pilot_session=owner-chart','other',true),false);
  assert.equal(await auth.ownProfile('nirayana_pilot_session=new-chart','missing-account',true),false);
  assert.equal(await auth.ownProfile('nirayana_pilot_session=new-chart','owner',true),true);
  assert.equal(await admitTesterRequest(db,'public-v1','/api/astrology/kundli','nirayana_pilot_session=new-chart',now,'owner'),200);
  assert.equal(await admitTesterRequest(db,'public-v1','/api/guidance','nirayana_pilot_session=new-chart',now,'other'),403);
  for(let i=0;i<5;i++)assert.equal(await admitTesterRequest(db,'public-v1','/api/kundli/matching','',now,'owner'),200);
  assert.equal(await admitTesterRequest(db,'public-v1','/api/kundli/matching','',now,'owner'),429);
  assert.equal(await admitTesterRequest(db,'public-v1','/api/kundli/matching','',now,'other'),200);
  await db.pool.query('INSERT INTO phone_login_sessions VALUES($1,$2,$3,$4)',[createHash('sha256').update(reportToken).digest('hex'),'owner','tester',now+600000]);
  const reportRequest=()=>new Request('https://example.test/api/answers/report',{method:'POST',headers:{Authorization:'Bearer '+reportToken},body:JSON.stringify({answer:'Synthetic reported answer',guide:'Guide',reason:'harmful',consent:true})});
  assert.equal((await reportAnswer(reportRequest(),db,'ab'.repeat(32),'tester',now)).status,200);
  assert.equal((await reportAnswer(reportRequest(),db,'ab'.repeat(32),'tester',now)).status,200);
  assert.equal((await db.pool.query('SELECT * FROM answer_reports')).rowCount,1);
  assert.equal(await erasePhoneAccount(db,'owner-token','wrong',now),false);
  let clock=now,otp='';
  const phoneSecret='synthetic-deletion-otp-secret-2026';
  const phoneHash=createHmac('sha256',phoneSecret).update('phone:9000000001').digest('hex');
  await db.pool.query('INSERT INTO phone_accounts VALUES($1,$2,$3,$4)',['otp-owner',phoneHash,'0001',now]);
  const recovery=new PhoneAuth(db,{JYOTARA_OTP_ENABLED:'true',JYOTARA_PHONE_AUTH_KEY:phoneSecret,AUTHKEY_KEY:'synthetic',AUTHKEY_SID:'123'},async url=>{
    otp=new URL(String(url)).searchParams.get('otp')!;
    return Response.json({Message:'Submitted Successfully'});
  },()=>clock);
  const recoveryRequest=(path:string,body:object)=>new Request('https://example.test/api/auth/'+path,{method:'POST',body:JSON.stringify({mobile:'9000000001',...body})});
  let challenge=await (await recovery.handle(recoveryRequest('send',{}),'public-v1')).json();
  assert.equal((await recovery.handle(recoveryRequest('verify-deletion',{challengeId:challenge.challengeId,otp:'000000'}),'public-v1')).status,400);
  assert.equal((await db.pool.query("SELECT id FROM phone_accounts WHERE id='otp-owner'")).rowCount,1);
  assert.deepEqual(await (await recovery.handle(recoveryRequest('verify-deletion',{challengeId:challenge.challengeId,otp}),'public-v1')).json(),{deleted:true});
  assert.equal((await db.pool.query("SELECT id FROM phone_accounts WHERE id='otp-owner'")).rowCount,0);
  clock+=61000;
  challenge=await (await recovery.handle(recoveryRequest('send',{}),'public-v1')).json();
  assert.deepEqual(await (await recovery.handle(recoveryRequest('verify-deletion',{challengeId:challenge.challengeId,otp}),'public-v1')).json(),{deleted:true});
  assert.equal((await db.pool.query('SELECT id FROM phone_accounts WHERE phone_hash=$1',[phoneHash])).rowCount,0);
  // Simulate provider requests already running when account deletion commits.
  await db.pool.query("UPDATE profile_generations SET status='started' WHERE id='owner-generation'");
  await db.pool.query("UPDATE guide_requests SET answer_mode='pending' WHERE id='owner-reply'");
  assert.deepEqual(await Promise.all([erasePhoneAccount(db,'owner-token','tester',now),erasePhoneAccount(db,'owner-token','tester',now)]),[true,true]);
  const compatible=db as unknown as D1Database;
  await assert.rejects(completeProfile(compatible,'ab'.repeat(32),{
    id:'owner-generation',session:'owner-chart',reply:{private:'late chart'},now,expiresAt:now+60000,
  }),/could not be completed/);
  assert.equal(await completeQuestion(compatible,{
    id:'owner-reply',session:'owner-chart',support:'chart',mode:'chart',question:'late private question',
    intent:'love',consent:null,ageBand:null,ciphertext:'late private answer',expiresAt:now+60000,
  }),false);
  assert.equal(await reserveProfile(compatible,{
    id:'late-generation',session:'owner-chart',day:'tomorrow',now,limit:100,
  }),'limit');
  assert.deepEqual(await reserveQuestion(compatible,{
    id:'late-question',hash:'late-hash',session:'owner-chart',category:'love',language:'en',now,limit:null,
  }),{kind:'limit'});
  assert.equal((await db.pool.query("SELECT * FROM phone_accounts WHERE id='owner'")).rowCount,0);
  assert.equal((await db.pool.query('SELECT * FROM answer_reports')).rowCount,0);
  assert.equal(await auth.ownProfile('nirayana_pilot_session=new-chart','owner',true),false);
  assert.equal(await auth.ownProfile('nirayana_pilot_session=new-chart','other',true),false);
  assert.equal((await reportAnswer(reportRequest(),db,'ab'.repeat(32),'tester',now)).status,401);
  assert.equal((await db.pool.query("SELECT * FROM phone_login_sessions WHERE account_id='owner'")).rowCount,0);
  const erased=(await db.pool.query("SELECT * FROM guide_requests WHERE id='owner-reply'")).rows[0];
  assert.equal(erased.question_text,null);assert.equal(erased.response_ciphertext,null);
  assert.equal((await db.pool.query("SELECT status FROM profile_generations WHERE id='owner-generation'")).rows[0].status,'deleted');
  assert.equal((await db.pool.query("SELECT * FROM deleted_chart_sessions WHERE session_id='owner-chart'")).rowCount,1);
  assert.equal((await db.pool.query("SELECT question_text FROM guide_requests WHERE id='other-reply'")).rows[0].question_text,'private question');
  assert.equal((await db.pool.query("SELECT * FROM phone_accounts WHERE id='other'")).rowCount,1);
  assert.equal(await erasePhoneAccount(db,'owner-token','wrong',now),false);
 }finally{await db.close();}
});
