import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import ts from 'typescript';

const source = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const { currentContext } = await import(url(compile(source('../db/current-context.ts'))));
const evidence = url(compile(source('../lib/astrology-evidence.ts')));
const { normalizeProviderContext } = await import(url(compile(source('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence)));

function database() {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(source('../drizzle/0008_damp_marvex.sql'));
  const db = { prepare(sql) {
    let args = [];
    return { bind(...values) { args = values; return this; },
      async first() { return sqlite.prepare(sql).get(...args) ?? null; },
      async run() { return { meta: { changes: Number(sqlite.prepare(sql).run(...args).changes) } }; } };
  } };
  return { sqlite, db };
}
const location = { latitude: 11.3428, longitude: 77.7274 };
const time = text => Date.parse(text);

test('provider context rejects contradictory signs and duplicated planets', () => {
  const at = new Date('2026-09-07T04:30:00Z');
  const planet = { id: 5, name: 'Jupiter', degree: 10, position: 4, rasi: { name: 'Karka' } };
  assert.throws(() => normalizeProviderContext({ transitPosition: { data: { planet_position: [{ ...planet, position: 5 }] } } }, at));
  assert.throws(() => normalizeProviderContext({ transitPosition: { data: { planet_position: [planet, planet] } } }, at));
});

test('current context caches timed provider data and reselects Panchang at a transition', async () => {
  const { sqlite, db } = database();
  const calls = [];
  const fetcher = async (module, at, place) => {
    calls.push({ module, at, place });
    return module === 'transit'
      ? { data: { planet_position: [{ id: 5, name: 'Jupiter', degree: 10, position: 4, rasi: { name: 'Karka' } }] } }
      : { data: { vaara: 'Monday', tithi: [
        { name: 'First', start: '2026-09-07T00:00:00+05:30', end: '2026-09-07T10:10:00+05:30' },
        { name: 'Second', start: '2026-09-07T10:10:00+05:30', end: '2026-09-08T00:00:00+05:30' },
      ] } };
  };
  try {
    const at = time('2026-09-07T10:00:00+05:30');
    const raw = await currentContext(db, location, fetcher, at);
    assert.equal(raw.status, 'complete');
    assert.equal(calls.length, 2);
    assert.equal(normalizeProviderContext(raw, new Date(at)).todayPanchang.tithi, 'First');
    const later = time('2026-09-07T10:15:00+05:30');
    const cached = await currentContext(db, location, fetcher, later);
    assert.equal(calls.length, 2);
    assert.equal(cached.contextCalculatedAt, raw.contextCalculatedAt, 'cache hit must not claim a new transit acquisition');
    assert.equal(normalizeProviderContext(cached, new Date(later)).todayPanchang.tithi, 'Second');
    await currentContext(db, location, fetcher, time('2026-09-07T10:30:00+05:30'));
    assert.equal(calls.length, 3, 'hour boundary refreshes only transits');
    assert.equal(calls.at(-1).module, 'transit');
    await currentContext(db, { latitude: 13, longitude: 80 }, fetcher, later);
    assert.equal(calls.length, 5, 'different location cannot reuse local Panchang');
  } finally { sqlite.close(); }
});

test('Indian midnight invalidates both modules even within the same UTC hour', async () => {
  const { sqlite, db } = database();
  let calls = 0;
  const fetcher = async () => { calls++; return { data: {} }; };
  try {
    await currentContext(db, location, fetcher, time('2026-09-07T23:59:00+05:30'));
    await currentContext(db, location, fetcher, time('2026-09-08T00:00:00+05:30'));
    assert.equal(calls, 4);
  } finally { sqlite.close(); }
});

test('concurrent requests claim each module once and a failed module is not silently retried', async () => {
  const { sqlite, db } = database();
  let release;
  const wait = new Promise(resolve => { release = resolve; });
  let calls = 0;
  const fetcher = async module => { calls++; await wait; if (module === 'panchang') throw new Error('Synthetic timeout'); return { data: {} }; };
  const now = time('2026-09-07T10:00:00+05:30');
  try {
    const first = currentContext(db, location, fetcher, now);
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(calls, 2);
    const overlap = await currentContext(db, location, fetcher, now);
    assert.equal(overlap.status, 'unavailable');
    release();
    assert.equal((await first).status, 'partial');
    assert.equal((await currentContext(db, location, fetcher, now + 1)).status, 'partial');
    assert.equal(calls, 2);
  } finally { release(); sqlite.close(); }
});

test('context daily safety cap prevents calls and invalid locations fail before transport', async () => {
  const { sqlite, db } = database();
  const now = time('2026-09-07T10:00:00+05:30');
  for (let i = 0; i < 120; i++) sqlite.prepare('INSERT INTO current_context_cache VALUES (?, ?, ?, NULL, ?, ?)').run(`occupied-${i}`, '2026-09-07', 'pending', now, now + 3600000);
  let calls = 0;
  try {
    const fetcher = async () => { calls++; return { data: {} }; };
    assert.equal((await currentContext(db, location, fetcher, now)).status, 'unavailable');
    await assert.rejects(currentContext(db, { latitude: NaN, longitude: 80 }, fetcher, now));
    assert.equal(calls, 0);
  } finally { sqlite.close(); }
});
