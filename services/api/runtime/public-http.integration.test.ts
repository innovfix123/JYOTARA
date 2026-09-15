import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {once} from 'node:events';

test('public HTTP authenticates before admission, serves policies and accepts reports',async()=>{
  if(!(process.env.DATABASE_URL ?? '').includes('jyotara_qa_http_20260915'))throw Error('Dedicated HTTP QA database required');
  Object.assign(process.env,{PORT:'0',JYOTARA_PUBLIC_ACCESS:'true',JYOTARA_OTP_ENABLED:'true',JYOTARA_PHONE_AUTH_KEY:'synthetic-http-test-secret-for-otp',AUTHKEY_KEY:'synthetic',AUTHKEY_SID:'123',JYOTARA_CHART_TICKET_KEY:'ab'.repeat(32)});
  delete process.env.JYOTARA_TESTER_CODES_SHA256;
  delete process.env.JYOTARA_TESTER_EXPIRES_AT;
  const {database}=await import('./env');
  for(const file of readdirSync(process.env.QA_MIGRATIONS!).filter(f=>/^\d+_.*\.sql$/.test(f)).sort())
    await database.pool.query(readFileSync(process.env.QA_MIGRATIONS+'/'+file,'utf8').replace(/`([a-z_]+)`/gi,'"$1"').replace(/\binteger\b/gi,'bigint'));
  const {server}=await import('./server');
  try {
    if(!server.listening)await once(server,'listening');
    const address=server.address();
    if(!address || typeof address==='string')throw Error('No HTTP listener');
    const base='http://127.0.0.1:'+address.port;
    const post=(path:string,body:object={},token?:string,cookie?:string)=>fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...(cookie?{Cookie:cookie}:{})},body:JSON.stringify(body)});
    assert.equal((await fetch(base+'/privacy')).status,200);
    const deletion=await fetch(base+'/delete-account');
    assert.match(await deletion.text(),/mailto:saran@innovfix.in/);
    assert.match(deletion.headers.get('content-security-policy')!,/frame-ancestors 'none'/);
    assert.deepEqual(await (await post('/api/auth/config')).json(),{enabled:true});
    for(const path of ['/api/astrology/kundli','/api/guidance','/api/locations','/api/kundli/matching','/api/horoscope/daily','/api/answers/report'])
      assert.equal((await post(path)).status,401,path);
    assert.equal((await database.pool.query('SELECT * FROM tester_daily_usage')).rowCount,0);
    assert.equal((await post('/api/auth/send',{mobile:'bad'})).status,422);
    const token='12'.repeat(32);
    await database.pool.query("INSERT INTO phone_accounts VALUES('owner','hash','0000',$1),('other','otherhash','1111',$1)",[Date.now()]);
    await database.pool.query('INSERT INTO phone_login_sessions VALUES($1,$2,$3,$4)',[createHash('sha256').update(token).digest('hex'),'owner','public-v1',Date.now()+60000]);
    await database.pool.query("INSERT INTO phone_profile_owners VALUES('other-chart','other')");
    assert.equal((await post('/api/auth/session',{},token)).status,200);
    assert.equal((await post('/api/guidance',{},token,'nirayana_pilot_session=other-chart')).status,403);
    const report={answer:'Synthetic HTTP report',guide:'Guide',reason:'harmful',consent:true};
    assert.deepEqual(await (await post('/api/answers/report',report,token)).json(),{reported:true});
    assert.deepEqual(await (await post('/api/auth/delete-account',{confirm:true},token)).json().then(x=>({deleted:x.deleted})),{deleted:true});
    assert.equal((await post('/api/answers/report',report,token)).status,401);
    assert.equal((await database.pool.query('SELECT * FROM answer_reports')).rowCount,0);
    assert.equal((await database.pool.query("SELECT * FROM phone_accounts WHERE id='other'")).rowCount,1);
  } finally {
    await new Promise<void>((resolve,reject)=>server.close(error=>error?reject(error):resolve()));
    await database.close();
  }
});
