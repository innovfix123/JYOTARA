// Temporary, single-use capability test. No changes to the public chart/chat flow.
// Disabled in the public source. Historical capability/profile fingerprints are
// private QA data and remain in the original local source only.
export const auditConfig = {
  id: 'disabled',
  tokenHash: '',
  profileHash: '',
  expiresAt: 0,
};

export type AuditConfig = typeof auditConfig;
export type AuditDependencies = {
  now: () => number;
  production: boolean;
  clientId?: string;
  clientSecret?: string;
  fetch: typeof fetch;
  claim: (id: string, at: number) => Promise<boolean>;
  finish: (id: string, status: string, at: number) => Promise<void>;
};

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
}

function reply(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex, nofollow' } });
}

export async function runAudit(request: Request, deps: AuditDependencies, config = auditConfig) {
  if (request.method !== 'POST') return reply({ error: 'Not found' }, 404);
  if (deps.now() >= config.expiresAt) return reply({ error: 'Test expired' }, 410);
  const authorization = request.headers.get('authorization') ?? '';
  if (!/^Bearer [a-f0-9]{64}$/.test(authorization) || await sha256(authorization.slice(7)) !== config.tokenHash) {
    return reply({ error: 'Not found' }, 404);
  }
  if (!deps.production || !deps.clientId || !deps.clientSecret) return reply({ error: 'Production service unavailable' }, 503);
  const input = await request.json().catch(() => null) as null | { datetime?: unknown; latitude?: number; longitude?: number };
  if (!input || typeof input.datetime !== 'string' || !Number.isFinite(input.latitude) || !Number.isFinite(input.longitude)) {
    return reply({ error: 'Invalid test profile' }, 400);
  }
  // Restrict this credential to the specifically approved profile, language and two modules.
  if (await sha256(JSON.stringify([input.datetime, input.latitude, input.longitude])) !== config.profileHash) {
    return reply({ error: 'Test profile not authorised' }, 400);
  }
  if (!await deps.claim(config.id, deps.now())) return reply({ error: 'Test already claimed; no automatic retries' }, 409);
  const results: Record<string, unknown> = {};
  let complete = false;
  try {
    const tokenResponse = await deps.fetch('https://api.prokerala.com/token', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'client_credentials', client_id: deps.clientId, client_secret: deps.clientSecret }),
    });
    if (!tokenResponse.ok) return reply({ error: 'Provider authentication failed; no calculation requested' }, 502);
    const token = await tokenResponse.json() as { access_token?: string };
    if (!token.access_token) return reply({ error: 'Provider authentication response invalid' }, 502);
    for (const [name, path, credits] of [
      ['advancedKundli', '/astrology/kundli/advanced', 600],
      ['yoga', '/astrology/yoga', 400],
    ] as const) {
      const url = new URL(`https://api.prokerala.com/v2${path}`);
      url.searchParams.set('ayanamsa', '1');
      url.searchParams.set('coordinates', `${input.latitude},${input.longitude}`);
      url.searchParams.set('datetime', input.datetime);
      url.searchParams.set('la', 'ta');
      try {
        const response = await deps.fetch(url, {
          headers: { Authorization: `Bearer ${token.access_token}` },
          redirect: 'error', signal: AbortSignal.timeout(25000),
        });
        results[name] = {
          httpStatus: response.status, expectedCredits: credits,
          ...(response.ok ? { response: await response.json() } : { error: 'Provider rejected module request' }),
        };
      } catch {
        results[name] = { error: 'Module request failed or timed out; charge may have occurred', expectedCredits: credits };
      }
    }
    complete = true;
    return reply({ mode: 'production', language: 'ta', convention: 'Lahiri (ayanamsa=1)', expectedCredits: 1000, actualCredits: 'Verify account ledger; estimates are not billed totals', results });
  } catch {
    return reply({ error: 'Test interrupted; no automatic retries' }, 502);
  } finally {
    await deps.finish(config.id, complete ? 'completed' : 'interrupted', deps.now()).catch(() => undefined);
  }
}
