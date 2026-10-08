import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import ts from 'typescript';
import {moduleFor} from './helpers/load.mjs';
const source = readFileSync(new URL('../db/profile-reservation.ts', import.meta.url), 'utf8');
const code = ts.transpileModule(source, {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const { reserveProfile } = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
function database() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../drizzle/0004_powerful_juggernaut.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0009_salty_skrulls.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0010_green_johnny_blaze.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0011_report_evidence.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0022_profile_corrections.sql', import.meta.url), 'utf8'));
  const db = {prepare(sql) { let args=[]; return {
    bind(...values) {args=values;return this;},
    async run() {return {meta:{changes:Number(sqlite.prepare(sql).run(...args).changes)}};},
    async first() {return sqlite.prepare(sql).get(...args) ?? null;},
  };}};
  return {sqlite,db};
}
const base = {day:'2026-09-07',now:1000,limit:60};
test('overlapping sessions cannot exceed the daily 60-profile cap', async () => {
  const {sqlite,db}=database();
  try {
    const results=await Promise.all(Array.from({length:100},(_,i)=>reserveProfile(db,{...base,id:`id-${i}`,session:`session-${i}`})));
    assert.equal(results.filter(v=>v==='claimed').length,60);
    assert.equal(results.filter(v=>v==='limit').length,40);
    assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM profile_generations').get().n,60);
  } finally {sqlite.close();}
});
test('same session is reserved once; failed and stale requests never automatically restart', async () => {
  const {sqlite,db}=database();
  try {
    const results=await Promise.all(Array.from({length:20},(_,i)=>reserveProfile(db,{...base,id:`id-${i}`,session:'same-session'})));
    assert.equal(results.filter(v=>v==='claimed').length,1);
    assert.equal(results.filter(v=>v==='existing').length,19);
    for (const status of ['started','failed','success']) {
      sqlite.prepare('UPDATE profile_generations SET status=?').run(status);
      assert.equal(await reserveProfile(db,{...base,id:`retry-${status}`,session:'same-session',now:99999999}),'existing');
      assert.equal(sqlite.prepare('SELECT status FROM profile_generations').get().status,status);
    }
    assert.equal(await reserveProfile(db,{...base,id:'tomorrow',session:'same-session',day:'2026-09-08'}),'claimed');
  } finally {sqlite.close();}
});
test('failed attempts still consume the budget and cannot be recycled by another session', async () => {
  const {sqlite,db}=database();
  try {
    assert.equal(await reserveProfile(db,{...base,limit:1,id:'first',session:'first'}),'claimed');
    sqlite.prepare("UPDATE profile_generations SET status='failed'").run();
    assert.equal(await reserveProfile(db,{...base,limit:1,id:'next',session:'next'}),'limit');
    assert.equal(await reserveProfile(db,{...base,limit:1,id:'retry',session:'first'}),'existing');
  } finally {sqlite.close();}
});

test('corrections are allowed while identical failed, overlapping and recovered updates remain reserved',async()=>{
 const {sqlite,db}=database();try{
  const first={...base,session:'editable',id:'first',hash:'original-details'};
  assert.equal(await reserveProfile(db,first),'claimed');
  sqlite.prepare("UPDATE profile_generations SET status='success' WHERE id='first'").run();
  const correction={...first,id:'correction',hash:'corrected-time'};
  const results=await Promise.all(Array.from({length:10},(_,i)=>reserveProfile(db,{...correction,id:'correction-'+i})));
  assert.equal(results.filter(v=>v==='claimed').length,1);
  assert.equal(results.filter(v=>v==='existing').length,9);
  sqlite.prepare("UPDATE profile_generations SET status='failed' WHERE request_hash='corrected-time'").run();
  assert.equal(await reserveProfile(db,correction),'existing');
  assert.equal(await reserveProfile(db,{...first,id:'again-original'}),'existing');
  assert.equal(await reserveProfile(db,{...first,id:'place',hash:'corrected-place'}),'claimed');
  for(let i=3;i<10;i++)assert.equal(await reserveProfile(db,{...first,id:'change-'+i,hash:'details-'+i}),'claimed');
  assert.equal(await reserveProfile(db,{...first,id:'eleventh',hash:'details-eleventh'}),'limit');
  assert.equal(sqlite.prepare('SELECT COUNT(*) n FROM profile_generations').get().n,10);
 }finally{sqlite.close();}
});

test('recovery selects the matching corrected chart rather than the first chart of the day',async()=>{
 const {sqlite,db}=database();
 const {completeProfile,recoverProfile}=await import(moduleFor('../db/profile-recovery.ts'));
 const secret='a3'.repeat(32);
 try{
  for(const [id,hash] of [['original','first-hash'],['corrected','second-hash']]){
   assert.equal(await reserveProfile(db,{...base,session:'same',id,hash}),'claimed');
   await completeProfile(db,secret,{id,session:'same',reply:{profileId:id},now:1000,expiresAt:10000});
  }
  assert.deepEqual(await recoverProfile(db,secret,{session:'same',day:base.day,hash:'second-hash',now:2000}),{profileId:'corrected'});
  assert.deepEqual(await recoverProfile(db,secret,{session:'same',day:base.day,hash:'first-hash',now:2000}),{profileId:'original'});
  assert.equal(await recoverProfile(db,secret,{session:'same',day:base.day,hash:'unknown',now:2000}),null);
 }finally{sqlite.close();}
});
