import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const source = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const moduleUrl = path => url(compile(source(path)));
const evidence = moduleUrl('../lib/astrology-evidence.ts');
const tickets = url(compile(source('../lib/chart-ticket.ts')).replace('./astrology-evidence', evidence));
const receipts = moduleUrl('../db/guidance-requests.ts');
const deletion = url(compile(source('../db/profile-deletion.ts')).replace('./guidance-requests', receipts));
const rules = moduleUrl('../lib/career-rules.ts');
const contract = url(compile(source('../lib/career-answer-contract.ts')).replace('./career-rules', rules));
const career = url(compile(source('../lib/career-response.ts')).replaceAll('./astrology-evidence', evidence).replace('./career-rules', rules).replace('./career-answer-contract', contract));
const { issueChartTicket, openChartTicket } = await import(tickets);
const { sealReply, openReply } = await import(receipts);
const route = url(compile(source('../app/api/guidance/route.ts'))
  .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
  .replace('@/lib/chart-ticket', tickets)
  .replace('@/db/guidance-requests', receipts)
  .replace('@/db/profile-deletion', deletion)
  .replace('@/lib/career-response', career)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/marriage-report', moduleUrl('../lib/marriage-report.ts'))
  .replaceAll('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(source('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence)))
  .replace('@/lib/astrology-evidence', evidence)
  .replace('@/lib/guidance-language', moduleUrl('../lib/guidance-language.ts')));

test('actual route reserves before model work, replays encrypted result, enforces quota and isolates identities', async () => {
  const db = new DatabaseSync(':memory:');
  for (const name of ['0000_perpetual_giant_man', '0001_chilly_purple_man', '0002_broad_spacker_dave', '0003_reflective_betty_ross', '0004_powerful_juggernaut', '0007_cold_inhumans', '0009_salty_skrulls']) {
    db.exec(source(`../drizzle/${name}.sql`));
  }
  db.exec(source('../drizzle/0010_green_johnny_blaze.sql'));
  db.exec(source('../drizzle/0011_report_evidence.sql'));
  const secret = 'a3'.repeat(32);
  const originalFetch = globalThis.fetch;
  let calls = 0;
  let release;
  let started;
  const modelStarted = new Promise(resolve => { started = resolve; });
  const modelWait = new Promise(resolve => { release = resolve; });
  globalThis.__receiptTestEnv = { NIRAYANA_CHART_TICKET_KEY: secret, OPENROUTER_API_KEY: 'TEST-ONLY', DB: {
    async batch(statements) {
      db.exec('BEGIN');
      try {
        const results = [];
        for (const statement of statements) results.push(await statement.run());
        db.exec('COMMIT');
        return results;
      } catch (error) { db.exec('ROLLBACK'); throw error; }
    },
    prepare(sql) {
      let args = [];
      return {
        bind(...values) { args = values; return this; },
        async run() { const result = db.prepare(sql).run(...args); return { meta: { changes: Number(result.changes) } }; },
        async first() { return db.prepare(sql).get(...args) ?? null; },
      };
    },
  } };
  globalThis.fetch = async () => {
    calls++;
    started();
    if (calls === 1) await modelWait;
    return Response.json({ output_text: 'Mercury Mahadasha and Venus Antardasha are the supplied periods.' });
  };
  try {
    const { POST, DELETE } = await import(route);
    const chart = { rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', lagna: 'Mithuna', planets: [], yogas: [],
      currentDasha: { name: 'Mercury', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' },
      currentAntardasha: { name: 'Venus', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' } };
    const ticket = (sessionId, profileId) => issueChartTicket(secret, { sessionId, profileId, chart, birthTimeKnown: true });
    const base = { requestId: 'request-0000000001', category: 'Love', question: 'What should I focus on?', language: 'en', responseStyle: 'english', researchConsent: false, profileId: 'one', chartTicket: await ticket('owner', 'one') };
    const post = (body = base, session = 'owner') => POST(new Request('https://example.test/api/guidance', { method: 'POST', headers: { Cookie: `nirayana_pilot_session=${session}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) }));
    const pending = post();
    await modelStarted;
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM guide_requests').get().n, 1);
    assert.equal((await post()).status, 409);
    assert.equal(calls, 1, 'overlap must not duplicate provider call');
    release();
    const first = await pending;
    assert.equal(first.status, 200);
    const reply = await first.json();
    const replay = await post();
    assert.equal(replay.status, 200);
    assert.deepEqual(await replay.json(), { ...reply, replayed: true, providerUsage:{calls:[],newProviderCalls:0,receiptReused:true} });
    assert.equal(reply.replayed, false);
    assert.ok(Number.isFinite(Date.parse(reply.answeredAt)));
    assert.equal(calls, 1);
    const stored = db.prepare('SELECT * FROM guide_requests').get();
    assert.equal(stored.question_text, null);
    assert.equal(stored.research_consent_version, null);
    assert.ok(!stored.response_ciphertext.includes('Mercury'));
    assert.equal((await post({ ...base, question: 'Different question?' })).status, 409);
    assert.equal((await post({ ...base, profileId: 'two', chartTicket: await ticket('owner', 'two') })).status, 409);
    assert.equal((await post(base, 'other')).status, 401);
    assert.equal((await post({ ...base, requestId: {} })).status, 400);
    const other = await post({ ...base, chartTicket: await ticket('other', 'one') }, 'other');
    assert.equal(other.status, 200, 'same ID does not expose another session reply');
    const burst = await Promise.all(['2', '3', '4', '5'].map(n => post({ ...base, requestId: `request-000000000${n}` })));
    assert.deepEqual(burst.map(r => r.status).sort(), [200, 200, 429, 429]);
    assert.equal(db.prepare("SELECT COUNT(*) AS n FROM guide_requests WHERE session_id = 'owner'").get().n, 3);
    const after = calls;
    assert.equal((await post()).status, 200, 'replay works even after quota reached');
    db.prepare('UPDATE guide_requests SET response_expires_at = 0 WHERE id = ?').run(stored.id);
    assert.equal((await post()).status, 409, 'expired receipt is not a new billable attempt');
    assert.equal(calls, after);
    assert.equal(db.prepare('SELECT response_ciphertext FROM guide_requests WHERE id = ?').get(stored.id).response_ciphertext, null);

    const remove = session => DELETE(new Request('https://example.test/api/guidance', {
      method: 'DELETE', headers: { Cookie: `nirayana_pilot_session=${session}` },
    }));
    assert.equal((await remove('owner')).status, 204);
    assert.equal((await post()).status, 410, 'deleted receipt never replays or resubmits');
    assert.equal((await post({ ...base, requestId: 'request-new-after-delete' })).status, 429, 'erasure must not reset consumed slots');
    assert.equal(calls, after, 'erasure and deleted retries make no new provider calls');
    const erased = db.prepare("SELECT * FROM guide_requests WHERE session_id = 'owner'").all();
    assert.equal(erased.length, 3);
    for (const row of erased) {
      assert.equal(row.answer_mode, 'deleted');
      for (const field of ['question_text', 'intent', 'research_consent_version', 'age_band', 'request_hash', 'response_ciphertext', 'response_expires_at']) assert.equal(row[field], null, field);
    }
    assert.equal((await post({ ...base, chartTicket: await ticket('other', 'one') }, 'other')).status, 200, 'another session survives erasure');

    let pendingStarted;
    let finishPending;
    const began = new Promise(resolve => { pendingStarted = resolve; });
    const pause = new Promise(resolve => { finishPending = resolve; });
    globalThis.fetch = async () => {
      calls++;
      pendingStarted();
      await pause;
      return Response.json({ output_text: 'Mercury Mahadasha and Venus Antardasha are the supplied periods.' });
    };
    const lateBase = { ...base, researchConsent: true, chartTicket: await ticket('delete-pending', 'one') };
    const late = post(lateBase, 'delete-pending');
    await began;
    try {
      assert.equal((await remove('delete-pending')).status, 204);
    } finally { finishPending(); }
    const lateResult = await late;
    assert.equal(lateResult.status, 410);
    const lateReply = await lateResult.json();
    assert.equal(lateReply.code, 'request_inactive');
    assert.equal(lateReply.answer, undefined);
    const tombstone = db.prepare("SELECT * FROM guide_requests WHERE session_id = 'delete-pending'").get();
    assert.equal(tombstone.answer_mode, 'deleted');
    assert.equal(tombstone.question_text, null, 'late consented question must not be restored');
    assert.equal(tombstone.response_ciphertext, null, 'late answer must not be restored');
    assert.equal((await post(lateBase, 'delete-pending')).status, 410);

    const eventsRoute = url(compile(source('../app/api/pilot/events/route.ts'))
      .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
      .replace('@/db/guidance-requests', receipts));
    const { DELETE: deletePilotData } = await import(eventsRoute);
    db.prepare('INSERT INTO pilot_events (id,session_id,event_type,created_at) VALUES (?,?,?,?)').run('event-other', 'other', 'question_asked', Date.now());
    const beforeErasure = calls;
    const erasedResponse = await deletePilotData(new Request('https://example.test/api/pilot/events', {
      method: 'DELETE', headers: { Cookie: 'nirayana_pilot_session=other' },
    }));
    assert.equal(erasedResponse.status, 204);
    assert.equal(db.prepare("SELECT COUNT(*) AS n FROM pilot_events WHERE session_id = 'other'").get().n, 0);
    assert.equal(db.prepare("SELECT answer_mode FROM guide_requests WHERE session_id = 'other'").get().answer_mode, 'deleted');
    assert.equal((await post({ ...base, chartTicket: await ticket('other', 'one') }, 'other')).status, 410);
    assert.equal(calls, beforeErasure);

    const deleteRoute = url(compile(source('../app/api/profile/delete/route.ts'))
      .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
      .replace('@/lib/chart-ticket', tickets).replace('@/db/profile-deletion', deletion));
    const { POST: deleteProfile } = await import(deleteRoute);
    const expired = await issueChartTicket(secret, { sessionId: 'owner', profileId: 'one', chart, birthTimeKnown: true }, Date.now() - 2 * 86400000);
    const renewalRoute = url(compile(source('../app/api/profile/renew/route.ts'))
      .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
      .replace('@/lib/chart-ticket', tickets).replace('@/db/profile-deletion', deletion));
    const { POST: renewProfile } = await import(renewalRoute);
    const renew = (chartTicket = expired, session = 'owner') => renewProfile(new Request('https://example.test/api/profile/renew', {
      method: 'POST', headers: { Cookie: `nirayana_pilot_session=${session}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ chartTicket, profileId: 'one', chart: { rashi: 'Mesha' }, birthTimeKnown: false, latitude: 0 }),
    }));
    const renewedResponse = await renew();
    assert.equal(renewedResponse.status, 409);
    assert.equal((await renewedResponse.json()).code, 'provider_refresh_required');
    const fresh = await ticket('owner','one');
    const freshResponse = await renew(fresh);
    assert.equal(freshResponse.status,200);
    const renewed = await freshResponse.json();
    assert.equal(renewed.chartTicket,fresh,'fresh access must not mint a later credential');
    assert.equal(renewed.natalRecalculated, false);
    const reopened = await openChartTicket(secret, renewed.chartTicket, 'owner', 'one');
    assert.deepEqual(reopened.chart, chart, 'body overrides cannot replace server-owned facts');
    assert.equal(reopened.birthTimeKnown, true);
    assert.equal((await renew('tampered')).status, 401);
    assert.equal((await renew(expired, 'other')).status, 401);
    assert.equal(calls, beforeErasure, 'renewal must not call a paid provider or model');
    const eraseProfile = (chartTicket = expired, session = 'owner', profileId = 'one') => deleteProfile(new Request('https://example.test/api/profile/delete', {
      method: 'POST', headers: { Cookie: `nirayana_pilot_session=${session}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ chartTicket, profileId }),
    }));
    assert.equal((await post({ ...base, chartTicket: expired })).status, 401, 'expired capability cannot read');
    assert.equal((await eraseProfile('tampered')).status, 401);
    assert.equal((await eraseProfile(expired, 'other')).status, 401);
    assert.equal((await eraseProfile(expired, 'owner', 'another-profile')).status, 401);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM deleted_chart_sessions').get().n, 0);
    for (const session of ['owner', 'surviving-owner']) {
      db.prepare(`INSERT INTO profile_generations (id,session_id,day_key,status,credits,created_at,updated_at,request_hash,response_ciphertext,response_expires_at)
        VALUES (?,?,?,'started',320,?,?,?,?,?)`).run(`generation-${session}`, session, '2026-09-07', Date.now(), Date.now(), 'test-hash', 'test-encrypted-placeholder', Date.now() + 10000);
    }
    assert.equal((await eraseProfile()).status, 200, 'expired capability can erase');
    assert.equal((await eraseProfile()).status, 200, 'deletion retry is idempotent');
    assert.equal((await renew()).status, 410, 'revoked session cannot renew');
    const erasedProfile = db.prepare("SELECT * FROM profile_generations WHERE session_id = 'owner'").get();
    assert.equal(erasedProfile.status, 'deleted');
    assert.equal(erasedProfile.request_hash, null);
    assert.equal(erasedProfile.response_ciphertext, null);
    assert.equal(erasedProfile.credits, 320, 'operational budget is not refunded by deletion');
    assert.equal(db.prepare("SELECT status FROM profile_generations WHERE session_id = 'surviving-owner'").get().status, 'started');
    assert.equal((await post()).status, 410, 'unexpired ticket is revoked too');
    assert.equal((await post({ ...base, requestId: 'new-after-profile-erasure' })).status, 410);
    const { reserveQuestion } = await import(receipts);
    const { reserveProfile } = await import(moduleUrl('../db/profile-reservation.ts'));
    // Check atomic reservation itself, not just the route's preflight check.
    assert.equal((await reserveQuestion(globalThis.__receiptTestEnv.DB, { id: 'racing-new', hash: 'test', session: 'owner', category: 'Career', language: 'en', now: Date.now(), limit: 100 })).kind, 'limit');
    assert.equal(await reserveProfile(globalThis.__receiptTestEnv.DB, { id: 'racing-profile', session: 'owner', day: '2026-09-08', now: Date.now(), limit: 60 }), 'limit');
    const recovery = url(compile(source('../db/profile-recovery.ts')).replace('./guidance-requests', receipts));
    const { completeProfile } = await import(recovery);
    await assert.rejects(completeProfile(globalThis.__receiptTestEnv.DB, secret, {
      id: 'generation-owner', session: 'owner', reply: { synthetic: true }, expiresAt: Date.now() + 10000, now: Date.now(),
    }), /could not be completed/, 'late chart completion cannot restore erased cache');
    assert.equal(calls, beforeErasure, 'revoked work cannot spend');
    // Real, assistant-reviewed catalogue; only the chart is synthetic.
    // Do not inject approvals or model text for this branch.
    const matchingChart = { rashi: 'Karka', nakshatra: 'Pushya', lagna: 'Karka', yogas: [],
      planets: ['Sun','Moon','Mars','Mercury','Jupiter','Venus','Saturn','Rahu','Ketu'].map(name => ({name, rasi: 'Karka', position: 4, degree: 1, isRetrograde: false})),
      navamsa: [{name: 'Mars', rasi: 'Mithuna', position: 3, degree: 1}],
    };
    const reviewedTicket = await issueChartTicket(secret, {sessionId: 'reviewed-owner', profileId: 'reviewed-profile', chart: matchingChart, birthTimeKnown: true});
    const reviewedBody = {requestId: 'reviewed-question-0001', category: 'Career', question: 'Which career direction could I explore?',
      language: 'en', responseStyle: 'english', profileId: 'reviewed-profile', chartTicket: reviewedTicket, researchConsent: false,
      chart: { ...matchingChart, planets: [] }, birthTimeKnown: false,
    };
    const beforeReviewed = calls;
    const rowsBefore = db.prepare('SELECT COUNT(*) AS n FROM guide_requests').get().n;
    const reviewedResponse = await post(reviewedBody, 'reviewed-owner');
    assert.equal(reviewedResponse.status, 200);
    const reviewedAnswer = await reviewedResponse.json();
    assert.equal(reviewedAnswer.answerMode, 'reviewed_traditional');
    assert.equal(reviewedAnswer.profileId, 'reviewed-profile');
    assert.equal(reviewedAnswer.evidence.length, 19);
    assert.match(reviewedAnswer.answer, /Writing, accounting and craft-based work/u);
    assert.match(reviewedAnswer.answer, /tenth houses from Lagna and Moon empty/u);
    assert.match(reviewedAnswer.answer, /Try one small task/u);
    assert.match(reviewedAnswer.answer, /not a complete career assessment/u);
    assert.equal(reviewedAnswer.interpretationProvenance.snapshotId, 'reviewed-profile');
    assert.ok(reviewedAnswer.interpretationProvenance.ruleVersions.includes('CAREER-BJ10-D9-MERCURY-CONVERGENCE-english@2'));
    const recoveredResponse = await post(reviewedBody, 'reviewed-owner');
    assert.equal(recoveredResponse.status, 200);
    const recoveredAnswer = await recoveredResponse.json();
    assert.equal(recoveredAnswer.replayed, true);
    assert.equal(recoveredAnswer.answer, reviewedAnswer.answer);
    assert.equal(recoveredAnswer.answeredAt, reviewedAnswer.answeredAt);
    assert.deepEqual(recoveredAnswer.evidence, reviewedAnswer.evidence);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM guide_requests').get().n, rowsBefore + 1);
    assert.equal((await post(reviewedBody, 'different-owner')).status, 401);
    assert.equal(calls, beforeReviewed, 'reviewed rendering and replay do not call the language model');
  } finally {
    release();
    globalThis.fetch = originalFetch;
    delete globalThis.__receiptTestEnv;
    db.close();
  }
});

test('encrypted reply is bound to request and key; corruption fails closed', async () => {
  const secret = '12'.repeat(32);
  const sealed = await sealReply(secret, 'request-one', { answer: 'Synthetic test response' });
  assert.deepEqual(await openReply(secret, 'request-one', sealed), { answer: 'Synthetic test response' });
  await assert.rejects(openReply(secret, 'request-two', sealed));
  await assert.rejects(openReply('34'.repeat(32), 'request-one', sealed));
  await assert.rejects(openReply(secret, 'request-one', sealed.slice(0, -1)));
});

test('guidance refresh uses ticket-bound location and shared context, never caller time or chart', async () => {
  const db = new DatabaseSync(':memory:');
  db.exec(source('../drizzle/0010_green_johnny_blaze.sql'));
  db.exec(source('../drizzle/0011_report_evidence.sql'));
  for (const name of ['0000_perpetual_giant_man', '0001_chilly_purple_man', '0002_broad_spacker_dave', '0003_reflective_betty_ross', '0007_cold_inhumans', '0008_damp_marvex']) db.exec(source(`../drizzle/${name}.sql`));
  const secret = 'c4'.repeat(32);
  const originalFetch = globalThis.fetch;
  const providerRequests = [];
  globalThis.__receiptTestEnv = { NIRAYANA_CHART_TICKET_KEY: secret, PROKERALA_ENVIRONMENT: 'production', PROKERALA_CLIENT_ID: 'synthetic-context-client', PROKERALA_CLIENT_SECRET: 'synthetic-secret', DB: {
    prepare(sql) { let args = []; return {
      bind(...values) { args = values; return this; },
      async run() { return { meta: { changes: Number(db.prepare(sql).run(...args).changes) } }; },
      async first() { return db.prepare(sql).get(...args) ?? null; },
    }; },
  } };
  globalThis.fetch = async address => {
    const target = new URL(address);
    assert.equal(target.origin, 'https://api.prokerala.com');
    if (target.pathname === '/token') return Response.json({ access_token: 'synthetic-token', expires_in: 3600 });
    providerRequests.push(target);
    if (target.pathname.endsWith('planet-position')) return Response.json({ data: { planet_position: [{ id: 1, name: 'Moon', degree: 10, position: 4, rasi: { name: 'Karka' } }] } });
    assert.ok(target.pathname.endsWith('panchang'));
    return Response.json({ data: { vaara: 'Test day', tithi: [{ name: 'Active test tithi', start: new Date(Date.now() - 60000).toISOString(), end: new Date(Date.now() + 3600000).toISOString() }] } });
  };
  try {
    const { POST } = await import(`${route}#current-context`);
    const profileId = 'context-one';
    const chartTicket = await issueChartTicket(secret, { sessionId: 'context-owner', profileId, birthTimeKnown: false,
      contextLocation: { latitude: 11.3428, longitude: 77.7274 },
      chart: { rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', planets: [], yogas: [], contextCalculatedAt: '2000-01-01T00:00:00Z', todayPanchang: { tithi: 'Stale tithi' } } });
    const body = { requestId: 'context-question-0001', category: 'Panchang', question: 'What is today’s Panchangam?', language: 'en', responseStyle: 'english', profileId, chartTicket,
      currentDatetime: '2000-01-01T00:00:00Z', latitude: 0, longitude: 0, chart: { rashi: 'Mesha' } };
    const post = payload => POST(new Request('https://example.test/api/guidance', { method: 'POST', headers: { Cookie: 'nirayana_pilot_session=context-owner', 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }));
    const first = await post(body);
    assert.equal(first.status, 200);
    const answer = await first.json();
    assert.ok(answer.evidence.some(line => line.includes('Active test tithi')));
    assert.ok(answer.evidence.every(line => !line.includes('Stale tithi')));
    assert.ok(answer.evidence.some(line => line.includes('Current Moon') && line.includes('Karka')));
    assert.equal(providerRequests.length, 2);
    assert.ok(providerRequests.every(target => target.searchParams.get('coordinates') === '11.3428,77.7274'));
    assert.ok(providerRequests.every(target => Math.abs(Date.parse(target.searchParams.get('datetime')) - Date.now()) < 10000));
    assert.ok(providerRequests.every(target => target.searchParams.get('datetime').endsWith('+05:30')), 'provider Panchang day must use Indian civil time');
    assert.equal((await post({ ...body, requestId: 'context-question-0002' })).status, 200);
    assert.equal(providerRequests.length, 2, 'a new question reuses fresh current context without another provider charge');
    await post({ ...body, requestId: 'context-question-0002' });
    assert.equal(providerRequests.length, 2, 'retry must not charge provider again');
    const unsupported = await post({ ...body, requestId: 'context-question-0003', category: 'Family', question: 'How is my parents health?' });
    assert.equal((await unsupported.json()).support, 'unsupported');
    assert.equal(providerRequests.length, 2, 'unsupported intents must not trigger context work');
  } finally { globalThis.fetch = originalFetch; delete globalThis.__receiptTestEnv; db.close(); }
});

 test('large chart recovery is explicit while chat receipts retain their smaller cap', async () => {
  const secret = '12'.repeat(32);
  const chart = { synthetic: 'x'.repeat(150_000) };
  await assert.rejects(sealReply(secret, 'profile:large', chart));
  const sealed = await sealReply(secret, 'profile:large', chart, 2_000_000);
  await assert.rejects(openReply(secret, 'profile:large', sealed));
  assert.deepEqual(await openReply(secret, 'profile:large', sealed, 2_000_000), chart);
  await assert.rejects(openReply(secret, 'profile:other', sealed, 2_000_000));
  await assert.rejects(sealReply(secret, 'profile:large', { value: 'x'.repeat(2_000_001) }, 2_000_000));
});
