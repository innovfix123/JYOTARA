import { discardPending } from './discard-pending';
import { daily, matching } from './discovery';
import { createServer } from 'node:http';
import { database } from './env';
import { testerIdentity, admitTesterRequest } from './tester-access';
import { POST as kundli } from '../app/api/astrology/kundli/route';
import { POST as guidance } from '../app/api/guidance/route';
import { POST as locations } from '../app/api/locations/route';
import { POST as events, DELETE as eraseEvents } from '../app/api/pilot/events/route';
import { POST as renew } from '../app/api/profile/renew/route';
import { POST as deleteProfile } from '../app/api/profile/delete/route';

const routes: Record<string, (request: Request) => Promise<Response>> = {
  'POST /api/astrology/kundli': kundli,
  'POST /api/horoscope/daily': daily,
  'POST /api/kundli/matching': matching,
  'POST /api/guidance': guidance,
  'POST /api/locations': locations,
  'POST /api/pilot/events': events,
  'DELETE /api/pilot/events': eraseEvents,
  'POST /api/profile/renew': renew,
  'POST /api/profile/delete': deleteProfile,
  'POST /api/profile/discard': discardPending,
};
if (!process.env.JYOTARA_TESTER_CODES_SHA256 || !process.env.JYOTARA_TESTER_EXPIRES_AT) {
  throw new Error('Tester access configuration is required');
}
const server = createServer(async (incoming, outgoing) => {
  outgoing.setHeader('X-Content-Type-Options', 'nosniff');
  outgoing.setHeader('Cache-Control', 'no-store');
  try {
    const path = new URL(incoming.url ?? '/', 'http://localhost').pathname;
    if (incoming.method === 'GET' && path === '/healthz') {
      await database.pool.query('SELECT session_id FROM tester_sessions LIMIT 0');
      outgoing.writeHead(200, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ status: 'ok', service: 'jyotara-api' }));
      return;
    }
    const tester = testerIdentity(
      typeof incoming.headers['x-jyotara-tester-code'] === 'string' ? incoming.headers['x-jyotara-tester-code'] : undefined,
      process.env.JYOTARA_TESTER_CODES_SHA256!, process.env.JYOTARA_TESTER_EXPIRES_AT!, path);
    if (!tester) {
      outgoing.writeHead(401, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ error: 'Enter a valid tester access code. It may have expired.', code: 'tester_access_required' }));
      return;
    }
    if (incoming.method === 'POST' && path === '/api/tester/check') {
      outgoing.writeHead(200, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ access: 'granted', expiresAt: process.env.JYOTARA_TESTER_EXPIRES_AT }));
      return;
    }
    const handler = routes[`${incoming.method} ${path}`];
    if (!handler) { outgoing.writeHead(404); outgoing.end(); return; }
    const admission = await admitTesterRequest(database, tester, path, incoming.headers.cookie ?? '');
    if (admission !== 200) {
      outgoing.writeHead(admission, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ error: admission === 429
        ? 'Your tester request limit has been reached. No calculation or answer was requested.'
        : 'This profile does not belong to the current tester session.' }));
      return;
    }
    const chunks: Buffer[] = []; let length = 0;
    for await (const chunk of incoming) {
      length += chunk.length;
      if (length > 256_000) { outgoing.writeHead(413); outgoing.end(); return; }
      chunks.push(chunk);
    }
    const headers = new Headers();
    for (const [key, value] of Object.entries(incoming.headers)) {
      if (Array.isArray(value)) value.forEach(v => headers.append(key, v));
      else if (value !== undefined) headers.set(key, value);
    }
    const request = new Request(`http://localhost${path}`, {
      method: incoming.method, headers,
      body: length ? Buffer.concat(chunks) : undefined,
    });
    const response = await handler(request);
    response.headers.forEach((value, key) => { if (key !== 'set-cookie') outgoing.setHeader(key, value); });
    const cookies = response.headers.getSetCookie();
    if (cookies.length) outgoing.setHeader('Set-Cookie', cookies);
    outgoing.writeHead(response.status);
    outgoing.end(Buffer.from(await response.arrayBuffer()));
  } catch {
    // Never log bodies, chart tickets, questions, URLs or provider payloads.
    console.error('Request failed');
    if (!outgoing.headersSent) outgoing.writeHead(503, { 'Content-Type': 'application/json' });
    outgoing.end(JSON.stringify({ error: 'Jyotara is temporarily unavailable.' }));
  }
});
server.requestTimeout = 30000;
server.headersTimeout = 10000;
server.keepAliveTimeout = 5000;
server.listen(Number(process.env.PORT ?? 3000), '127.0.0.1', () => console.log('Jyotara API listening on loopback'));
for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, () => {
  server.close(() => { void database.close().finally(() => process.exit(0)); });
  setTimeout(() => process.exit(1), 30000).unref();
});
