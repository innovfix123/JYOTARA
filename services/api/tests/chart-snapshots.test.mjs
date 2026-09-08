import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

const transpile = source => ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = code => `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`;
const evidence = url(transpile(readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8')));
const source = readFileSync(new URL('../db/chart-snapshots.ts', import.meta.url), 'utf8');
const storageUrl = url(transpile(source).replace('../lib/astrology-evidence', evidence));
const { saveChartSnapshot, loadChartSnapshot, deleteProfileSnapshots } = await import(storageUrl);
const ownedSource = readFileSync(new URL('../lib/owned-guidance.ts', import.meta.url), 'utf8');
const { buildOwnedGuidance } = await import(url(transpile(ownedSource)
  .replace('../db/chart-snapshots', storageUrl).replace('./astrology-evidence', evidence)));
const migration = readFileSync(new URL('../drizzle/0006_cute_may_parker.sql', import.meta.url), 'utf8');

test('actual SQLite migration and owner/profile-scoped snapshot lifecycle', async () => {
  const sqlite = new DatabaseSync(':memory:');
  try {
    sqlite.exec(migration);
    const db = { prepare(sql) {
      let values = [];
      return { bind(...input) { values = input; return this; },
        async run() { return sqlite.prepare(sql).run(...values); },
        async first() { return sqlite.prepare(sql).get(...values) ?? null; } };
    }};
    const identity = { ownerId: 'owner-one', profileId: 'profile-one' };
    const other = { ownerId: 'owner-two', profileId: 'profile-one' };
    const sibling = { ownerId: 'owner-one', profileId: 'profile-two' };
    const facts = { rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', planets: [], yogas: [] };
    const id = await saveChartSnapshot(db, identity, facts, false, 1000);
    const otherId = await saveChartSnapshot(db, other, facts, true, 1000);
    const siblingId = await saveChartSnapshot(db, sibling, facts, true, 1000);
    facts.rashi = 'Changed client data';
    const loaded = await loadChartSnapshot(db, identity, id);
    assert.equal(loaded.chart.rashi, 'Meena');
    assert.equal(loaded.birthTimeKnown, false);
    const request = { db, verifiedOwnerId: identity.ownerId, profileId: identity.profileId,
      snapshotId: id, category: 'Career', question: 'What does my chart show?', language: 'en', now: new Date(2000) };
    const owned = await buildOwnedGuidance({ ...request, chart: { rashi: 'Forged' }, birthTimeKnown: true });
    assert.equal(owned.ok, true);
    assert.equal(owned.packet.facts.find(f => f.field === 'moon_sign').value, 'Meena');
    assert.equal(owned.packet.birthTimePrecision, 'unknown');
    assert.deepEqual(await buildOwnedGuidance({ ...request, verifiedOwnerId: null }), { ok: false, status: 401 });
    assert.deepEqual(await buildOwnedGuidance({ ...request, verifiedOwnerId: other.ownerId }), { ok: false, status: 404 });
    assert.deepEqual(await buildOwnedGuidance({ ...request, profileId: sibling.profileId }), { ok: false, status: 404 });
    assert.deepEqual(await buildOwnedGuidance({ ...request, now: new Date(500) }), { ok: false, status: 409 });
    assert.equal((await buildOwnedGuidance({ ...request, now: new Date(1000 + 86400000 - 1) })).ok, true);
    assert.deepEqual(await buildOwnedGuidance({ ...request, now: new Date(1000 + 86400000) }), { ok: false, status: 409 });
    assert.ok(await loadChartSnapshot(db, identity, id), 'withholding expired guidance must not delete user data');
    assert.equal(await loadChartSnapshot(db, other, id), null);
    assert.equal(await loadChartSnapshot(db, sibling, id), null);
    assert.equal(await loadChartSnapshot(db, identity, "' OR 1=1 --"), null);
    await deleteProfileSnapshots(db, identity);
    assert.equal(await loadChartSnapshot(db, identity, id), null);
    assert.ok(await loadChartSnapshot(db, other, otherId));
    assert.ok(await loadChartSnapshot(db, sibling, siblingId));
    sqlite.prepare('UPDATE birth_chart_snapshots SET facts_json = ? WHERE id = ?').run('{broken', otherId);
    assert.equal(await loadChartSnapshot(db, other, otherId), null);
    const plan = sqlite.prepare('EXPLAIN QUERY PLAN SELECT id FROM birth_chart_snapshots WHERE owner_id = ? AND profile_id = ?').all(identity.ownerId, identity.profileId);
    assert.ok(plan.some(row => row.detail.includes('idx_birth_chart_snapshots_owner_profile')));
    await assert.rejects(saveChartSnapshot(db, identity, { ...facts, planets: [null] }, true));
  } finally { sqlite.close(); }
});
