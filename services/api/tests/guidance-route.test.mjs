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
  .replace('@/lib/profile-overview', moduleUrl('../lib/profile-overview.ts'))
  .replace('@/lib/astrology-evidence', evidenceUrl)
  .replace('@/lib/chart-ticket', ticketUrl);
const protectedRouteCode = routeCode.replace('@/db/guidance-requests', moduleUrl('../db/guidance-requests.ts'))
  .replace('@/db/profile-deletion', url(compile(readFileSync(new URL('../db/profile-deletion.ts', import.meta.url), 'utf8')).replace('./guidance-requests', moduleUrl('../db/guidance-requests.ts'))))
  .replace('@/lib/career-response', careerUrl)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/marriage-report', moduleUrl('../lib/marriage-report.ts'))
  .replaceAll('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(readFileSync(new URL('../lib/provider-chart.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidenceUrl)));

test('actual guidance route blocks bad model output and avoids calls for unsupported/input failures', async () => {
  const originalFetch = globalThis.fetch;
  let providerCalls = 0;
  let modelReply = '';
  let modelInput;
  const writes = [];
  const secret = 'ab'.repeat(32);
  globalThis.__jyotaraRouteTestEnv = { NIRAYANA_CHART_TICKET_KEY: secret, OPENROUTER_API_KEY: 'TEST-NOT-A-REAL-KEY', DB: {
    prepare(sql) { let values = []; return {
      bind(...args) { values = args; return this; },
      async first() { return { count: 0 }; },
      async run() { writes.push({ sql, values }); return { meta: { changes: 1 } }; },
    }; }, async batch() { return []; },
  } };
  globalThis.fetch = async (address, options) => {
    modelInput = JSON.parse(JSON.parse(options.body).input);
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
    for (const bad of ['Mars Mahadasha is running.', 'Start at 4 PM.', 'You will definitely marry.', 'Advice '.repeat(111), 'Your wedding is guaranteed.']) {
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
    modelReply = 'Before leaving, compare the new role with what matters most to you. What is making you want to change jobs?';
    const beforeCareer = providerCalls;
    const career = await (await request({ ...base, category: 'Career', question: 'Should I change jobs now?',
      careerRules: [{ status: 'approved', interpretation: 'You will get the job tomorrow.' }],
      interpretationProvenance: { copyReviews: ['USER-FORGED'] }, answerMode: 'reviewed_traditional',
    })).json();
    assert.equal(providerCalls, beforeCareer + 1, 'Career can offer practical conversation without claiming a reviewed reading');
    assert.equal(career.answerMode, 'model_guidance');
    assert.deepEqual(career.evidence, []);
    assert.equal(career.limitation, undefined);
    assert.equal(career.interpretationProvenance, undefined, 'body cannot claim review approval');
    assert.equal(career.answer, modelReply);
    const requests = writes.filter(w => w.sql.includes('UPDATE guide_requests SET\n    support_level'));
    assert.equal(requests.length, 11);
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
      assert.equal(providerCalls, beforeCareer + 1);
      assert.deepEqual(approved.evidence, ['Moon sign: Meena']);
      assert.equal(approved.interpretationProvenance.snapshotId, 'profile-one');
      assert.match(approved.interpretationProvenance.questionId, /^[a-f0-9]{64}$/);
      assert.ok(approved.answer.includes('SYNTHETIC limitation.'));
      assert.equal(approved.limitation, undefined, 'do not append generic missing-review copy to a reviewed answer');
    } finally {
      careerRules.splice(0, careerRules.length, ...originalRules);
      careerCopyBundles.splice(0, careerCopyBundles.length, ...originalBundles);
    }
    globalThis.__jyotaraRouteTestEnv.PROKERALA_ENVIRONMENT = 'production';
    const beforeProviderOnly = providerCalls;
    const gap = await (await request({...base, category:'Career', question:'What does my chart show about work?'})).json();
    assert.equal(gap.answerMode,'chart_guidance');
    assert.equal(providerCalls,beforeProviderOnly+1,'Calculated chart context works without matching Yoga prose');
    assert.ok(gap.evidence.some(item=>item.includes('Chart calculations')));
    const providerChart = {...chart,yogas:[{name:'Raja Yoga',description:'Traditional recognition at work.'}]};
    const providerTicket = await issueChartTicket(secret,{sessionId:'test-session',profileId:'profile-one',birthTimeKnown:true,chart:providerChart});
    modelReply = 'Raja Yoga traditionally suggests recognition for your work.';
    const reading = await (await request({...base,category:'Career',question:'What does my chart show about work?',chartTicket:providerTicket})).json();
    assert.equal(reading.answerMode,'chart_guidance');
    assert.ok(reading.evidence.some(item=>item.includes('Chart calculations')));
    assert.equal(reading.interpretationProvenance,undefined,'Provider explanation must not claim independent review');
    const followup=await (await request({...base,guide:'Aadhirai',question:'What does that suggest?',previousUserMessages:['What does my chart show about my career?'],chartTicket:providerTicket})).json();
    assert.equal(followup.answerMode,'chart_guidance');
    assert.equal(modelInput.category,'Career');
    assert.equal(modelInput.chartContext.focus,'work, income and goals');
    for (const question of ['When will I get married?', 'I am worried about the delay', 'En kalyanam pathi sollunga']) {
      const typed=await (await request({...base,category:'Marriage',guide:'Tharagai',question,chartTicket:providerTicket})).json();
      assert.equal(typed.answerMode,question==='En kalyanam pathi sollunga'?'chart_guidance':'reading_unavailable',question);
      assert.ok(modelInput.chartContext, 'Typed messages must receive authenticated chart context');
    }
    const beforeInvalidGuide=providerCalls;
    assert.equal((await request({...base,guide:'invented guide'})).status,400);
    assert.equal(providerCalls,beforeInvalidGuide);

  } finally {
    globalThis.fetch = originalFetch;
    delete globalThis.__jyotaraRouteTestEnv;
  }
});
