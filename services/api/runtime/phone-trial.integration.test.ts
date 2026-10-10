import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,createHmac} from 'node:crypto';
import {PostgresDatabase} from './postgres';
import {CoinWallet} from './coin-wallet';
import {PhoneAuth} from './phone-auth';
import {erasePhoneAccount} from './account-deletion';

const secret='synthetic-phone-trial-secret-longer-than-32';
const settings={JYOTARA_OTP_ENABLED:'true',JYOTARA_PHONE_AUTH_KEY:secret,AUTHKEY_KEY:'synthetic',AUTHKEY_SID:'123'};
const dbFor=()=>{
 if(!process.env.DATABASE_URL?.includes('jyotara_qa_trial147_phone_once'))throw Error('Isolated phone-trial QA database required');
 return new PostgresDatabase(process.env.DATABASE_URL);
};
const phoneHash=(mobile:string)=>createHmac('sha256',secret).update('phone:'+mobile).digest('hex');
async function cleanAccount(db:PostgresDatabase,account:string){
 await db.pool.query('DELETE FROM phone_login_sessions WHERE account_id=$1',[account]);
 await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[account]);
}
test('migration backfills prior trial and purchase eligibility without claiming untouched offers',async()=>{
 const db=dbFor();
 try{
  const rows=(await db.pool.query("SELECT phone_hash FROM phone_trial_claims WHERE phone_hash LIKE 'migration-phone-%' ORDER BY phone_hash")).rows;
  assert.deepEqual(rows.map(row=>row.phone_hash),['migration-phone-legacy','migration-phone-paid','migration-phone-used']);
 }finally{await db.close();}
});
function harness(db:PostgresDatabase,mode:'live'|'test',mobile:string){
 let clock=Date.now(),otp='',token='',account='';
 const auth=new PhoneAuth(db,settings,async url=>{otp=new URL(String(url)).searchParams.get('otp')!;return Response.json({Message:'Submitted Successfully'});},()=>clock);
 const wallet=new CoinWallet(db,{JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64)},{configured:()=>true,account:(tx,request,tester)=>auth.account(request,tester),provider:async()=>{throw Error('No payment/provider calls');}},mode);
 const request=(path:string,body:any)=>new Request('https://example.test/api/'+path,{method:'POST',headers:{Authorization:'Bearer '+token,'x-jyotara-wallet-catalog':'2'},body:JSON.stringify(body)});
 return {wallet,
  get account(){return account;},get token(){return token;},
  async signIn(){clock+=61000;const sent:any=await (await auth.handle(request('auth/send',{mobile}),'public-v1')).json();assert.ok(sent.challengeId,sent.error);const verified=await auth.handle(request('auth/verify',{mobile,challengeId:sent.challengeId,otp}),'public-v1');assert.equal(verified.status,200);const data:any=await verified.json();token=data.token;account=data.accountId;assert.ok(token&&account);},
  async trial(operation:string,patch:any={}){return wallet.handle(request('wallet/intro-trial',{operation,...patch}),'public-v1');},
  question(id:string,session='a'.repeat(32)){return {requestId:'phone-once-question-'+id,profileId:'profile1',guide:'Meera',question:'What does my reading suggest about love?',category:'Love',depth:'standard',responseMode:'conversation',responseStyle:'english',language:'en',billingVersion:2,billingSession:session};},
  async quote(payload:any){return wallet.handle(request('wallet/quote',{action:'guidance',payload}),'public-v1');},
  async run(payload:any,handler:any=async()=>Response.json({answer:'A useful answer.',answerMode:'provider_reading'})){const quote:any=await (await this.quote(payload)).json();assert.ok(quote.quote,quote.error);return wallet.run(request('guidance',{...payload,coinQuote:quote.quote}),account,'guidance',handler);},
 };
}

for(const mode of ['live','test'] as const)test(mode+' one phone: verified registration, resume, deletion and re-registration never renew the trial',async()=>{
 const db=dbFor(),mobile=mode==='live'?'9000001001':'9000001002',h=harness(db,mode,mobile);
 try{
  await h.signIn();const original=h.account;
  assert.equal((await (await h.trial('status')).json() as any).state,'available');
  await h.trial('offer');
  assert.equal((await db.pool.query('SELECT 1 FROM phone_trial_claims WHERE mode=$1 AND phone_hash=$2',[mode,phoneHash(mobile)])).rows.length,0,'an offer is not a claimed trial');
  const starts=await Promise.all(Array.from({length:8},(_,i)=>h.trial('start',{guide:'Meera',billingSession:i.toString(16).padStart(32,'0')})));
  const states=await Promise.all(starts.map(r=>r.json())) as any[];
  assert.ok(starts.every(r=>r.status===200));assert.equal(new Set(states.map(s=>s.billingSession)).size,1);
  assert.equal((await db.pool.query('SELECT 1 FROM phone_trial_claims WHERE mode=$1 AND phone_hash=$2',[mode,phoneHash(mobile)])).rows.length,1);
  const session=states[0].billingSession;
  const response=await h.run(h.question(mode,session));assert.equal(response.status,200);
  assert.equal((await response.json() as any).wallet.coins,0);
  const before:any=await (await h.trial('status')).json();
  await h.signIn();assert.equal(h.account,original,'another verified login restores the same account');
  const resumed:any=await (await h.trial('start',{guide:'Nila',billingSession:'b'.repeat(32)})).json();
  assert.equal(resumed.billingSession,session);assert.ok(resumed.remainingMs<=before.remainingMs);
  assert.equal(await erasePhoneAccount(db,createHash('sha256').update(h.token).digest('hex'),'public-v1'),true);
  assert.equal((await db.pool.query('SELECT 1 FROM phone_accounts WHERE id=$1',[original])).rows.length,0);
  assert.equal((await db.pool.query('SELECT 1 FROM intro_chat_trials WHERE account_id=$1',[original])).rows.length,0);
  const retained=(await db.pool.query('SELECT * FROM phone_trial_claims WHERE mode=$1 AND phone_hash=$2',[mode,phoneHash(mobile)])).rows[0];
  assert.deepEqual(Object.keys(retained).sort(),['claimed_at','mode','phone_hash']);
  await h.signIn();assert.notEqual(h.account,original);
  assert.equal((await (await h.trial('status')).json() as any).state,'unavailable');
  assert.equal((await h.trial('start',{guide:'Meera',billingSession:'c'.repeat(32)})).status,422);
  const timed:any=await (await h.quote(h.question('recreated','c'.repeat(32)))).json();
  assert.equal(timed.cost,40);assert.equal(timed.trial,false);assert.equal(timed.canProceed,false);
  const legacy={...h.question('legacy')};delete (legacy as any).billingVersion;delete (legacy as any).billingSession;
  assert.equal((await (await h.quote(legacy)).json() as any).trial,false,'an old app cannot recover another free allowance');
  const other=harness(db,mode,mode==='live'?'9000001003':'9000001004');await other.signIn();
  assert.equal((await (await other.trial('status')).json() as any).state,'available','another unused number remains eligible');
  await cleanAccount(db,other.account);
 }finally{try{await cleanAccount(db,h.account);}finally{await db.close();}}
});

test('old one-answer trials and paid-only accounts also retain eligibility exclusions through deletion',async()=>{
 const db=dbFor();
 try{
  for(const [mobile,kind] of [['9000001005','legacy'],['9000001006','paid']]){
   const h=harness(db,'live',mobile);await h.signIn();
   if(kind==='legacy'){
    const question={...h.question('first-legacy')};delete (question as any).billingVersion;delete (question as any).billingSession;
    const response=await h.run(question);assert.equal(response.status,200);assert.equal((await response.json() as any).wallet.trial,true);
   }else await db.pool.query("INSERT INTO live_wallet_orders(id,account_id,request_id,pack_id,amount,coins,remaining,status,created_at,updated_at) VALUES($1,$2,$1,'minuteentry',2500,40,40,'paid',$3,$3)",['phone-once-paid',h.account,Date.now()]);
   assert.equal(await erasePhoneAccount(db,createHash('sha256').update(h.token).digest('hex'),'public-v1'),true);
   await h.signIn();assert.equal((await (await h.trial('status')).json() as any).state,'unavailable');
   await cleanAccount(db,h.account);
  }
 }finally{await db.close();}
});

test('skipping or merely seeing an offer does not create a used-phone marker',async()=>{
 const db=dbFor(),h=harness(db,'live','9000001007');
 try{
  await h.signIn();await h.trial('offer');await h.trial('skip');
  assert.equal((await (await h.trial('status')).json() as any).state,'skipped');
  await erasePhoneAccount(db,createHash('sha256').update(h.token).digest('hex'),'public-v1');
  await h.signIn();assert.equal((await (await h.trial('status')).json() as any).state,'available');
 }finally{try{await cleanAccount(db,h.account);}finally{await db.close();}}
});
