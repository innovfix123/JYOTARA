import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PostgresDatabase } from './postgres';
import { admitTesterRequest } from './tester-access';
import { deleteChartSession, chartSessionDeleted } from '../db/profile-deletion';
import type { D1Database } from '@cloudflare/workers-types';

test('tester isolation and parallel quotas hold across database connections', async () => {
  const url = process.env.DATABASE_URL;
  if (!url || !new URL(url).pathname.startsWith('/jyotara_qa_')) throw new Error('Isolated QA database required');
  const a = new PostgresDatabase(url), b = new PostgresDatabase(url);
  const tester = randomUUID(), other = randomUUID();
  const cookie = `nirayana_pilot_session=${randomUUID()}`;
  const now = Date.now();
  try {
    assert.equal(await admitTesterRequest(a, tester, '/api/astrology/kundli', '', now), 400);
    assert.equal(await admitTesterRequest(a, tester, '/api/astrology/kundli', cookie, now), 200);
    assert.equal(await admitTesterRequest(b, other, '/api/guidance', cookie, now), 403);
    assert.equal(await admitTesterRequest(b, other, '/api/profile/delete', cookie, now), 403);
    assert.equal(await admitTesterRequest(b, other, '/api/profile/discard', cookie, now), 403);
    assert.equal(await admitTesterRequest(a, tester, '/api/profile/discard', cookie, now), 200);
    const pendingCookie = `nirayana_pilot_session=${randomUUID()}`;
    assert.equal(await admitTesterRequest(a, tester, '/api/profile/discard', pendingCookie, now), 200);
    assert.equal(await admitTesterRequest(b, other, '/api/profile/discard', pendingCookie, now), 403);
    const pendingSession = pendingCookie.split('=')[1];
    await deleteChartSession(a as unknown as D1Database, pendingSession, now);
    await deleteChartSession(a as unknown as D1Database, pendingSession, now);
    assert.equal(await chartSessionDeleted(a as unknown as D1Database, pendingSession, now), true);
    const results = await Promise.all(Array.from({length: 45}, (_, i) =>
      admitTesterRequest(i % 2 ? a : b, tester, '/api/guidance', cookie, now)));
    assert.equal(results.filter(r => r === 200).length, 30);
    assert.equal(results.filter(r => r === 429).length, 15);
    assert.equal(await admitTesterRequest(a, tester, '/api/profile/delete', cookie, now), 200);
    assert.equal(await admitTesterRequest(a, tester, '/api/guidance', cookie, now + 86_400_000), 200);
    const charts = await Promise.all(Array.from({length: 15}, (_, i) => admitTesterRequest(
      i % 2 ? a : b, tester, '/api/astrology/kundli', `nirayana_pilot_session=${randomUUID()}`, now)));
    assert.equal(charts.filter(r => r === 200).length, 9, 'new session cookies cannot reset the invitation budget');
    assert.equal(await admitTesterRequest(a, tester, '/api/astrology/kundli', cookie, now), 200, 'an existing session can recover its result after the chart budget is exhausted');
    const deniedCookie = `nirayana_pilot_session=${randomUUID()}`;
    assert.equal(await admitTesterRequest(a, tester, '/api/astrology/kundli', deniedCookie, now), 429);
    assert.equal(await admitTesterRequest(b, tester, '/api/astrology/kundli', deniedCookie, now), 429, 'repeating a denied session must not bypass budget');
  } finally { await Promise.all([a.close(), b.close()]); }
});
