import test from 'node:test';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../runtime/tester-access.ts', import.meta.url), 'utf8'), {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {admitTesterRequest,officeTesterIdentity} = await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
test('chat continues past the old daily allowance but still requires the profile owner', async () => {
  const db = {transaction: fn => fn({query: async sql => {
    assert.ok(sql.startsWith('SELECT tester_key'), 'chat must not reserve a daily question allowance');
    return {rows:[{tester_key:'owner'}]};
  }})};
  for(let i=0;i<45;i++) assert.equal(await admitTesterRequest(db,'owner','/api/guidance','nirayana_pilot_session=profile-one'),200);
  assert.equal(await admitTesterRequest(db,'someone-else','/api/guidance','nirayana_pilot_session=profile-one'),403);
  assert.equal(await admitTesterRequest(db,'owner','/api/guidance',''),400);
});

test('office invitation keeps identity and rejects wrong or expired codes',()=>{
 const original='a'.repeat(48),hash=v=>createHash('sha256').update(v).digest('hex');
 const env={JYOTARA_SAMSUNG_TESTER_SHA256:hash(original),JYOTARA_SAMSUNG_TESTER_EXPIRES_AT:'2030-01-01T00:00:00Z',JYOTARA_OFFICE_ACCESS_SHA256:hash('011011')};
 const now=Date.parse('2026-09-24');
 assert.equal(officeTesterIdentity('011011',env,'/api/tester/check',now),hash(original));
 assert.equal(officeTesterIdentity(original,env,'/api/tester/check',now),hash(original));
 for(const code of ['111111','11011','0110110',undefined])assert.equal(officeTesterIdentity(code,env,'/api/tester/check',now),null);
 assert.equal(officeTesterIdentity('011011',env,'/api/tester/check',Date.parse('2031-01-01')),null);
 assert.equal(officeTesterIdentity('011011',{...env,JYOTARA_OFFICE_ACCESS_SHA256:''},'/api/tester/check',now),null);
});

test('coin-metered matching ignores an exhausted legacy daily allowance', async () => {
  let queries = 0;
  const db = {transaction: fn => fn({query: async () => {queries++; return {rows:[],rowCount:0};}})};
  for (let i=0;i<12;i++) assert.equal(await admitTesterRequest(db,'office','/api/kundli/matching','',Date.now(),undefined,true),200);
  assert.equal(queries,0,'wallet matching must not consume the shared trial counter');
  assert.equal(await admitTesterRequest(db,'office','/api/kundli/matching',''),429,'unmetered requests retain their allowance');
});

test('wallet matching exemption does not bypass other resource limits or profile ownership', async () => {
 const db={transaction:fn=>fn({query:async sql=>sql.startsWith('SELECT tester_key')?{rows:[{tester_key:'owner'}]}:{rows:[],rowCount:0}})};
 assert.equal(await admitTesterRequest(db,'office','/api/locations','',Date.now(),undefined,true),429);
 assert.equal(await admitTesterRequest(db,'other','/api/guidance','nirayana_pilot_session=profile-one',Date.now(),undefined,true),403);
 assert.equal(await admitTesterRequest(db,'office','/api/astrology/kundli','',Date.now(),undefined,true),400);
});


test('twelve-Rasi allowance is bounded and isolated by signed-in account', async () => {
  const counters = new Map();
  const db = {transaction: fn => fn({query: async (sql, values) => {
    const [key, , limit] = values;
    assert.equal(limit, 240);
    const used = counters.get(key) ?? 0;
    if (used >= limit) return {rowCount: 0, rows: []};
    counters.set(key, used + 1);
    return {rowCount: 1, rows: [{requests: used + 1}]};
  }})};
  const now = Date.parse('2026-09-25T10:00:00Z');
  for (let i = 0; i < 240; i++) assert.equal(await admitTesterRequest(db, 'office', '/api/horoscope/daily', '', now, 'one'), 200);
  assert.equal(await admitTesterRequest(db, 'office', '/api/horoscope/daily', '', now, 'one'), 429);
  assert.equal(await admitTesterRequest(db, 'office', '/api/horoscope/daily', '', now, 'two'), 200);
});
