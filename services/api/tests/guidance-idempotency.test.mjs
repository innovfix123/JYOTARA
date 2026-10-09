import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
import {moduleFor} from './helpers/load.mjs';

const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const source = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const moduleUrl = path => moduleFor(path,'__receiptTestEnv');
const evidence = moduleUrl('../lib/astrology-evidence.ts');
const tickets = url(compile(source('../lib/chart-ticket.ts')).replace('./astrology-evidence', evidence));
const receipts = moduleUrl('../db/guidance-requests.ts');
const deletion = moduleUrl('../db/profile-deletion.ts');
const rules = moduleUrl('../lib/career-rules.ts');
const contract = url(compile(source('../lib/career-answer-contract.ts')).replace('./career-rules', rules));
const career = url(compile(source('../lib/career-response.ts')).replaceAll('./astrology-evidence', evidence).replace('./career-rules', rules).replace('./career-answer-contract', contract));
const { issueChartTicket, openChartTicket } = await import(tickets);
const { sealReply, openReply } = await import(receipts);
const route = url(compile(source('../app/api/guidance/route.ts'))
  .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
  .replace('@/runtime/financial-tracking',moduleUrl('../runtime/financial-tracking.ts'))
  .replace('@/runtime/research-content',moduleUrl('../runtime/research-content.ts'))
  .replace('@/lib/chat-access-window', url(compile(source('../lib/chat-access-window.ts'))))
      .replace('@/lib/chart-ticket', tickets)
  .replace('@/db/guidance-requests', receipts)
  .replace('@/db/profile-deletion', deletion)
  .replace('@/lib/career-response', career)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/divine-calculations', moduleUrl('../lib/divine-calculations.ts'))
  .replace('@/lib/limited-birth-guidance', moduleFor('../lib/limited-birth-guidance.ts'))
  .replace('@/lib/conversation-acknowledgement', moduleUrl('../lib/conversation-acknowledgement.ts'))
  .replace('@/lib/divine-consultation', moduleUrl('../lib/divine-consultation.ts'))
  .replace('@/lib/marriage-report', moduleUrl('../lib/marriage-report.ts'))
  .replaceAll('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(source('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence)))
  .replace('@/lib/profile-overview', url(compile(source('../lib/profile-overview.ts')))).replace('@/lib/astrology-evidence', evidence)
  .replace('@/lib/guidance-language', moduleUrl('../lib/guidance-language.ts')).replace('@/lib/consultation-writer', moduleUrl('../lib/consultation-writer.ts')));

test('conversational mode rejects a Detailed purchase or upgrade before provider work',async()=>{
 const {POST}=await import(route+'#conversation-mode-validation');
 const originalFetch=globalThis.fetch;
 let calls=0;
 globalThis.fetch=async()=>{calls++;throw Error('Unexpected provider work');};
 try {
  for(const extra of [{depth:'detailed'},{depth:'standard',upgradeFrom:'original-reading'}]) {
   const response=await POST(new Request('https://example.test/api/guidance',{method:'POST',body:JSON.stringify({category:'Career',question:'Help me think through my next step.',responseMode:'conversation',...extra})}));
   assert.equal(response.status,400);
   assert.match((await response.json()).error,/standard price.*paid upgrades/);
  }
  assert.equal(calls,0);
 } finally {globalThis.fetch=originalFetch;}
});

test('actual route reserves before model work, replays encrypted result, allows continued chat and isolates identities', async () => {
  const db = new DatabaseSync(':memory:');
  for (const name of ['0000_perpetual_giant_man', '0001_chilly_purple_man', '0002_broad_spacker_dave', '0003_reflective_betty_ross', '0004_powerful_juggernaut', '0007_cold_inhumans', '0009_salty_skrulls']) {
    db.exec(source(`../drizzle/${name}.sql`));
  }
  db.exec(source('../drizzle/0010_green_johnny_blaze.sql'));
  db.exec(source('../drizzle/0011_report_evidence.sql'));
  db.exec(source('../drizzle/0013_divine_cleanup.sql'));
  for(const name of ['0012_phone_login','0017_coin_wallet','0018_coin_context','0019_live_wallet','0025_account_profile_backup'])db.exec(source(`../drizzle/${name}.sql`));
  const person={name:'QA Kavin',gender:'male',place:'Chennai',datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707};
  const secret = 'a3'.repeat(32);
  const originalFetch = globalThis.fetch;
  let calls = 0;
  let release;
  let started;
  const modelStarted = new Promise(resolve => { started = resolve; });
  const modelWait = new Promise(resolve => { release = resolve; });
  globalThis.__receiptTestEnv = { NIRAYANA_CHART_TICKET_KEY: secret, DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test-token', OPENROUTER_API_KEY: 'TEST-ONLY', DB: {
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
  globalThis.fetch = async (address, options) => {
    if(String(address).endsWith('/session/delete'))return Response.json({deleted:true});
    calls++;
    started();
    if (calls === 1) await modelWait;
    const answer='Focus on one need you would like to discuss. What matters most to you?';
    return Response.json(address.includes('ask.divine')?{answer,credits_charged:30}:{choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[answer]})}}]});
  };
  try {
    const { POST, DELETE } = await import(route);
    const chart = { rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', lagna: 'Mithuna', planets: [], yogas: [],
      currentDasha: { name: 'Mercury', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' },
      currentAntardasha: { name: 'Venus', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' } };
    const ticket = (sessionId, profileId) => issueChartTicket(secret, { sessionId, profileId, chart, birthTimeKnown: true, birthDatetime:person.datetime, contextLocation:{latitude:person.latitude,longitude:person.longitude} });
    const base = { reportPerson:person, requestId: 'request-0000000001', category: 'Love', question: 'What should I focus on?', language: 'en', responseStyle: 'english', researchConsent: false, profileId: 'one', chartTicket: await ticket('owner', 'one') };
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
    assert.equal(calls, 2, 'one draft and one review; replay makes no new calls');
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
    assert.deepEqual(burst.map(r => r.status).sort(), [200, 200, 200, 200]);
    assert.equal(db.prepare("SELECT COUNT(*) AS n FROM guide_requests WHERE session_id = 'owner'").get().n, 5);
    for(let n=6;n<=35;n++)assert.equal((await post({...base,requestId:`continued-chat-${String(n).padStart(6,'0')}`})).status,200, 'chat continues past both old limits');
    const unknownChart=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:false});
    const unknown={...base,requestId:'unknown-time-request-001',chartTicket:unknownChart,birthTimeKnown:true};
    const beforeUnknown=calls;
    const limited=await (await post(unknown)).json();
    assert.equal(limited.answerMode,'limited_guidance');
    assert.match(limited.answer,/What matters most/);
    assert.equal(calls,beforeUnknown+1,'unknown time uses general guidance only, never Divine');
    assert.equal((await (await post(unknown)).json()).replayed,true);
    assert.equal(calls,beforeUnknown+1,'limited retry reuses encrypted receipt');
    const unavailableRasi=await (await post({...unknown,requestId:'unknown-time-rasi-0001',question:'What is my Rasi?'})).json();
    assert.match(unavailableRasi.answer,/can’t confirm/);
    assert.equal(calls,beforeUnknown+1,'no invented birth time sent for Rasi');
    const after = calls;
    assert.equal((await post()).status, 200, 'replay works without new provider work');
    db.prepare('UPDATE guide_requests SET response_expires_at = 0 WHERE id = ?').run(stored.id);
    assert.equal((await post()).status, 409, 'expired receipt is not a new billable attempt');
    assert.equal(calls, after);
    assert.equal(db.prepare('SELECT response_ciphertext FROM guide_requests WHERE id = ?').get(stored.id).response_ciphertext, null);

    const remove = session => DELETE(new Request('https://example.test/api/guidance', {
      method: 'DELETE', headers: { Cookie: `nirayana_pilot_session=${session}` },
    }));
    assert.equal((await remove('owner')).status, 204);
    assert.equal((await post()).status, 410, 'deleted receipt never replays or resubmits');
    // Deleted receipts remain protected; a fresh question is tested separately below.
    assert.equal(calls, after, 'erasure and deleted retries make no new provider calls');
    const erased = db.prepare("SELECT * FROM guide_requests WHERE session_id = 'owner'").all();
    assert.equal(erased.length, 37);
    for (const row of erased) {
      assert.equal(row.answer_mode, 'deleted');
      for (const field of ['question_text', 'intent', 'research_consent_version', 'age_band', 'request_hash', 'response_ciphertext', 'response_expires_at']) assert.equal(row[field], null, field);
    }
    assert.equal((await post({ ...base, chartTicket: await ticket('other', 'one') }, 'other')).status, 200, 'another session survives erasure');

    let pendingStarted;
    let finishPending;
    const began = new Promise(resolve => { pendingStarted = resolve; });
    const pause = new Promise(resolve => { finishPending = resolve; });
    globalThis.fetch = async (address, options) => {
      if(String(address).endsWith('/session/delete'))return Response.json({deleted:true});
      calls++;
      pendingStarted();
      await pause;
      const answer='Focus on one need you would like to discuss. What matters most to you?';
    return Response.json(address.includes('ask.divine')?{answer,credits_charged:30}:{choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[answer]})}}]});
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
      .replace('@/lib/chat-access-window', url(compile(source('../lib/chat-access-window.ts'))))
      .replace('@/lib/chart-ticket', tickets).replace('@/db/profile-deletion', deletion));
    const { POST: deleteProfile } = await import(deleteRoute);
    const expired = await issueChartTicket(secret, { sessionId: 'owner', profileId: 'one', chart, birthTimeKnown: true }, Date.now() - 2 * 86400000);
    const renewalRoute = url(compile(source('../app/api/profile/renew/route.ts'))
      .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
      .replace('@/lib/chat-access-window', url(compile(source('../lib/chat-access-window.ts'))))
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
    assert.equal(erasedProfile.request_hash, 'erased:' + erasedProfile.id);
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
    // Verify the deterministic approved fallback when no writer is configured.
    delete globalThis.__receiptTestEnv.OPENROUTER_API_KEY;
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
    assert.equal(reviewedAnswer.answerMode, 'limited_guidance');assert.doesNotMatch(reviewedAnswer.answer,/confirm your saved|birth time/);
    assert.equal(reviewedAnswer.profileId, 'reviewed-profile');
    assert.deepEqual(reviewedAnswer.evidence, []);
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

test('Divine route verifies birth details, replays without charge and isolates provider conversations',async()=>{
 const db=new DatabaseSync(':memory:');
 for(const name of ['0000_perpetual_giant_man','0001_chilly_purple_man','0002_broad_spacker_dave','0003_reflective_betty_ross','0004_powerful_juggernaut','0007_cold_inhumans','0009_salty_skrulls','0010_green_johnny_blaze','0011_report_evidence','0013_divine_cleanup','0012_phone_login','0017_coin_wallet','0018_coin_context','0019_live_wallet','0025_account_profile_backup'])db.exec(source(`../drizzle/${name}.sql`));
 const secret='ef'.repeat(32);const old=globalThis.fetch;const requests=[];
 globalThis.__receiptTestEnv={NIRAYANA_CHART_TICKET_KEY:secret,JYOTARA_CHAT_PROVIDER:'divine',DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test-token',OPENROUTER_API_KEY:'test',DB:{
  prepare(sql){let args=[];return{bind(...v){args=v;return this;},async run(){return{meta:{changes:Number(db.prepare(sql).run(...args).changes)}};},async first(){return db.prepare(sql).get(...args)||null;}};}
 }};
 const reading='Venus may favour commitment. Marriage discussions may progress slowly.';
 globalThis.fetch=async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  requests.push({url,payload:JSON.parse(opts.body)});
  if(url.includes('ask.divine'))return Response.json({answer:reading,credits_charged:30});
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:reading,source_quotes:['Venus may favour commitment.']})}}]});
 };
 try{
  const {POST}=await import(`${route}#divine`);
  const person={datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707,name:'QA alias',gender:'male',place:'Chennai'};
  const chart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',planets:[],yogas:[]};
  const ticket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',chart,birthTimeKnown:true,birthDatetime:person.datetime,contextLocation:{latitude:person.latitude,longitude:person.longitude}},Date.now()-2*86400000);
  const base={requestId:'divine-question-0001',profileId:'one',chartTicket:ticket,category:'Marriage',question:'When will I get married?',language:'en',responseStyle:'english',reportPerson:person};
  const post=body=>POST(new Request('https://test/api/guidance',{method:'POST',headers:{cookie:'nirayana_pilot_session=owner','content-type':'application/json'},body:JSON.stringify(body)}));
  const first=await (await post(base)).json();assert.equal(first.answer,reading);assert.equal(first.answerMode,'provider_reading');assert.equal(requests.length,2);
  assert.equal(first.providerUsage.calls[0].credits,30);
  const replay=await (await post(base)).json();assert.equal(replay.replayed,true);assert.equal(requests.length,2);
  await post({...base,requestId:'divine-question-0002',question:'What about family approval?',conversationHistory:[{role:'user',content:base.question},{role:'assistant',content:reading}]});
  assert.equal(requests.length,4);assert.notEqual(requests[0].payload.session_id,requests[2].payload.session_id);
  assert.ok(requests[2].payload.message.includes('family approval'));
  const beforeEquivalent=requests.length;
  const equivalent=await (await post({...base,requestId:'divine-equivalent-0001',reportPerson:{...person,datetime:'2001-06-12T00:50:00Z'}})).json();
  assert.equal(equivalent.answerMode,'provider_reading');assert.equal(requests.length,beforeEquivalent+2);
  assert.equal(requests[beforeEquivalent].payload.hour,'6','Use verified birth-location offset, not representation of the same instant');
  const beforeMismatch=requests.length;
  const mismatch=await (await post({...base,requestId:'divine-question-0003',reportPerson:{...person,datetime:'2002-06-12T06:20:00+05:30'}})).json();
  assert.equal(mismatch.answerMode,'limited_guidance');assert.equal(requests.length,beforeMismatch+1);assert.match(requests.at(-1).url,/openrouter/,'unverified birth details must not reach Divine');assert.doesNotMatch(mismatch.answer,/confirm your saved|birth time/);
  const conversationHistory=Array.from({length:32},(_,i)=>({role:i%2?'assistant':'user',content:`Previous relationship discussion ${i}.`}));
  const conversationMemory=['My family already knows about us.','We agreed that I would wait for their reply.'];
  const unified={...base,requestId:'unified-question-0001',depth:'standard',responseMode:'conversation',conversationHistory,conversationMemory};
  const beforeUnified=requests.length;
  const legacyTooLong=await post({...base,requestId:'legacy-history-too-long',conversationHistory});
  assert.equal(legacyTooLong.status,400);assert.equal(requests.length,beforeUnified);
  const unifiedReply=await (await post(unified)).json();
  assert.equal(unifiedReply.answer,reading);assert.equal(requests.length,beforeUnified+2);
  const sourceRequest=requests[beforeUnified].payload;
  assert.equal(sourceRequest.depth,'standard');assert.equal(sourceRequest.length_cap,'full');
  assert.deepEqual(JSON.parse(sourceRequest.message).conversation_context,conversationHistory);
  assert.deepEqual(JSON.parse(sourceRequest.message).earlier_user_statements,conversationMemory);
  const unifiedReplay=await (await post(unified)).json();
  assert.equal(unifiedReplay.replayed,true);assert.equal(requests.length,beforeUnified+2);
  assert.equal(unifiedReplay.providerUsage.newProviderCalls,0);
  const changedMemory=await post({...unified,conversationMemory:['My family does not know about us.']});
  assert.equal(changedMemory.status,409);assert.equal(requests.length,beforeUnified+2);
  const invalidMemory=await post({...unified,requestId:'invalid-memory-0001',conversationMemory:['x'.repeat(1001)]});
  assert.equal(invalidMemory.status,400);assert.equal(requests.length,beforeUnified+2);
  const noContact='My relationship ended and they asked me not to contact them. '+'I want to respect that boundary while I recover. '.repeat(8);
  assert.ok(noContact.length>240);
  const boundary=await (await post({...unified,requestId:'long-user-boundary-01',category:'Career',question:'Should I give them another chance?',conversationMemory:[],previousUserMessages:[],conversationHistory:[{role:'user',content:noContact},{role:'assistant',content:'Try messaging from another account.'}]})).json();
  assert.equal(boundary.answerMode,'practical_guidance');
  assert.match(boundary.answer,/Respect the request for no contact/);
  assert.equal(requests.length,beforeUnified+2,'a long retained boundary must avoid paid provider work');
  const beforeAck=requests.length;
  const ack={...base,requestId:'local-acknowledgement-01',question:'Please keep it brief.',responseMode:'conversation',userMessageBatch:['Please keep it brief.']};
  const ackReply=await (await post(ack)).json();
  assert.equal(ackReply.answerMode,'limited_guidance');
  assert.match(ackReply.answer,/brief|short/i);
  assert.equal(ackReply.providerUsage.newProviderCalls,0);
  const ackReplay=await (await post(ack)).json();
  assert.equal(ackReplay.replayed,true);assert.equal(ackReplay.answer,ackReply.answer);
  assert.equal((await post({...ack,question:'Thanks',userMessageBatch:['Thanks']})).status,409,'changed same-ID preference cannot overwrite its saved receipt');
  const foreign=await POST(new Request('https://test/api/guidance',{method:'POST',headers:{cookie:'nirayana_pilot_session=foreign','content-type':'application/json'},body:JSON.stringify(ack)}));
  assert.equal(foreign.status,401);
  assert.equal((await post({...ack,requestId:'invalid-acknowledgement-01',chartTicket:'tampered'})).status,401);
  assert.equal((await post({...ack,requestId:'forged-free-batch-01',question:'When will I get married?',userMessageBatch:['Thanks']})).status,400);
  assert.equal(requests.length,beforeAck,'acknowledgment, replay and rejected requests must not call a provider');
  const mixed=['When will I get married?','Please keep it brief.'];
  const mixedReply=await (await post({...ack,requestId:'real-question-plus-brief-01',question:mixed.join('\n'),userMessageBatch:mixed})).json();
  assert.equal(mixedReply.answerMode,'provider_reading');assert.equal(requests.length,beforeAck+2,'a real question with a preference is still a full reading');
  const multiline=await (await post({...ack,requestId:'legacy-multiline-brief-01',question:'Please\nkeep it brief.',userMessageBatch:undefined})).json();
  assert.equal(multiline.answerMode,'provider_reading','legacy whitespace must not turn a paid quote into a free local response');
  assert.equal(requests.length,beforeAck+4);
  db.prepare('INSERT INTO deleted_chart_sessions (session_id,expires_at) VALUES (?,?)').run('owner',Date.now()+60000);
  assert.equal((await post({...ack,requestId:'deleted-acknowledgement-01'})).status,410);
  assert.equal(requests.length,beforeAck+4);
  assert.equal(db.prepare('SELECT COUNT(*) AS n FROM divine_cleanup').get().n,0);
 }finally{globalThis.fetch=old;delete globalThis.__receiptTestEnv;db.close();}
});
