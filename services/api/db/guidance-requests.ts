import type { D1Database } from '@cloudflare/workers-types';

const encoder = new TextEncoder();
const hex = (bytes: ArrayBuffer) => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const bytes = (value: string) => Uint8Array.from(value.match(/../g)!, b => parseInt(b, 16));

async function encryptionKey(secret: string) {
  if (!/^[a-f\d]{64}$/i.test(secret)) throw new Error('Request protection unavailable');
  return crypto.subtle.importKey('raw', bytes(secret), 'AES-GCM', false, ['encrypt', 'decrypt']);
}

// Keyed digests avoid retaining raw questions or dictionary-checkable hashes.
export async function requestIdentity(secret: string, session: string, requestId: string, payload: unknown) {
  const key = await crypto.subtle.importKey('raw', bytes(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sign = async (value: unknown) => hex(await crypto.subtle.sign('HMAC', key, encoder.encode(JSON.stringify(value))));
  return { id: await sign(['guidance-id-v1', session, requestId]), hash: await sign(['guidance-body-v1', payload]) };
}

export async function sealReply(secret: string, id: string, reply: unknown, maxBytes = 100_000) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const text = encoder.encode(JSON.stringify(reply));
  if (!Number.isInteger(maxBytes) || maxBytes < 1 || maxBytes > 2_000_000 || text.length > maxBytes) throw new Error('Reply too large');
  const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(`nirayana:guidance-reply:v1:${id}`) }, await encryptionKey(secret), text);
  return `${hex(iv.buffer)}.${hex(ciphertext)}`;
}

export async function openReply(secret: string, id: string, value: string, maxBytes = 100_000): Promise<unknown> {
  if (!Number.isInteger(maxBytes) || maxBytes < 1 || maxBytes > 2_000_000 || value.length > 25 + 2 * (maxBytes + 16) || !/^[a-f\d]{24}\.[a-f\d]{32,}$/.test(value)) throw new Error('Invalid receipt');
  const [iv, ciphertext] = value.split('.');
  if (ciphertext.length % 2) throw new Error('Invalid receipt');
  const text = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: bytes(iv), additionalData: encoder.encode(`nirayana:guidance-reply:v1:${id}`) }, await encryptionKey(secret), bytes(ciphertext));
  return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(text));
}

export type Receipt = { request_hash: string | null; answer_mode: string; response_ciphertext: string | null; response_expires_at: number | null };

/** Erase recoverable/research content without recycling a possibly billed
 * attempt. A terminal marker also prevents a pending completion restoring it.
 * This is not profile deletion or authenticated account revocation. */
export function eraseGuidanceContent(db: D1Database, session: string) {
  return db.prepare(`UPDATE guide_requests SET
    category = 'deleted', language = 'deleted', support_level = 'deleted', answer_mode = 'deleted',
    question_text = NULL, intent = NULL, research_consent_version = NULL, age_band = NULL,
    request_hash = NULL, response_ciphertext = NULL, response_expires_at = NULL
    WHERE session_id = ?`).bind(session);
}

export async function completeQuestion(db: D1Database, input: {
  id: string; session: string; support: string; mode: string; question: string | null;
  intent: string; consent: string | null; ageBand: string | null;
  ciphertext: string; expiresAt: number;
}) {
  const result = await db.prepare(`UPDATE guide_requests SET
    support_level = ?, answer_mode = ?, question_text = ?, intent = ?,
    research_consent_version = ?, age_band = ?, response_ciphertext = ?, response_expires_at = ?
    WHERE id = ? AND session_id = ? AND answer_mode = 'pending'`).bind(
    input.support, input.mode, input.question, input.intent, input.consent,
    input.ageBand, input.ciphertext, input.expiresAt, input.id, input.session,
  ).run();
  return result.meta.changes === 1;
}

export async function reserveQuestion(db: D1Database, input: {
  id: string; hash: string; session: string; category: string; language: string; now: number; limit: number;
}): Promise<{ kind: 'claimed' } | { kind: 'existing'; receipt: Receipt } | { kind: 'limit' }> {
  // Predicate and insertion are one SQLite write. Pending/uncertain attempts
  // occupy their slots before model work; they are never automatically rerun.
  const result = await db.prepare(`INSERT OR IGNORE INTO guide_requests
    (id, session_id, category, language, support_level, answer_mode, request_hash, created_at)
    SELECT ?, ?, ?, ?, 'pending', 'pending', ?, ?
    WHERE (SELECT COUNT(*) FROM guide_requests WHERE session_id = ?) < ?
      AND NOT EXISTS (SELECT 1 FROM deleted_chart_sessions WHERE session_id = ? AND expires_at > ?)`)
    .bind(input.id, input.session, input.category, input.language, input.hash, input.now, input.session, input.limit, input.session, input.now).run();
  if (result.meta.changes === 1) return { kind: 'claimed' };
  const receipt = await db.prepare(`SELECT request_hash, answer_mode, response_ciphertext, response_expires_at
    FROM guide_requests WHERE id = ? AND session_id = ?`).bind(input.id, input.session).first<Receipt>();
  return receipt ? { kind: 'existing', receipt } : { kind: 'limit' };
}
