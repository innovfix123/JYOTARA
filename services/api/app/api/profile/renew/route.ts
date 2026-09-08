import { env } from 'cloudflare:workers';
import { chartTicketConfigured, chartProviderDataFresh, openChartRenewalTicket } from '@/lib/chart-ticket';
import { chartSessionDeleted } from '@/db/profile-deletion';

export async function POST(request: Request) {
  const body = await request.json().catch(() => null) as { chartTicket?: unknown; profileId?: unknown } | null;
  const session = (request.headers.get('cookie') ?? '').split(';').map(p => p.trim())
    .find(p => p.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
  const chartSecret = (env.JYOTARA_CHART_TICKET_KEY ?? env.NIRAYANA_CHART_TICKET_KEY);
  if (!chartTicketConfigured(chartSecret)) return Response.json({ error: 'Chart protection is not configured.' }, { status: 503 });
  const now = Date.now();
  const ticket = await openChartRenewalTicket(chartSecret, body?.chartTicket, session ?? '', body?.profileId, now);
  if (!ticket) return Response.json({ error: 'This saved chart cannot be renewed. Its protected renewal window may have expired.', code: 'renewal_unavailable' }, { status: 401 });
  if (await chartSessionDeleted(env.DB, ticket.sessionId, now)) return Response.json({ error: 'This chart session was deleted.', code: 'profile_deleted' }, { status: 410 });
  if (!chartProviderDataFresh(ticket, now)) return Response.json({
    error: 'Your calculation needs a provider refresh before another reading. No paid refresh has been started. Your saved birth details have not been deleted.',
    code: 'provider_refresh_required', natalRecalculated: false,
  }, {status: 409, headers: {'Cache-Control': 'no-store'}});
  // Fresh access is a no-op. Never relabel old data by minting a newer token.
  return Response.json({ profileId: ticket.profileId, chartTicket: body!.chartTicket,
    chatAuthorizedAt: new Date(ticket.issuedAt).toISOString(), chatExpiresAt: new Date(ticket.expiresAt).toISOString(),
    renewed: true, natalRecalculated: false }, { headers: { 'Cache-Control': 'no-store' } });
}
