import { env } from 'cloudflare:workers';
import { eraseGuidanceContent } from '@/db/guidance-requests';

const allowedEvents = new Set([
  'profile_completed',
  'category_opened',
  'question_asked',
  'answer_feedback',
]);
const allowedCategories = new Set([
  'Daily', 'Education', 'Career', 'Love', 'Breakup', 'Relationships',
  'Marriage', 'Family', 'Business', 'Property', 'Spiritual', 'Panchang',
]);
const allowedAgeBands = new Set(['13-17', '18-20', '21-27', '28-35', '36-45', '46-59', '60+']);
const sessionCookie = 'nirayana_pilot_session';

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as null | {
    eventType?: string;
    category?: string;
    language?: string;
    tradition?: string;
    helpful?: boolean;
    ageBand?: string;
    inputMode?: string;
    acquisitionSource?: string;
  };

  if (!body?.eventType || !allowedEvents.has(body.eventType)) {
    return Response.json({ error: 'Invalid event' }, { status: 400 });
  }

  const cookieHeader = request.headers.get('cookie') ?? '';
  const existingSession = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${sessionCookie}=`))
    ?.slice(sessionCookie.length + 1);
  const sessionId = existingSession || crypto.randomUUID();

  await env.DB.batch([
    env.DB.prepare(`
      CREATE TABLE IF NOT EXISTS pilot_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        category TEXT,
        language TEXT,
        tradition TEXT,
        helpful INTEGER,
        age_band TEXT,
        input_mode TEXT,
        acquisition_source TEXT,
        created_at INTEGER NOT NULL
      )
    `),
    env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_pilot_events_session
      ON pilot_events(session_id)
    `),
    env.DB.prepare(`
      CREATE INDEX IF NOT EXISTS idx_pilot_events_type_created
      ON pilot_events(event_type, created_at)
    `),
  ]);

  // Product analytics are retained for no longer than the approved 12-month window.
  await env.DB.prepare('DELETE FROM pilot_events WHERE created_at < ?')
    .bind(Date.now() - 365 * 24 * 60 * 60 * 1000)
    .run();

  await env.DB.prepare(`
    INSERT INTO pilot_events
      (id, session_id, event_type, category, language, tradition, helpful, age_band, input_mode, acquisition_source, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `)
    .bind(
      crypto.randomUUID(),
      sessionId,
      body.eventType,
      body.category && allowedCategories.has(body.category) ? body.category : null,
      body.language?.slice(0, 32) ?? null,
      body.tradition?.slice(0, 32) ?? null,
      typeof body.helpful === 'boolean' ? Number(body.helpful) : null,
      body.ageBand && allowedAgeBands.has(body.ageBand) ? body.ageBand : null,
      body.inputMode?.slice(0, 16) ?? null,
      body.acquisitionSource?.slice(0, 64) ?? null,
      Date.now(),
    )
    .run();

  return Response.json(
    { ok: true },
    {
      headers: existingSession
        ? undefined
        : { 'Set-Cookie': `${sessionCookie}=${sessionId}; Path=/; Max-Age=2592000; SameSite=Lax; Secure; HttpOnly` },
    },
  );
}

export async function DELETE(request: Request) {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const sessionId = cookieHeader
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${sessionCookie}=`))
    ?.slice(sessionCookie.length + 1);

  if (sessionId) {
    await env.DB.batch([
      eraseGuidanceContent(env.DB, sessionId),
      env.DB.prepare('DELETE FROM pilot_events WHERE session_id = ?').bind(sessionId),
    ]);
  }

  return new Response(null, {
    status: 204,
    headers: {
      'Set-Cookie': `${sessionCookie}=; Path=/; Max-Age=0; SameSite=Lax; Secure; HttpOnly`,
    },
  });
}
