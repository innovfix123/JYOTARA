import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,readdirSync} from 'node:fs';
import {PostgresDatabase} from './postgres';
import {accountProfileBackup} from './account-profile-backup';
import {issueChartTicket} from '../lib/chart-ticket';
import {deleteChartSession} from '../db/profile-deletion';
import {erasePhoneAccount} from './account-deletion';
test('encrypted profile restore is account-scoped and cannot resurrect deleted data',async()=>{
 const url=process.env.DATABASE_URL??'';
 if(!url.includes('jyotara_qa_backup_118'))throw Error('Dedicated QA database required');
 const db=new PostgresDatabase(url),secret='ab'.repeat(32),now=Date.now();
 try{
  for(const file of readdirSync(process.env.QA_MIGRATIONS!).filter(f=>/^\d+_.*\.sql$/.test(f)).sort())await db.pool.query(readFileSync(process.env.QA_MIGRATIONS+'/'+file,'utf8').replace(/`([a-z_]+)`/gi,'"$1"').replace(/\binteger\b/gi,'bigint'));
  const token='12'.repeat(32),other='34'.repeat(32);
  for(const [account,key] of [['owner',token],['other',other]]){
   await db.pool.query('INSERT INTO phone_accounts VALUES($1,$2,$3,$4)',[account,account+'-hash','0000',now]);
   await db.pool.query('INSERT INTO phone_login_sessions VALUES($1,$2,$3,$4)',[createHash('sha256').update(key).digest('hex'),account,'public-v1',now+600000]);
   await db.pool.query('INSERT INTO phone_profile_owners VALUES($1,$2)',[account+'-chart',account]);
  }
  const birthDatetime='2002-07-29T12:00:00+05:30';
  const ticket=await issueChartTicket(secret,{sessionId:'owner-chart',profileId:'profile-owner',birthTimeKnown:false,birthDatetime,contextLocation:{latitude:11,longitude:77},chart:{rashi:'Meena',nakshatra:'Uttara Bhadrapada',planets:[],yogas:[]}},now);
  const profile={version:1,origin:'https://api.jyotara.in',session:'nirayana_pilot_session=owner-chart',profileKey:birthDatetime+'|11|77|false',nickname:'Private name',birthTimeKnown:false,calculatedAt:new Date(now).toISOString(),raw:{chartTicket:ticket,profileId:'profile-owner'},conversations:{secret:'private chat'},requestIds:{secret:'id'}};
  const req=(body:object,key=token)=>new Request('https://example.test/api/account/profile',{method:'POST',headers:{Authorization:'Bearer '+key},body:JSON.stringify(body)});
  const handle=(body:object,key=token)=>accountProfileBackup(req(body,key),db,secret,'public-v1');
  assert.equal((await handle({action:'save',profile})).status,200);
  const stored=(await db.pool.query('SELECT * FROM account_profile_backups')).rows[0];
  assert(!stored.payload_ciphertext.includes('Private name'));assert(!stored.payload_ciphertext.includes(birthDatetime));
  const restored:any=await (await handle({action:'load'})).json();assert.equal(restored.profile.nickname,'Private name');assert.equal(restored.profile.conversations,undefined);assert.equal(restored.profile.requestIds,undefined);
  assert.deepEqual(await (await handle({action:'load'},other)).json(),{profile:null});
  assert.equal((await handle({action:'save',profile},other)).status,403);
  assert.equal((await handle({action:'save',profile:{...profile,raw:{chartTicket:'tampered',profileId:'profile-owner'}}})).status,422);
  assert.equal((await handle({action:'save',profile:{...profile,profileKey:birthDatetime+'|12|77|false'}})).status,422);
  assert.equal((await handle({action:'load'},'00'.repeat(32))).status,401);
  await deleteChartSession(db as any,'owner-chart');assert.deepEqual(await (await handle({action:'load'})).json(),{profile:null});assert.equal((await handle({action:'save',profile})).status,403);
  await db.pool.query('DELETE FROM deleted_chart_sessions WHERE session_id=$1',['owner-chart']);
  await handle({action:'save',profile});
  assert.equal(await erasePhoneAccount(db,createHash('sha256').update(token).digest('hex'),'public-v1',now),true);
  assert.equal((await db.pool.query('SELECT * FROM account_profile_backups')).rowCount,0);
  assert.equal((await handle({action:'save',profile})).status,401);
 }finally{await db.close();}
});
