import {readFileSync} from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import test from 'node:test';
import assert from 'node:assert/strict';
import {moduleFor} from './helpers/load.mjs';
const tracking=await import(moduleFor('../runtime/financial-tracking.ts'));
const {researchContent,conversationResearchVersion}=await import(moduleFor('../runtime/research-content.ts'));
function fixture(){
 const sqlite=new DatabaseSync(':memory:');sqlite.exec('PRAGMA foreign_keys=ON; CREATE TABLE phone_accounts(id text PRIMARY KEY); CREATE TABLE guide_requests(response_ciphertext text); INSERT INTO phone_accounts VALUES(\'owner\'),(\'other\');');
 sqlite.exec(readFileSync(new URL('../drizzle/0027_service_cost_tracking.sql',import.meta.url),'utf8'));
 const query=async(sql,values=[])=>{const bound=[];sql=sql.replace(/ FOR KEY SHARE| FOR UPDATE/g,'').replace(/\$(\d+)/g,(_,n)=>{bound.push(values[Number(n)-1]);return '?';});const statement=sqlite.prepare(sql);if(/^\s*SELECT|\bRETURNING\b/i.test(sql)){const rows=statement.all(...bound);return {rows,rowCount:rows.length};}const result=statement.run(...bound);return {rows:[],rowCount:Number(result.changes)};};
 const db={pool:{query},async transaction(run){sqlite.exec('BEGIN');try{const result=await run({query});sqlite.exec('COMMIT');return result;}catch(e){sqlite.exec('ROLLBACK');throw e;}}};
 return {db,sqlite};
}
test('actual cost survives answer cleanup; free and failed attempts count; missing cost stays null and finalization is idempotent',async()=>{
 const {db,sqlite}=fixture();
 await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'request-0000000001',profileId:'00000000-0000-4000-8000-000000000001',sessionId:'session',messageCount:2},async()=>{
  await tracking.recordWalletOutcome({id:'wallet-receipt',status:'failed',coins:0});
  const first=await tracking.beginProviderAttempt({provider:'openrouter',model:'openai/example',module:'editor'});
  await tracking.finishProviderAttempt(first,{status:'completed',costUsd:0.0004,promptTokens:150,completionTokens:30,generationId:'gen-synthetic',validation:'invalid_output'});
  await tracking.finishProviderAttempt(first,{status:'completed',costUsd:999});
  const failed=await tracking.beginProviderAttempt({provider:'openrouter',model:'openai/example',module:'editor',reason:'repair'});
  await tracking.finishProviderAttempt(failed,{status:'delivery_uncertain',errorCode:'transport'});
  await tracking.storeResearchContent('encrypted-only','anonymous-questions-v1');
 });
 sqlite.exec('UPDATE guide_requests SET response_ciphertext=NULL');
 const attempts=sqlite.prepare('SELECT * FROM provider_attempts ORDER BY created_at,id').all();
 assert.equal(attempts.length,2);assert.deepEqual(attempts.map(a=>a.reported_cost_usd).sort((a,b)=>(a??-1)-(b??-1)),[null,0.0004]);
 assert.equal(attempts.find(a=>a.status==='completed').prompt_tokens,150);
 const total=sqlite.prepare('SELECT * FROM service_cost_daily_totals').get();assert.equal(total.attempt_count,2);assert.equal(total.finished_count,2);assert.equal(total.known_usd_count,1);assert.equal(total.reported_cost_usd,0.0004);assert.equal(total.uncertain_count,1);
 assert.equal(sqlite.prepare('SELECT coins FROM service_requests').get().coins,0);
 assert.equal(sqlite.prepare('SELECT delivery_uncertain FROM service_requests').get().delivery_uncertain,1);
 sqlite.close();
});
test('account-bound cleanup erases content/attempts, cannot resurrect erased content, and preserves only anonymous totals',async()=>{
 const {db,sqlite}=fixture();
 await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'request-0000000002',profileId:'00000000-0000-4000-8000-000000000001',sessionId:'session'},async()=>{
  const attempt=await tracking.beginProviderAttempt({provider:'divine',module:'/chat'});await tracking.finishProviderAttempt(attempt,{status:'completed',credits:30});
  await tracking.storeResearchContent('encrypted-only','anonymous-questions-v1');
  sqlite.exec("DELETE FROM phone_accounts WHERE id='owner'");
  await tracking.storeResearchContent('late-content-must-not-return','anonymous-questions-v1');
  await tracking.finishProviderAttempt(attempt,{status:'completed',credits:999});
 });
 assert.equal(sqlite.prepare('SELECT count(*) n FROM service_requests').get().n,0);assert.equal(sqlite.prepare('SELECT count(*) n FROM provider_attempts').get().n,0);assert.equal(sqlite.prepare('SELECT count(*) n FROM research_chat_content').get().n,0);
 assert.equal(sqlite.prepare('SELECT charged_credits FROM service_cost_daily_totals').get().charged_credits,30);
 assert.equal(sqlite.prepare('SELECT count(*) n FROM phone_accounts').get().n,1);sqlite.close();
});
test('only allowlisted metadata is persisted; malformed token/cost/error values never become content',async()=>{
 const {db,sqlite}=fixture();
 await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'private question with spaces',profileId:'birth details with spaces'},async()=>{
  const attempt=await tracking.beginProviderAttempt({provider:'openrouter',model:'private question with spaces'});
  await tracking.finishProviderAttempt(attempt,{status:'completed',costUsd:NaN,credits:-1,promptTokens:1.5,errorCode:'Bearer private secret',generationId:'answer text with spaces'});
 });
 const row=sqlite.prepare('SELECT * FROM provider_attempts').get();assert.equal(row.model,'unknown');for(const field of ['reported_cost_usd','charged_credits','prompt_tokens','error_code','generation_id'])assert.equal(row[field],null);
 const serialized=JSON.stringify(sqlite.prepare('SELECT * FROM service_requests').all())+JSON.stringify(row);assert.ok(!serialized.includes('private question'));assert.ok(!serialized.includes('birth details'));assert.ok(!serialized.includes('Bearer'));
 assert.deepEqual(tracking.reportedOpenRouterUsage({usage:{cost:0,input_tokens:5,output_tokens:2},id:'gen-safe',model:'google/example'}),{costUsd:0,promptTokens:5,completionTokens:2,reasoningTokens:null,cachedTokens:null,generationId:'gen-safe',returnedModel:'google/example'});sqlite.close();
});
test('same request retry with adapter-local attempt one gets a new durable ordinal',async()=>{
 const {db,sqlite}=fixture();
 for(let retry=0;retry<2;retry++)await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'request-retry-00001'},async()=>{
  const attempt=await tracking.beginProviderAttempt({provider:'openrouter',module:'editor',attempt:1});
  await tracking.finishProviderAttempt(attempt,{status:retry?'completed':'provider_error',costUsd:0.0001});
  await tracking.finishProviderAttempt(attempt,{status:'completed',costUsd:99});
 });
 const attempts=sqlite.prepare('SELECT attempt,retry_index FROM provider_attempts ORDER BY attempt').all();assert.deepEqual(attempts.map(x=>[x.attempt,x.retry_index]),[[1,1],[2,1]]);
 const totals=sqlite.prepare('SELECT * FROM service_cost_daily_totals').get();assert.equal(totals.attempt_count,2);assert.equal(totals.reported_cost_usd,0.0002);sqlite.close();
});
test('research off stores no content; legacy consent permits only questions; v2 permits redacted question and reply',()=>{
 const question='Reach me at sample@example.invalid or 9876543210';
 assert.equal(researchContent({question},'reply'),null);
 assert.deepEqual(researchContent({question,researchConsent:true},'private reply'),{question:'Reach me at [email removed] or [phone removed]',consentVersion:'anonymous-questions-v1'});
 assert.equal('answer' in researchContent({question,researchConsent:true,researchConsentVersion:'unknown'},'private reply'),false);
 assert.deepEqual(researchContent({question,researchConsent:true,researchConsentVersion:conversationResearchVersion},'Reply to sample@example.invalid'),{question:'Reach me at [email removed] or [phone removed]',answer:'Reply to [email removed]',consentVersion:conversationResearchVersion});
});
test('phone/name profile values and short request identifiers never enter the metadata ledger',async()=>{
 const {db,sqlite}=fixture();
 for(const value of ['9876543210','Kavin','KavinChennaiTamil'])await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'9876543210',profileId:value},async()=>{});
 const valid='00000000-0000-4000-8000-000000000001';
 await tracking.withFinancialRequest(db,{accountId:'owner',feature:'chat',requestId:'request-valid-00001',profileId:valid},async()=>{});
 const rows=sqlite.prepare('SELECT client_request_id,profile_id FROM service_requests').all();
 assert.equal(rows.length,4);assert.equal(rows.filter(x=>x.profile_id==='none').length,3);assert.ok(rows.some(x=>x.profile_id===valid));
 for(const row of rows)assert.match(row.client_request_id,/^[A-Za-z0-9_-]{16,128}$/);
 const persisted=JSON.stringify(rows);for(const value of ['9876543210','Kavin','KavinChennaiTamil'])assert.equal(persisted.includes(value),false);
 sqlite.close();
});
