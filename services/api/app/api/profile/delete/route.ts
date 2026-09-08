import { env } from 'cloudflare:workers';
import { chartTicketConfigured, openChartDeletionTicket } from '@/lib/chart-ticket';
import { deleteChartSession } from '@/db/profile-deletion';

export async function POST(request: Request) {
  const body = await request.json().catch(() => null) as { chartTicket?: unknown; profileId?: unknown } | null;
  const session = (request.headers.get('cookie') ?? '').split(';').map(p => p.trim())
    .find(p => p.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
  const chartSecret = (env.JYOTARA_CHART_TICKET_KEY ?? env.NIRAYANA_CHART_TICKET_KEY);
  if (!chartTicketConfigured(chartSecret)) {
    return Response.json({ error: 'Chart protection is not configured.' }, { status: 503 });
  }
  const ticket = await openChartDeletionTicket(chartSecret, body?.chartTicket, session ?? '', body?.profileId);
  if (!ticket) return Response.json({ error: 'A valid saved chart is required to delete this session.', code: 'invalid_deletion_capability' }, { status: 401 });
  await deleteChartSession(env.DB, ticket.sessionId);
  return Response.json({ deleted: true, scope: 'anonymous_chart_session',
    retained: 'Minimal used-attempt and revocation records remain; local device data must be cleared separately.' },
    { headers: { 'Cache-Control': 'no-store' } });
}
