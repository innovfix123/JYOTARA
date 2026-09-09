import type { D1Database } from '@cloudflare/workers-types';
import { eraseGuidanceContent } from './guidance-requests';

export async function chartSessionDeleted(db: D1Database, session: string, now = Date.now()) {
  const row = await db.prepare(`SELECT 1 AS revoked FROM deleted_chart_sessions
    WHERE session_id = ? AND expires_at > ?`).bind(session, now).first<{ revoked: number }>();
  return row?.revoked === 1;
}

/** Invoke only after authenticating a chart deletion capability or runtime
 * invitation/session ownership for pending-request erasure. Atomic erasure
 * closes reservations before removing content; metering tombstones remain. */
export async function deleteChartSession(db: D1Database, session: string, now = Date.now()) {
  await db.batch([
    db.prepare(`INSERT INTO deleted_chart_sessions (session_id, expires_at) VALUES (?, ?)
      ON CONFLICT(session_id) DO UPDATE SET expires_at = MAX(expires_at, excluded.expires_at)`)
      .bind(session, now + 30 * 24 * 60 * 60 * 1000),
    eraseGuidanceContent(db, session),
    db.prepare(`UPDATE profile_generations SET status = 'deleted', request_hash = NULL,
      response_ciphertext = NULL, response_expires_at = NULL, updated_at = ?
      WHERE session_id = ?`).bind(now, session),
    db.prepare('DELETE FROM pilot_events WHERE session_id = ?').bind(session),
  ]);
}
