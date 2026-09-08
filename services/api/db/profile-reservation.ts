import type { D1Database } from '@cloudflare/workers-types';

/** One atomic write enforces the daily budget and existing session/day unique
 * index. Failed or stale attempts still count: provider delivery is uncertain,
 * so elapsed time alone must never authorize another paid request. */
export async function reserveProfile(db: D1Database, input: {
  id: string; session: string; day: string; now: number; limit: number; hash?: string;
}): Promise<'claimed' | 'existing' | 'limit'> {
  const result = await db.prepare(`INSERT OR IGNORE INTO profile_generations
    (id, session_id, day_key, status, credits, created_at, updated_at, request_hash)
    SELECT ?, ?, ?, 'started', 0, ?, ?, ?
    WHERE (SELECT COUNT(*) FROM profile_generations WHERE day_key = ?) < ?
      AND NOT EXISTS (SELECT 1 FROM deleted_chart_sessions WHERE session_id = ? AND expires_at > ?)`)
    .bind(input.id, input.session, input.day, input.now, input.now, input.hash ?? null, input.day, input.limit, input.session, input.now).run();
  if (result.meta.changes === 1) return 'claimed';
  const existing = await db.prepare('SELECT id FROM profile_generations WHERE session_id = ? AND day_key = ?')
    .bind(input.session, input.day).first();
  return existing ? 'existing' : 'limit';
}
