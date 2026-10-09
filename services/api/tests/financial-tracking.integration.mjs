import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {PostgresDatabase} from '../runtime/postgres.ts';
import * as tracking from '../runtime/financial-tracking.ts';
import {guidanceStatus} from '../runtime/guidance-status.ts';
import {issueChartTicket} from '../lib/chart-ticket.ts';
import {deleteChartSession} from '../db/profile-deletion.ts';

// This entry is bundled for disposable PostgreSQL QA only, never production.
const connection=process.env.DATABASE_URL;
if(!connection||!/^\/jyotara_qa_cost_tracking_\d+$/.test(new URL(connection).pathname))throw Error('Disposable cost-tracking database required');
const db=new PostgresDatabase(connection);
const secret='a3'.repeat(32),session='qa-session',profile='00000000-0000-4000-8000-000000000001',requestId='qa-request-00000001';
const chart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',lagna:'Mithuna',planets:[],yogas:[],currentDasha:{name:'Mercury',start:'2020-01-01T00:00:00Z',end:'2040-01-01T00:00:00Z'},currentAntardasha:{name:'Venus',start:'2020-01-01T00:00:00Z',end:'2040-01-01T00:00:00Z'}};
const ticket=await issueChartTicket(secret,{sessionId:session,profileId:profile,birthTimeKnown:true,chart});
const identity=createHmac('sha256',Buffer.from(secret,'hex')).update(JSON.stringify(['guidance-id-v1',session,requestId])).digest('hex');
const scope=(run,extra={})=>tracking.withFinancialRequest(db,{accountId:'qa-owner',feature:'chat',requestId,profileId:profile,sessionId:session,messageCount:2,...extra},run);
const status=async(extra={},account='qa-owner',cookie=session)=>{
 const req=new Request('https://qa.invalid/api/guidance/status',{method:'POST',headers:{cookie:`nirayana_pilot_session=${cookie}`},body:JSON.stringify({requestId,profileId:profile,chartTicket:ticket,...extra})});
 const response=await guidanceStatus(req,db,account,secret);return {code:response.status,body:await response.json()};
};
const summary=async()=>Object.fromEntries(Object.entries((await db.pool.query('SELECT (SELECT count(*) FROM service_requests) requests,(SELECT count(*) FROM provider_attempts) attempts,(SELECT count(*) FROM research_chat_content) content,(SELECT COALESCE(sum(attempt_count),0) FROM service_cost_daily_totals) total_attempts')).rows[0]).map(([key,value])=>[key,Number(value)]));
test('real PostgreSQL: truthful read-only status, account/feature isolation, missing and failed costs, deletion and retention',async()=>{
 try{
  await db.pool.query("INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES('qa-owner','synthetic-owner','0000',$1),('qa-other','synthetic-other','0000',$1)",[Date.now()]);
  await db.pool.query("INSERT INTO phone_profile_owners VALUES($1,'qa-owner')",[session]);
  const before=await summary();assert.equal((await status()).body.state,'absent');assert.deepEqual(await summary(),before);
  assert.equal((await status({},'qa-other')).code,403);assert.equal((await status({},'qa-owner','qa-wrong')).code,401);assert.equal((await status({profileId:'wrong-profile'})).code,401);assert.equal((await status({requestId:'bad'})).code,422);
  await db.pool.query("INSERT INTO guide_requests(id,session_id,category,language,support_level,answer_mode,created_at,response_ciphertext) VALUES($1,$2,'Love','en','grounded','pending',$3,'encrypted-replay')",[identity,session,Date.now()]);
  assert.equal((await status()).body.state,'received');
  let attempt;
  await scope(async()=>{
   attempt=await tracking.beginProviderAttempt({provider:'openrouter',model:'openai/qa',module:'editor'});
   const beforePoll=await summary();assert.equal((await status()).body.state,'processing');assert.deepEqual(await summary(),beforePoll);
   await tracking.finishProviderAttempt(attempt,{status:'completed',costUsd:0.0004,promptTokens:100,completionTokens:20,generationId:'gen-synthetic'});
   await tracking.finishProviderAttempt(attempt,{status:'completed',costUsd:99});
   const failed=await tracking.beginProviderAttempt({provider:'divine',module:'/qa',reason:'repair'});
   await tracking.finishProviderAttempt(failed,{status:'delivery_uncertain',errorCode:'transport'});
   await tracking.recordWalletOutcome({id:'qa-wallet',status:'failed',coins:0});
   await tracking.storeResearchContent('encrypted-opt-in-only','anonymous-questions-v1');
  });
  await db.pool.query("UPDATE guide_requests SET answer_mode='divine',response_ciphertext=NULL WHERE id=$1",[identity]);
  const complete=await status();assert.equal(complete.body.state,'complete');assert.equal(complete.body.deliveryUncertain,true);assert.equal('answer' in complete.body,false);
  const attempts=(await db.pool.query('SELECT reported_cost_usd,charged_credits FROM provider_attempts ORDER BY created_at,id')).rows;
  assert.equal(attempts.length,2);assert.equal(attempts.filter(x=>x.reported_cost_usd===null).length,1);assert.equal(Number(attempts.find(x=>x.reported_cost_usd!==null).reported_cost_usd),0.0004);assert.ok(attempts.every(x=>x.charged_credits===null));
  await Promise.all([scope(async()=>{}, {feature:'matching'}),scope(async()=>{}, {accountId:'qa-other'})]);
  assert.equal((await db.pool.query('SELECT count(*) n FROM service_requests')).rows[0].n,3);
  for(let retry=0;retry<2;retry++)await scope(async()=>{const a=await tracking.beginProviderAttempt({provider:'openrouter',module:'retry',attempt:1});await tracking.finishProviderAttempt(a,{status:retry?'completed':'provider_error'});},{feature:'matching'});
  const retries=(await db.pool.query("SELECT attempt,retry_index FROM provider_attempts WHERE module='retry' ORDER BY attempt")).rows;assert.deepEqual(retries.map(x=>[x.attempt,x.retry_index]),[[1,1],[2,1]]);
  await scope(async()=>{await deleteChartSession(db,session);await tracking.storeResearchContent('must-not-return','anonymous-questions-v1');await assert.rejects(()=>tracking.beginProviderAttempt({provider:'openrouter'}));});
  assert.equal((await status()).body.state,'deleted');assert.equal((await summary()).requests,0);assert.equal((await summary()).content,0);assert.equal((await summary()).attempts,0);
  const totals=(await db.pool.query('SELECT sum(attempt_count) attempts,sum(known_usd_count) known,sum(reported_cost_usd) usd FROM service_cost_daily_totals')).rows[0];assert.equal(Number(totals.attempts),4);assert.equal(Number(totals.known),1);assert.equal(Number(totals.usd),0.0004);
  await scope(async()=>{const a=await tracking.beginProviderAttempt({provider:'openrouter',module:'free'});await tracking.finishProviderAttempt(a,{status:'provider_error',costUsd:0.0002,errorCode:'http'});await db.pool.query("DELETE FROM phone_profile_owners WHERE account_id='qa-owner'");await db.pool.query("DELETE FROM phone_accounts WHERE id='qa-owner'");await tracking.storeResearchContent('late-content','anonymous-questions-v1');});
  assert.equal((await summary()).requests,0);assert.equal((await summary()).attempts,0);assert.equal((await summary()).content,0);assert.equal((await summary()).total_attempts,5);
  await tracking.withFinancialRequest(db,{accountId:'qa-other',feature:'daily'},async()=>tracking.storeResearchContent('expiry-only','anonymous-questions-v1'));
  await tracking.cleanupFinancialContent(db,Date.now()+91*86400000);
  assert.equal((await summary()).requests,0);assert.equal((await summary()).content,0);assert.equal((await summary()).total_attempts,5);
  await tracking.cleanupFinancialContent(db,Date.now()+366*86400000);assert.equal((await summary()).total_attempts,0);
 }finally{await db.close();}
});
