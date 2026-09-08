import { env } from 'cloudflare:workers';

export async function claimAudit(id: string, at: number) {
  const result = await env.DB.prepare(
    'INSERT OR IGNORE INTO prokerala_audit_runs (id, status, created_at, updated_at) VALUES (?, ?, ?, ?)',
  ).bind(id, 'started', at, at).run();
  return result.meta.changes === 1;
}

export async function finishAudit(id: string, status: string, at: number) {
  await env.DB.prepare('UPDATE prokerala_audit_runs SET status = ?, updated_at = ? WHERE id = ?')
    .bind(status, at, id).run();
}
