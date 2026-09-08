import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const moduleUrl = path => url(compile(readFileSync(new URL(path, import.meta.url), 'utf8')));
const evidenceUrl = moduleUrl('../lib/astrology-evidence.ts');
const rulesUrl = moduleUrl('../lib/career-rules.ts');
const contractUrl = url(compile(readFileSync(new URL('../lib/career-answer-contract.ts', import.meta.url), 'utf8')).replace('./career-rules', rulesUrl));
const careerUrl = url(compile(readFileSync(new URL('../lib/career-response.ts', import.meta.url), 'utf8')).replaceAll('./astrology-evidence', evidenceUrl).replace('./career-rules', rulesUrl).replace('./career-answer-contract', contractUrl));
const ticketUrl = url(compile(readFileSync(new URL('../lib/chart-ticket.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidenceUrl));
const { issueChartTicket } = await import(ticketUrl);
const source = readFileSync(new URL('../app/api/guidance/route.ts', import.meta.url), 'utf8');
const routeCode = compile(source)
  .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__jyotaraRouteTestEnv;')
  .replace('@/lib/guidance-language', moduleUrl('../lib/guidance-language.ts'))
  .replace('@/lib/astrology-evidence', evidenceUrl)
  .replace('@/lib/chart-ticket', ticketUrl);
const protectedRouteCode = routeCode.replace('@/db/guidance-requests', moduleUrl('../db/guidance-requests.ts'))
  .replace('@/db/profile-deletion', url(compile(readFileSync(new URL('../db/profile-deletion.ts', import.meta.url), 'utf8')).replace('./guidance-requests', moduleUrl('../db/guidance-requests.ts'))))
  .replace('@/lib/career-response', careerUrl)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(readFileSync(new URL('../lib/provider-chart.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidenceUrl)));

test('actual guidance route blocks bad model output and avoids calls for unsupported/input failures', async () => {
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let modelReply = '';
  const writes = [];
  const secret = 'ab'.repeat(32);
  globalThis.__jyotaraRouteTestEnv = { NIRAYANA_CHART_TICKET_KEY: secret, OPENROUTER_API_KEY: 'TEST-NOT-A-REAL-KEY', DB: {
    prepare(sql) { let values = []; return {
      bind(...args) { values = args; return this; },
      async first() { return { count: 0 }; },
      async run() { writes.push({ sql, values }); return { meta: { changes: 1 } }; },
    }; }, async batch() { return []; },
  } };
  globalThis.fetch = async (address) => {
    assert.equal(address, 'https://openrouter.ai/api/v1/responses');
    providerCalls++;
    return Response.json({ output_text: modelReply });
  };
  try {
    const { POST } = await import(url(protectedRouteCode));
    const chart = { rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', lagna: 'Mithuna', planets: [], yogas: [],
      currentDasha: { name: 'Mercury', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' },
      currentAntardasha: { name: 'Venus', start: '2020-01-01T00:00:00Z', end: '2040-01-01T00:00:00Z' },
    };
    const chartTicket = await issueChartTicket(secret, {sessionId: 'test-session', profileId: 'profile-one', birthTimeKnown: true, chart});
    const base = { category: 'Love', question: 'What should I focus on in relationships?', language: 'en', responseStyle: 'english', profileId: 'profile-one', chartTicket, researchConsent: false };
    const request = body => POST(new Request('https://example.test/api/guidance', { method: 'POST', headers: { 'Content-Type': 'application/json', Cookie: 'nirayana_pilot_session=test-session' }, body: JSON.stringify(body) }));
    modelReply = 'Mercury Mahadasha and Venus Antardasha are the supplied periods.';
    let response = await request(base);
    assert.equal(response.status, 200);
    assert.equal((await response.json()).answerMode, 'grounded_fallback');
    modelReply = 'Write down one need you want to express. Pick a calm moment and say: I would like us to plan some uninterrupted time together this week.';
    const practicalModel = await (await request(base)).json();
    assert.equal(practicalModel.answerMode, 'model_guidance');
    assert.deepEqual(practicalModel.evidence, []);
    for (const bad of ['Mars Mahadasha is running.', 'Start at 4 PM.', 'You will definitely marry.']) {
      modelReply = bad;
      const output = await (await request(base)).json();
      assert.equal(output.answerMode, 'grounded_fallback');
      assert.notEqual(output.answer, bad);
    }
    const before = providerCalls;
    for (const question of ['En child ku enna career suit aagum?', 'How is my parents health?']) {
      const output = await (await request({ ...base, question })).json();
      assert.equal(output.answerMode, 'grounded_fallback');
      assert.deepEqual(output.evidence, []);
    }
    assert.equal(providerCalls, before);
    response = await request({ ...base, profileId: 'different-person' });
    assert.equal(response.status, 401);
    response = await request({ ...base, chartTicket: 'tampered' });
    assert.equal(response.status, 401);
    assert.equal(providerCalls, before);
    modelReply = 'Mercury Mahadasha and Venus Antardasha are the supplied periods.';
    response = await request({...base, birthTimeKnown: false, chart: {...chart, rashi: 'Mesha', planets: [null]}});
    const protectedAnswer = await response.json();
    assert.equal(response.status, 200);
    assert.equal(protectedAnswer.profileId, 'profile-one');
    assert.ok(protectedAnswer.evidence.some(e => e.includes('Mercury')));
    assert.ok(!protectedAnswer.evidence.some(e => e.includes('Mesha')));
    const beforeCareer = providerCalls;
    const career = await (await request({ ...base, category: 'Career', question: 'Should I change jobs now?',
      careerRules: [{ status: 'approved', interpretation: 'You will get the job tomorrow.' }],
      interpretationProvenance: { copyReviews: ['USER-FORGED'] }, answerMode: 'reviewed_traditional',
    })).json();
    assert.equal(providerCalls, beforeCareer, 'unreviewed Career interpretation must not call a model');
    assert.equal(career.answerMode, 'grounded_fallback');
    assert.equal(career.interpretationProvenance, undefined, 'body cannot claim review approval');
    assert.match(career.answer, /Practical next step/);
    assert.match(career.answer, /not a personalised astrological conclusion/);
    const requests = writes.filter(w => w.sql.includes('UPDATE guide_requests SET\n    support_level'));
    assert.equal(requests.length, 9);
    assert.ok(requests.every(w => w.values[2] === null), 'question text not stored without research consent');
    // In-memory synthetic catalogues exercise the approved HTTP branch only.
    // No production source or review record is edited or approved by this test.
    const { careerRules } = await import(rulesUrl);
    const { careerCopyBundles } = await import(careerUrl);
    const originalRules = [...careerRules];
    const originalBundles = [...careerCopyBundles];
    try {
      careerRules.splice(0, careerRules.length, {
        id: 'TEST-HTTP-RULE', version: 1, status: 'approved', language: 'english',
        prerequisites: ['moon_sign'], condition: { field: 'moon_sign', equals: 'Meena' },
        interpretation: 'SYNTHETIC interpretation for HTTP plumbing only.',
        review: { interpretation: 'TEST', rights: 'TEST', language: 'TEST' },
      });
      careerCopyBundles.push({ id: 'TEST-HTTP-BUNDLE', version: 1, status: 'approved',
        questionKind: 'career_direction', responseStyle: 'english', ruleIds: ['TEST-HTTP-RULE'],
        direct: { id: 'direct', text: 'SYNTHETIC direct response.', reviewId: 'TEST' },
        step: { id: 'step', text: 'SYNTHETIC next step.', reviewId: 'TEST' },
        limitation: { id: 'limit', text: 'SYNTHETIC limitation.', reviewId: 'TEST' },
      });
      const approved = await (await request({ ...base, category: 'Career', question: 'Which career direction suits me?' })).json();
      assert.equal(approved.answerMode, 'reviewed_traditional');
      assert.equal(providerCalls, beforeCareer);
      assert.deepEqual(approved.evidence, ['Moon sign: Meena']);
      assert.equal(approved.interpretationProvenance.snapshotId, 'profile-one');
      assert.match(approved.interpretationProvenance.questionId, /^[a-f0-9]{64}$/);
      assert.ok(approved.answer.includes('SYNTHETIC limitation.'));
      assert.equal(approved.limitation, undefined, 'do not append generic missing-review copy to a reviewed answer');
    } finally {
      careerRules.splice(0, careerRules.length, ...originalRules);
      careerCopyBundles.splice(0, careerCopyBundles.length, ...originalBundles);
    }
  } finally {
    globalThis.fetch = originalFetch;
    delete globalThis.__jyotaraRouteTestEnv;
  }
});
