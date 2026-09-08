import { env } from 'cloudflare:workers';
import { chartSessionDeleted } from '@/db/profile-deletion';
import { chartTicketConfigured, issueChartTicket } from '@/lib/chart-ticket';
import { normalizeProviderChart, normalizeProviderNavamsa } from '@/lib/provider-chart';
import { currentContext } from '@/db/current-context';
import { prokeralaJson } from '@/lib/prokerala-client';
import { validBirthDatetime, validChartSession, calculationBirthDatetime, isAdultBirthDate } from '@/lib/birth-request';
import { reserveProfile } from '@/db/profile-reservation';
import { requestIdentity } from '@/db/guidance-requests';
import { cleanupProfileRecovery, completeProfile, recoverProfile } from '@/db/profile-recovery';

const sessionCookie = 'nirayana_pilot_session';
const dailyProfileLimit = 60;

function getSession(request: Request) {
  const cookie = request.headers.get('cookie') ?? '';
  const existing = cookie
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${sessionCookie}=`))
    ?.slice(sessionCookie.length + 1);
  // Do not silently replace a malformed supplied session: that would reset
  // its quota and allow paid work that cannot be bound to a chart ticket.
  if (existing !== undefined && !validChartSession(existing)) return null;
  return { id: existing ?? crypto.randomUUID(), existing: existing !== undefined };
}

function sessionHeaders(session: { id: string; existing: boolean }) {
  return session.existing
    ? undefined
    : { 'Set-Cookie': `${sessionCookie}=${session.id}; Path=/; Max-Age=2592000; SameSite=Lax; Secure; HttpOnly` };
}

async function cleanupProfileGenerationLogs() {
  // Schema and the session/day uniqueness constraint are migration-owned.
  // Profile-generation rows are operational metering logs; retain only 30 days.
  await env.DB.prepare('DELETE FROM profile_generations WHERE created_at < ?')
    .bind(Date.now() - 30 * 24 * 60 * 60 * 1000)
    .run();
}

export async function POST(request: Request) {
  const session = getSession(request);
  if (!session) return Response.json({ error: 'Invalid chart session.' }, { status: 400 });
  const body = (await request.json().catch(() => null)) as null | {
    datetime?: string;
    latitude?: number;
    longitude?: number;
    language?: string;
    currentDatetime?: string;
    birthTimeKnown?: boolean;
  };
  if (!body || typeof body.latitude !== 'number' || typeof body.longitude !== 'number' || !Number.isFinite(body.latitude) || !Number.isFinite(body.longitude) || Math.abs(body.latitude) > 90 || Math.abs(body.longitude) > 180 || !validBirthDatetime(body.datetime)) {
    return Response.json({ error: 'Valid coordinates and datetime are required' }, { status: 400, headers: sessionHeaders(session) });
  }

  if (!isAdultBirthDate(body.datetime)) {
    return Response.json({ error: 'This test app supports personal birth profiles for adults aged 18 or older.' }, { status: 400 });
  }
  const chartSecret = (env.JYOTARA_CHART_TICKET_KEY ?? env.NIRAYANA_CHART_TICKET_KEY);
  if (!chartTicketConfigured(chartSecret)) {
    return Response.json({ error: 'Chart protection is not configured.' }, { status: 503 });
  }
  const recoverySecret = chartSecret;
  if (await chartSessionDeleted(env.DB, session.id)) return Response.json({ error: 'This chart session was deleted.', code: 'profile_deleted' }, { status: 410 });
  if (typeof body.birthTimeKnown !== 'boolean') {
    return Response.json({ error: 'Birth-time accuracy is required.' }, { status: 400 });
  }

  const dayKey = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
  const birthDatetime = calculationBirthDatetime(body.datetime, body.birthTimeKnown);
  const generationId = crypto.randomUUID();
  try {
    const hash = (await requestIdentity(chartSecret, session.id, 'profile-v1',
      [birthDatetime, body.latitude, body.longitude, body.birthTimeKnown, body.language === 'en' ? 'en' : 'ta'])).hash;
    await cleanupProfileGenerationLogs();
    await cleanupProfileRecovery(env.DB, Date.now());
    const reservation = await reserveProfile(env.DB, {
      id: generationId, session: session.id, day: dayKey, now: Date.now(), limit: dailyProfileLimit, hash,
    });
    if (reservation === 'existing') {
      const recovered = await recoverProfile(env.DB, chartSecret, {
        session: session.id, day: dayKey, hash, now: Date.now(),
      });
      if (recovered) return Response.json({ ...recovered, profileRecovered: true }, {
        headers: { ...sessionHeaders(session), 'Cache-Control': 'no-store' },
      });
      return Response.json(
        { code: 'profile_attempt_exists', error: 'A chart request already exists for this session today. It will not be repeated automatically, even if its result was not received.' },
        { status: 429, headers: sessionHeaders(session) },
      );
    }
    if (reservation === 'limit') {
      return Response.json(
        { error: 'இன்றைய சோதனை வரம்பு முடிந்தது. நாளை மீண்டும் முயற்சிக்கவும்.' },
        { status: 429, headers: sessionHeaders(session) },
      );
    }

    const sandbox = env.PROKERALA_ENVIRONMENT !== 'production';
    const datetime = sandbox ? '2026-01-01T12:00:00+05:30' : birthDatetime;
    // Current context is server-owned, never a caller-selected historical date.
    const currentDatetime = sandbox ? '2026-09-01T12:00:00+05:30' : new Date().toISOString();
    const language = body.language === 'en' ? 'en' : 'ta';
    const fetchJson = (path: string, requestDatetime = datetime) => prokeralaJson(env, path, {
      datetime: requestDatetime, latitude: body.latitude!, longitude: body.longitude!, language,
    });
    // Natal modules and shared current-context modules use the same bounded,
    // non-retrying transport. Cache hits may reduce current-context requests.
    const kundli = await fetchJson('/astrology/kundli');
    const contextRequest = sandbox
      ? Promise.all([fetchJson('/astrology/planet-position', currentDatetime), fetchJson('/astrology/panchang', currentDatetime)])
          .then(([transitPosition, panchang]) => ({ transitPosition, panchang, contextCalculatedAt: currentDatetime }))
      : currentContext(env.DB, { latitude: body.latitude, longitude: body.longitude },
          (module, datetime, location) => prokeralaJson(env, module === 'transit' ? '/astrology/planet-position' : '/astrology/panchang', { ...location, datetime, language: 'en' }));
    const [planets, dasha, context, navamsa] = await Promise.allSettled([
      fetchJson('/astrology/planet-position'),
      fetchJson('/astrology/dasha-periods'),
      contextRequest,
      // English structured data costs 50 credits. It is fetched once with
      // natal data and retained in the same protected recovery snapshot.
      body.birthTimeKnown ? prokeralaJson(env, '/astrology/divisional-planet-position', {
        datetime, latitude: body.latitude!, longitude: body.longitude!, language: 'en',
      }) : Promise.resolve(null),
    ]);
    const current = context.status === 'fulfilled' ? context.value : null;
    const d9 = navamsa.status === 'fulfilled' && normalizeProviderNavamsa(navamsa.value, body.birthTimeKnown) ? navamsa.value : null;

    const payload = {
      sandbox,
      chartCalculatedAt: new Date().toISOString(),
      profileRecovered: false,
      contextCalculatedAt: current?.contextCalculatedAt ?? currentDatetime,
      result: kundli,
      planetPosition: planets.status === 'fulfilled' ? planets.value : null,
      dashaPeriods: dasha.status === 'fulfilled' ? dasha.value : null,
      navamsa: d9,
      transitPosition: current?.transitPosition ?? null,
      panchang: current?.panchang ?? null,
      moduleStatus: {
        kundli: 'connected',
        planetPosition: planets.status === 'fulfilled' ? 'connected' : 'unavailable',
        dashaPeriods: dasha.status === 'fulfilled' ? 'connected' : 'unavailable',
        navamsa: !body.birthTimeKnown ? 'not-requested-unknown-time' : d9 ? 'connected' : 'unavailable',
        birthChart: planets.status === 'fulfilled' ? 'locally-rendered' : 'unavailable',
        currentTransit: current?.transitPosition ? 'connected' : 'unavailable',
        panchang: current?.panchang ? 'connected' : 'unavailable',
      },
    };
    const complete = (reply: Record<string, unknown>) => completeProfile(env.DB, recoverySecret, {
      id: generationId, session: session.id, reply, now: Date.now(),
      // Recovery is intentionally shorter than the 24-hour chart ticket.
      expiresAt: Date.now() + 23 * 60 * 60 * 1000,
    });
    if (sandbox) {
      await complete(payload);
      return Response.json(payload, { headers: sessionHeaders(session) });
    }
    const profileId = crypto.randomUUID();
    const chart = normalizeProviderChart(payload, body.birthTimeKnown, new Date(currentDatetime));
    const chartTicket = await issueChartTicket(chartSecret, {
      sessionId: session.id, profileId, birthTimeKnown: body.birthTimeKnown, chart,
      contextLocation: { latitude: body.latitude, longitude: body.longitude },
    });
    const reply = { ...payload, profileId, chartTicket };
    await complete(reply);
    return Response.json(reply, {
      headers: { ...sessionHeaders(session), 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    await env.DB.prepare(`
      UPDATE profile_generations SET status = 'failed', updated_at = ?
      WHERE id = ? AND session_id = ? AND status = 'started'
    `).bind(Date.now(), generationId, session.id).run().catch(() => undefined);
    return Response.json(
      { error: error instanceof Error ? error.message : 'Astrology service unavailable' },
      { status: 503, headers: sessionHeaders(session) },
    );
  }
}
