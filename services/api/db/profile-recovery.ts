import type { D1Database } from '@cloudflare/workers-types';
import { sealReply, openReply } from './guidance-requests';

export async function completeProfile(db: D1Database, secret: string, input: {
  id: string; session: string; reply: Record<string, unknown>; expiresAt: number; now: number;
}) {
  const encrypted = await sealReply(secret, `profile:${input.id}`, input.reply, 2_000_000);
  const result = await db.prepare(`UPDATE profile_generations
    SET status = 'success', credits = 320, updated_at = ?, response_ciphertext = ?, response_expires_at = ?
    WHERE id = ? AND session_id = ? AND status = 'started'`)
    .bind(input.now, encrypted, input.expiresAt, input.id, input.session).run();
  if (result.meta.changes !== 1) throw new Error('Chart recovery record could not be completed');
}

export async function recoverProfile(db: D1Database, secret: string, input: {
  session: string; day: string; hash: string; now: number;
}): Promise<Record<string, unknown> | null> {
  const row = await db.prepare(`SELECT id, status, request_hash, response_ciphertext, response_expires_at
    FROM profile_generations WHERE session_id = ? AND day_key = ?`)
    .bind(input.session, input.day).first<{
      id: string; status: string; request_hash: string | null; response_ciphertext: string | null; response_expires_at: number | null;
    }>();
  if (!row || row.status !== 'success' || row.request_hash !== input.hash ||
      !row.response_ciphertext || !row.response_expires_at || row.response_expires_at <= input.now) return null;
  try {
    const reply = await openReply(secret, `profile:${row.id}`, row.response_ciphertext, 2_000_000);
    if (!reply || typeof reply !== 'object' || Array.isArray(reply)) return null;
    return reply as Record<string, unknown>;
  } catch { return null; }
}

export async function cleanupProfileRecovery(db: D1Database, now: number) {
  await db.prepare(`UPDATE profile_generations SET response_ciphertext = NULL
    WHERE response_expires_at <= ? AND response_ciphertext IS NOT NULL`).bind(now).run();
}
