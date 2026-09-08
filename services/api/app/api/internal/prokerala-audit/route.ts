import { env } from 'cloudflare:workers';
import { claimAudit, finishAudit } from '@/db/prokerala-audit';
import { runAudit } from '@/lib/prokerala-audit';

export async function POST(request: Request) {
  return runAudit(request, {
    now: Date.now,
    production: env.PROKERALA_ENVIRONMENT === 'production',
    clientId: env.PROKERALA_CLIENT_ID,
    clientSecret: env.PROKERALA_CLIENT_SECRET,
    fetch,
    claim: claimAudit,
    finish: finishAudit,
  });
}
