import test from 'node:test';
import assert from 'node:assert/strict';
import { PostgresDatabase } from './postgres';
import { reserveProfile } from '../db/profile-reservation';
import { reserveQuestion } from '../db/guidance-requests';
import { deleteChartSession, chartSessionDeleted } from '../db/profile-deletion';
import type { D1Database } from '@cloudflare/workers-types';

// Run only against a new isolated QA database, with migrations applied first.
test('PostgreSQL preserves reservation budgets, idempotency, deletion and atomic rollback', async () => {
  const connection = process.env.DATABASE_URL;
  if (!connection || !new URL(connection).pathname.startsWith('/jyotara_qa_')) {
    throw new Error('An isolated jyotara_qa_ database is required');
  }
  const first = new PostgresDatabase(connection), second = new PostgresDatabase(connection);
  const db = (index: number) => (index % 2 ? first : second) as unknown as D1Database;
  const now = Date.now();
  try {
    const profiles = await Promise.all(Array.from({ length: 24 }, (_, i) => reserveProfile(db(i), {
      id: `profile-${i}`, session: `owner-${i}`, day: 'qa-day', now, limit: 3,
    })));
    assert.equal(profiles.filter(r => r === 'claimed').length, 3, 'concurrent processes must not exceed daily paid-profile cap');
    const questions = await Promise.all(Array.from({ length: 24 }, (_, i) => reserveQuestion(db(i), {
      id: `q-${i}`, hash: 'synthetic-hash', session: 'same-owner', category: 'Love', language: 'en', now, limit: 3,
    })));
    assert.equal(questions.filter(r => r.kind === 'claimed').length, 3);
    const claimedIndex = questions.findIndex(r => r.kind === 'claimed');
    assert.equal((await reserveQuestion(db(0), {
      id: `q-${claimedIndex}`, hash: 'synthetic-hash', session: 'same-owner', category: 'Love', language: 'en', now, limit: 3,
    })).kind, 'existing');
    await deleteChartSession(db(0), 'same-owner', now);
    await deleteChartSession(db(1), 'same-owner', now + 1);
    assert.equal(await chartSessionDeleted(db(0), 'same-owner', now), true);
    assert.equal((await reserveQuestion(db(0), {
      id: 'after-delete', hash: 'synthetic-hash', session: 'same-owner', category: 'Love', language: 'en', now, limit: 100,
    })).kind, 'limit');
    assert.equal(await first.prepare("SELECT COUNT(*) AS total FROM guide_requests WHERE session_id = ? AND answer_mode = 'deleted'").bind('same-owner').first('total'), 3);
    await assert.rejects(first.batch([
      first.prepare('INSERT INTO deleted_chart_sessions (session_id, expires_at) VALUES (?, ?)').bind('rollback-owner', now),
      first.prepare('INSERT INTO missing_qa_table (id) VALUES (?)').bind('fail'),
    ]));
    assert.equal(await first.prepare('SELECT session_id FROM deleted_chart_sessions WHERE session_id = ?').bind('rollback-owner').first(), null);
    await first.prepare('INSERT INTO birth_chart_snapshots (id,owner_id,profile_id,facts_json,birth_time_known,created_at) VALUES (?,?,?,?,?,?)')
      .bind('snapshot', 'owner', 'profile', '{}', 1, now).run();
    assert.deepEqual(await first.prepare('SELECT facts_json AS factsJson, birth_time_known AS birthTimeKnown, created_at AS createdAt FROM birth_chart_snapshots WHERE id = ?').bind('snapshot').first(),
      { factsJson: '{}', birthTimeKnown: 1, createdAt: now });
  } finally { await Promise.all([first.close(), second.close()]); }
});
