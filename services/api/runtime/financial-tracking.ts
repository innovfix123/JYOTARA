import {AsyncLocalStorage} from 'node:async_hooks';
import {randomUUID} from 'node:crypto';
import type {PostgresDatabase} from './postgres';

type Scope={db:PostgresDatabase;id:string;accountId:string;feature:string;deleted:boolean};
const contexts=new AsyncLocalStorage<Scope>();
const opaque=/^[A-Za-z0-9_-]{1,128}$/;
const clientRequestId=/^[A-Za-z0-9_-]{16,128}$/;
const profileUuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const token=(value:unknown,max=128)=>typeof value==='string'&&value.length<=max&&/^[A-Za-z0-9_.:/@+-]+$/.test(value)?value:null;
const count=(value:unknown)=>typeof value==='number'&&Number.isSafeInteger(value)&&value>=0?value:null;
const cost=(value:unknown)=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=100000?value:null;
const statuses=new Set(['completed','received','provider_error','delivery_uncertain','unknown','failed','cancelled']);
const errors=new Set(['timeout','transport','http','invalid_json','invalid_source','invalid_output','truncated_output','unknown','deleted','unavailable']);
const safeError=(value:unknown)=>typeof value==='string'&&errors.has(value)?value:null;
export function financialScope(){return contexts.getStore();}
export function reportedOpenRouterUsage(body:any){
 const u=body?.usage;
 return {costUsd:cost(u?.cost),promptTokens:count(u?.prompt_tokens??u?.input_tokens),completionTokens:count(u?.completion_tokens??u?.output_tokens),reasoningTokens:count(u?.completion_tokens_details?.reasoning_tokens??u?.output_tokens_details?.reasoning_tokens),cachedTokens:count(u?.prompt_tokens_details?.cached_tokens??u?.input_tokens_details?.cached_tokens),generationId:token(body?.id),returnedModel:token(body?.model)};
}

/** The verified account comes from authentication, never JSON or a client ID. */
export async function withFinancialRequest<T>(db:PostgresDatabase,input:{accountId:string;feature:string;requestId?:unknown;profileId?:unknown;sessionId?:string|null;walletMode?:string;messageCount?:number},run:()=>Promise<T>):Promise<T>{
 const client=typeof input.requestId==='string'&&clientRequestId.test(input.requestId)?input.requestId:randomUUID();
 const profile=typeof input.profileId==='string'&&profileUuid.test(input.profileId)?input.profileId:'none';
 const id=randomUUID(),now=Date.now();
 const row=(await db.pool.query(`INSERT INTO service_requests(id,account_id,client_request_id,profile_id,session_id,feature,wallet_mode,message_count,created_at,updated_at)
 VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$9) ON CONFLICT(account_id,client_request_id,profile_id,feature) DO UPDATE SET updated_at=excluded.updated_at RETURNING id`,[id,input.accountId,client,profile,input.sessionId??null,input.feature,input.walletMode??null,Math.min(4,count(input.messageCount)??0),now])).rows[0];
 return contexts.run({db,id:row.id,accountId:input.accountId,feature:input.feature,deleted:false},run);
}
export async function markRequestState(state:'received'|'processing'|'complete'|'failed',input:{httpStatus?:number;errorCode?:string;deliveryUncertain?:boolean;replayed?:boolean}={}){
 const s=contexts.getStore();if(!s)return;
 await s.db.pool.query(`UPDATE service_requests SET state=CASE WHEN state='complete' THEN state ELSE $1 END,http_status=COALESCE($2,http_status),error_code=$3,delivery_uncertain=$4,replay_count=replay_count+$5,updated_at=$6 WHERE id=$7`,[state,count(input.httpStatus),safeError(input.errorCode),input.deliveryUncertain?1:0,input.replayed?1:0,Date.now(),s.id]);
}
export async function recordWalletOutcome(input:{id?:unknown;status?:unknown;coins?:unknown}){
 const s=contexts.getStore();if(!s)return;
 await s.db.pool.query(`UPDATE service_requests SET wallet_usage_id=$1,wallet_status=$2,coins=$3,updated_at=$4 WHERE id=$5`,[typeof input.id==='string'&&opaque.test(input.id)?input.id:null,['reserved','complete','failed'].includes(String(input.status))?input.status:null,count(input.coins),Date.now(),s.id]);
}
export async function markCacheOutcome(status:'hit'|'coalesced'){
 const s=contexts.getStore();if(!s)return;
 await s.db.pool.query('UPDATE service_requests SET cache_status=$1,updated_at=$2 WHERE id=$3',[status,Date.now(),s.id]);
}
type Begin={provider:string;model?:string;module?:string;attempt?:number;reason?:'initial'|'repair'|'translation'|'wording'|'calculation'};
export async function beginProviderAttempt(input:Begin):Promise<string|null>{
 const s=contexts.getStore();if(!s)return null;
 const provider=['divine','openrouter','prokerala'].includes(input.provider)?input.provider:'unknown';
 const model=token(input.model)??'unknown',module=token(input.module)??'default',reason=['initial','repair','translation','wording','calculation'].includes(input.reason??'initial')?input.reason??'initial':'initial';
 const id=randomUUID(),now=Date.now(),day=new Date(now).toISOString().slice(0,10);
 return s.db.transaction(async tx=>{
  // A deletion racing provider dispatch must stop dispatch, never resurrect data.
  const owner=await tx.query('SELECT 1 FROM service_requests WHERE id=$1 AND account_id=$2 FOR KEY SHARE',[s.id,s.accountId]);
  if(!owner.rows.length)throw Error('Request no longer active');
  // Every actual dispatch is a new attempt, including retrying the same client
  // request after failure. An adapter-local attempt index is not a unique ID.
  const ordinal=Number((await tx.query('SELECT COALESCE(max(attempt),0)+1 AS attempt FROM provider_attempts WHERE request_id=$1 AND provider=$2 AND module=$3 AND reason=$4',[s.id,provider,module,reason])).rows[0].attempt);
  const started=(await tx.query(`INSERT INTO provider_attempts(id,request_id,provider,module,model,attempt,retry_index,reason,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)
   ON CONFLICT(request_id,provider,module,attempt,reason) DO NOTHING RETURNING id`,[id,s.id,provider,module,model,Math.max(1,ordinal),count(input.attempt),reason,now])).rows[0];
  if(!started)throw Error('Provider attempt already recorded');
  await tx.query(`INSERT INTO service_cost_daily_totals(day_key,feature,provider,model,attempt_count) VALUES($1,$2,$3,$4,1) ON CONFLICT(day_key,feature,provider,model) DO UPDATE SET attempt_count=service_cost_daily_totals.attempt_count+1`,[day,s.feature,provider,model]);
  await tx.query("UPDATE service_requests SET state=CASE WHEN state='complete' THEN state ELSE 'processing' END,updated_at=$1 WHERE id=$2",[now,s.id]);
  return id;
 });
}
type Finish={status:string;httpStatus?:number;costUsd?:number|null;credits?:number|null;promptTokens?:number|null;completionTokens?:number|null;reasoningTokens?:number|null;cachedTokens?:number|null;generationId?:string|null;returnedModel?:string|null;errorCode?:string|null;validation?:string|null};
export async function finishProviderAttempt(id:string|null,input:Finish):Promise<void>{
 const s=contexts.getStore();if(!s||!id)return;
 const status=statuses.has(input.status)?input.status:/^http_[1-5]\d\d$/.test(input.status)?input.status:'unknown';
 const usd=cost(input.costUsd),credits=count(input.credits),now=Date.now();
 await s.db.transaction(async tx=>{
  const row=(await tx.query(`UPDATE provider_attempts SET status=$1,http_status=$2,reported_cost_usd=$3,charged_credits=$4,prompt_tokens=$5,completion_tokens=$6,reasoning_tokens=$7,cached_tokens=$8,generation_id=$9,returned_model=$10,error_code=$11,validation=$12,finished_at=$13,latency_ms=$13-created_at WHERE id=$14 AND request_id=$15 AND finished_at IS NULL RETURNING provider,model,created_at`,[status,count(input.httpStatus),usd,credits,count(input.promptTokens),count(input.completionTokens),count(input.reasoningTokens),count(input.cachedTokens),token(input.generationId),token(input.returnedModel),safeError(input.errorCode),safeError(input.validation),now,id,s.id])).rows[0];
  if(!row)return; // Already finished or erased; no second cost or content restore.
  const day=new Date(Number(row.created_at)).toISOString().slice(0,10),uncertain=['delivery_uncertain','unknown'].includes(status),failed=!['completed','received','http_200'].includes(status);
  await tx.query(`UPDATE service_cost_daily_totals SET finished_count=finished_count+1,failed_count=failed_count+$1,uncertain_count=uncertain_count+$2,known_usd_count=known_usd_count+$3,known_credit_count=known_credit_count+$4,reported_cost_usd=reported_cost_usd+$5,charged_credits=charged_credits+$6 WHERE day_key=$7 AND feature=$8 AND provider=$9 AND model=$10`,[failed?1:0,uncertain?1:0,usd===null?0:1,credits===null?0:1,usd??0,credits??0,day,s.feature,row.provider,row.model]);
  if(uncertain)await tx.query('UPDATE service_requests SET delivery_uncertain=1 WHERE id=$1',[s.id]);
 });
}
/** Content is encrypted by the caller and exists only for explicit research opt-in. */
export async function storeResearchContent(ciphertext:string,consentVersion:string){
 const s=contexts.getStore();if(!s)return;
 const now=Date.now();
 await s.db.pool.query(`INSERT INTO research_chat_content(request_id,consent_version,ciphertext,created_at,expires_at) SELECT $1,$2,$3,$4,$5 WHERE EXISTS(SELECT 1 FROM service_requests WHERE id=$1) ON CONFLICT(request_id) DO NOTHING`,[s.id,consentVersion,ciphertext,now,now+90*86400000]);
}
export async function cleanupFinancialContent(db:PostgresDatabase,now=Date.now()){
 await db.pool.query('DELETE FROM research_chat_content WHERE expires_at<=$1',[now]);
 // Account-bound diagnostics are bounded; anonymous daily totals survive.
 await db.pool.query('DELETE FROM service_requests WHERE created_at<$1',[now-90*86400000]);
 await db.pool.query('DELETE FROM service_cost_daily_totals WHERE day_key<$1',[new Date(now-365*86400000).toISOString().slice(0,10)]);
}
