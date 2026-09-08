import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import ts from 'typescript';
const source = readFileSync(new URL('../db/profile-reservation.ts', import.meta.url), 'utf8');
const code = ts.transpileModule(source, {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const { reserveProfile } = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
function database() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../drizzle/0004_powerful_juggernaut.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0009_salty_skrulls.sql', import.meta.url), 'utf8'));
  sqlite.exec(readFileSync(new URL('../drizzle/0010_green_johnny_blaze.sql', import.meta.url), 'utf8'));
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
