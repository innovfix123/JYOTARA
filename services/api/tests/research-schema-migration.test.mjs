import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';

test('research migrations upgrade the original pilot without deleting requests or inventing consent', () => {
  const db = new DatabaseSync(':memory:');
  const migration = name => readFileSync(new URL(`../drizzle/${name}`, import.meta.url), 'utf8');
  try {
    db.exec(migration('0000_perpetual_giant_man.sql'));
    db.exec(migration('0001_chilly_purple_man.sql'));
    db.prepare('INSERT INTO guide_requests VALUES (?, ?, ?, ?, ?, ?, ?)')
      .run('old-request', 'test-session', 'Career', 'en', 'limited', 'grounded_fallback', 1);
    assert.throws(() => db.prepare('SELECT question_text FROM guide_requests'), /no such column/);
    db.exec('BEGIN');
    db.exec(migration('0002_broad_spacker_dave.sql'));
    db.exec(migration('0003_reflective_betty_ross.sql'));
    db.exec('COMMIT');
    const row = db.prepare('SELECT * FROM guide_requests').get();
    assert.equal(row.id, 'old-request');
    for (const field of ['question_text', 'intent', 'research_consent_version', 'age_band']) {
      assert.equal(row[field], null);
    }
    db.prepare('UPDATE guide_requests SET question_text = NULL, research_consent_version = NULL WHERE question_text IS NOT NULL AND created_at < ?').run(Date.now());
    assert.equal(db.prepare('SELECT COUNT(*) AS count FROM guide_requests').get().count, 1);
  } finally { db.close(); }
});
