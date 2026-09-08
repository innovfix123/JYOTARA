import { createHash, timingSafeEqual } from 'node:crypto';
import type { PostgresDatabase } from './postgres';

export function testerIdentity(code: string | undefined, hashes: string, expiry: string, path: string, now = Date.now()) {
  if (!code || !/^[a-f0-9]{48}$/.test(code)) return null;
  const digest = createHash('sha256').update(code).digest();
  const known = hashes.split(',').filter(value => /^[a-f0-9]{64}$/.test(value));
  const matches = known.map(value => timingSafeEqual(digest, Buffer.from(value, 'hex')));
  if (!matches.some(Boolean)) return null;
  // Permit capability-authenticated erasure after the test period expires.
  if (path !== '/api/profile/delete' && path !== '/api/pilot/events') {
    const expiresAt = Date.parse(expiry);
    if (!Number.isFinite(expiresAt) || now >= expiresAt) return null;
  }
  return digest.toString('hex');
}

export async function admitTesterRequest(db: PostgresDatabase, tester: string, path: string, cookie: string, now = Date.now()) {
  const session = cookie.split(';').map(p => p.trim()).find(p => p.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
  const needsOwner = !['/api/locations', '/api/tester/check'].includes(path);
  if (needsOwner && (!session || !/^[A-Za-z0-9_-]{1,128}$/.test(session))) return 400;
  const limit = path === '/api/astrology/kundli' ? 2 : path === '/api/guidance' ? 30 : path === '/api/locations' ? 100 : null;
  const day = new Date(now + 19_800_000).toISOString().slice(0, 10);
  return db.transaction(async client => {
    let newChartSession = false;
    if (needsOwner) {
      if (path === '/api/astrology/kundli') {
        const inserted = await client.query('INSERT INTO tester_sessions (session_id,tester_key,created_at) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING', [session, tester, now]);
        newChartSession = inserted.rowCount === 1;
      }
      const owner = await client.query('SELECT tester_key FROM tester_sessions WHERE session_id = $1', [session]);
      if (owner.rows[0]?.tester_key !== tester) return 403;
    }
    if (limit !== null && (path !== '/api/astrology/kundli' || newChartSession)) {
      const id = `${day}:${tester}:${path}`;
      const result = await client.query(`INSERT INTO tester_daily_usage (id,day_key,requests) VALUES ($1,$2,1)
        ON CONFLICT(id) DO UPDATE SET requests = tester_daily_usage.requests + 1
        WHERE tester_daily_usage.requests < $3 RETURNING requests`, [id, day, limit]);
      if (!result.rowCount) {
        if (newChartSession) await client.query('DELETE FROM tester_sessions WHERE session_id = $1 AND tester_key = $2', [session, tester]);
        return 429;
      }
    }
    return 200;
  });
}
