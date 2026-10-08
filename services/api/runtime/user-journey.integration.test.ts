import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {PostgresDatabase} from './postgres';
import {userJourney} from './user-journey';

test('real PostgreSQL concurrent batches, retries and account erasure keep one ordered timeline',async()=>{
 const url=process.env.DATABASE_URL??'';
 if(!url.includes('jyotara_qa_journey_141'))throw Error('Dedicated QA journey database required');
 const db=new PostgresDatabase(url),now=Date.now(),token='12'.repeat(32);
 try{
  if(!(await db.pool.query("SELECT to_regclass('user_journey_events') AS table_name")).rows[0].table_name){
   for(const name of ['0012_phone_login.sql','0026_user_journey.sql'])await db.pool.query(readFileSync(process.env.QA_MIGRATIONS+'/'+name,'utf8').replace(/`([a-z_]+)`/gi,'"$1"').replace(/\binteger\b/gi,'bigint'));
  }
  await db.pool.query('INSERT INTO phone_accounts VALUES($1,$2,$3,$4)',['journey-owner','synthetic-private-hash','0000',now]);
  await db.pool.query('INSERT INTO phone_login_sessions VALUES($1,$2,$3,$4)',[createHash('sha256').update(token).digest('hex'),'journey-owner','public-v1',now+600000]);
  const request=(index:number)=>new Request('https://example.test/api/user-journey',{method:'POST',headers:{authorization:'Bearer '+token},body:JSON.stringify({events:[{id:index.toString(16).padStart(32,'0'),sessionId:'ab'.repeat(16),sequence:index,name:'chat.answer',screen:'chat',at:now,metadata:{outcome:'success',feature:'chat'}}]})});
  const responses=await Promise.all(Array.from({length:8},(_,index)=>userJourney(request(index+1),db,'public-v1',now)));
  assert.ok(responses.every(response=>response.status===200));
  const rows=(await db.pool.query('SELECT server_sequence FROM user_journey_events ORDER BY server_sequence')).rows;
  assert.deepEqual(rows.map(row=>row.server_sequence),[1,2,3,4,5,6,7,8]);
  await Promise.all([userJourney(request(1),db,'public-v1',now),userJourney(request(1),db,'public-v1',now)]);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM user_journey_events')).rows[0].count,8);
  await db.pool.query('DELETE FROM phone_login_sessions WHERE account_id=$1',['journey-owner']);
  await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',['journey-owner']);
  assert.equal((await db.pool.query('SELECT count(*)::int count FROM user_journey_events')).rows[0].count,0);
 }finally{await db.close();}
});
