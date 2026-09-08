import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

const source = readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const { buildEvidencePacket, buildFallbackAnswer, isValidChartFacts } = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const chart = {
  rashi: 'Kanya', nakshatra: 'Chitra', lagna: 'Vrischika', planets: [], yogas: [],
  currentDasha: { name: 'Mercury', start: '2024-10-27T00:00:00Z', end: '2041-10-27T00:00:00Z' },
  currentAntardasha: { name: 'Mercury', start: '2024-10-27T00:00:00Z', end: '2027-03-26T00:00:00Z' },
};
const packet = (question, category = 'Career', birthTimeKnown = true) => buildEvidencePacket({ question, category, birthTimeKnown, language: 'en', chart, now: new Date('2026-09-06T00:00:00Z') });

test('employment fallback addresses the specific intent in all three languages', () => {
  const cases = [
    ['Retirement plan start panna nalla period ah?', ['retirement', 'ஓய்வு', 'Retirement']],
    ['Job transfer accept pannalama?', ['transfer', 'இடமாற்ற', 'Transfer']],
    ['Abroad job chance iruka?', ['overseas', 'வெளிநாட்டு', 'Abroad']],
    ['சம்பள உயர்வு கிடைக்கும் காலம் எப்போது?', ['salary', 'சம்பள', 'Salary']],
    ['En career stable ah poguma?', ['security', 'நிலைத்திருக்கும்', 'secure']],
  ];
  for (const [question, terms] of cases) {
    for (const [i, style] of ['english', 'tamil', 'tanglish'].entries()) {
      const answer = buildFallbackAnswer({ ...packet(question), language: style === 'tamil' ? 'ta' : 'en' }, style);
      assert.ok(answer.includes(terms[i]), `${question}: ${style}`);
      assert.equal(answer.split('\n\n').length, 3);
      if (style === 'tanglish') assert.doesNotMatch(answer, /[\u0B80-\u0BFF]/u);
      assert.doesNotMatch(answer, /promotion criteria|two roles you are considering/iu);
    }
  }
});

test('interview questions keep their task despite location or transfer keywords', () => {
  for (const question of ['How will my overseas job interview go?', 'Job transfer interview eppadi irukkum?',
    'வெளிநாட்டு வேலை நேர்முகத் தேர்வு எப்படி இருக்கும்?', 'What should I pay attention to in my interview?']) {
    const answer = buildFallbackAnswer(packet(question), 'english');
    assert.match(answer, /result of your interview/u);
    assert.match(answer, /rehearse a short example/u);
    assert.doesNotMatch(answer, /salary increase|work-authorisation|transfer terms/u);
  }
  const ordinary = buildFallbackAnswer(packet('What should I pay attention to when choosing a career?'), 'english');
  assert.doesNotMatch(ordinary, /salary increase|pay-review/u);
});

test('Tamil chart display preserves canonical facts and fixes planetary terminology', () => {
  const input = { category: 'Career', question: 'வேலை எப்படி?', birthTimeKnown: true, chart: { ...chart,
    currentAntardasha: { ...chart.currentAntardasha, name: 'Venus' },
    planets: [{ name: 'Mercury', rasi: 'Karka', position: 4, degree: 20.5, isRetrograde: false }],
  }, now: new Date('2026-09-06T00:00:00Z') };
  const ta = buildEvidencePacket({ ...input, language: 'ta' });
  const en = buildEvidencePacket({ ...input, language: 'en' });
  for (const [field, canonical, display] of [['moon_sign', 'Kanya', 'கன்னி'], ['lagna', 'Vrischika', 'விருச்சிகம்'], ['mahadasha', 'Mercury', 'புதன்'], ['antardasha', 'Venus', 'சுக்கிரன்']]) {
    const fact = ta.facts.find(f => f.field === field);
    assert.equal(fact.value, canonical);
    assert.equal(fact.displayValue, display);
    assert.equal(en.facts.find(f => f.field === field).displayValue, undefined);
  }
  const mercury = ta.facts.find(f => f.value === 'Karka 20.50°');
  assert.equal(mercury?.displayValue, 'கடகம் 20.50°');
  const unknown = buildEvidencePacket({ ...input, language: 'ta', birthTimeKnown: false });
  assert.equal(unknown.facts.some(f => ['lagna', 'mahadasha', 'antardasha'].includes(f.field)), false);
});

test('an existing offer decision is not answered as waiting for an offer', () => {
  for (const question of ['Should I accept this job offer?', 'Should I reject this offer?', 'Indha offer accept pannalama?', 'இந்த வேலை வாய்ப்பை ஏற்கலாமா?', 'Which offer should I choose?']) {
    const p = packet(question);
    const en = buildFallbackAnswer(p, 'english');
    assert.match(en, /accepting or rejecting/);
    assert.match(en, /written responsibilities/);
    assert.doesNotMatch(en, /when a job offer will arrive|follow up on one/);
    const ta = buildFallbackAnswer({ ...p, language: 'ta' }, 'tamil');
    assert.match(ta, /நிபந்தனைகள்/);
    const tanglish = buildFallbackAnswer(p, 'tanglish');
    assert.match(tanglish, /accept pannalaamaa/);
    assert.doesNotMatch(tanglish, /[\u0B80-\u0BFF]/);
  }
  assert.match(buildFallbackAnswer(packet('When will I get a job offer?'), 'english'), /when a job offer will arrive/);
});

test('limited Career replies separate practical steps from unreviewed interpretation', () => {
  for (const [question, next] of [
    ['Should I change jobs now?', /written offer/],
    ['Will I get promoted?', /manager/],
    ['Which career suits me?', /two roles/],
  ]) {
    const p = packet(question);
    const reply = buildFallbackAnswer(p, 'english');
    assert.match(reply, next);
    assert.match(reply, /not a personalised astrological conclusion/);
    assert.doesNotMatch(reply, /Mercury|favourable period for you|definitely/);
    assert.doesNotMatch(buildFallbackAnswer(p, 'tanglish'), /[\u0B80-\u0BFF]/);
    assert.match(buildFallbackAnswer({ ...p, language: 'ta' }, 'tamil'), /நடைமுறை அடுத்த படி/);
  }
  const p = buildEvidencePacket({ category: 'Career', question: 'Career direction?', language: 'en', birthTimeKnown: true, chart: { ...chart, pada: 1 } });
  assert.match(p.facts.find(f => f.field === 'nakshatra').value, /Pada 1/);
});

test('new Career prompts receive question-specific limited replies in all three languages', () => {
  const cases = [
    ['Will I get this summer internship?', 'internship', 'பயிற்சிப் பணி', 'work sample'],
    ['Enakku internship select aaguma?', 'internship', 'பயிற்சிப் பணி', 'work sample'],
    ['இந்தப் பயிற்சி வேலை எனக்குக் கிடைக்குமா?', 'internship', 'பயிற்சிப் பணி', 'work sample'],
    ['How will my technical interview go?', 'interview', 'நேர்முகத் தேர்வின்', 'practice'],
    ['Naalaikku interview result epdi irukkum?', 'interview', 'நேர்முகத் தேர்வின்', 'practice'],
    ['நேர்முகத் தேர்வில் வெற்றி கிடைக்குமா?', 'interview', 'நேர்முகத் தேர்வின்', 'practice'],
    ['When can I expect an offer?', 'job offer', 'வேலை வாய்ப்பு', 'follow up'],
    ['Velai eppo kidaikkum?', 'job offer', 'வேலை வாய்ப்பு', 'follow up'],
    ['புதிய வேலை எப்போது கிடைக்கும்?', 'job offer', 'வேலை வாய்ப்பு', 'follow up'],
    ['Should I resign from this job?', 'change jobs', 'வேலை மாற்ற', 'written offer'],
  ];
  for (const [question, enTopic, taTopic, tanglishStep] of cases) {
    const p = packet(question);
    const english = buildFallbackAnswer(p, 'english');
    const tamil = buildFallbackAnswer({ ...p, language: 'ta' }, 'tamil');
    const tanglish = buildFallbackAnswer(p, 'tanglish');
    assert.ok(english.toLowerCase().includes(enTopic), question);
    assert.ok(tamil.includes(taTopic), question);
    assert.ok(tanglish.includes(tanglishStep), question);
    assert.doesNotMatch(tanglish, /[\u0B80-\u0BFF]/);
    for (const answer of [english, tamil, tanglish]) {
      assert.doesNotMatch(answer, /\d+\s*%|Mercury|Venus|Jupiter|October 12/i);
    }
    assert.match(english, /not a personalised astrological conclusion/);
    assert.equal((english.match(/Practical next step:/g) ?? []).length, 1);
  }
  // The targeted Career wording must not override subject/safety boundaries.
  assert.doesNotMatch(buildFallbackAnswer(packet('When will my wife get a job offer?'), 'english'), /review your active applications/);
  assert.doesNotMatch(buildFallbackAnswer(packet('I will kill myself if the interview fails'), 'english'), /rehearse a short example/);
});

test('chart boundary rejects malformed and contradictory numeric data', () => {
  const p = { name: 'Moon', rasi: 'Meena', degree: 4.5, position: 12, isRetrograde: false };
  assert.equal(isValidChartFacts({ ...chart, rashi: 'Meena', planets: [p] }), true);
  assert.equal(isValidChartFacts({ ...chart, rashi: 'மீனம்', planets: [{ ...p, rasi: 'Pisces' }] }), true);
  assert.equal(isValidChartFacts({ ...chart, planets: [p] }), false, 'Moon sign mismatch');
  assert.equal(isValidChartFacts({ ...chart, rashi: 'Meena', planets: [{ ...p, position: 1 }] }), false);
  assert.equal(isValidChartFacts({ ...chart, rashi: 'Invented sign' }), false);
  for (const invalid of [null, [], { ...chart, pada: 5 }, { ...chart, currentDasha: [] },
    { ...chart, todayPanchang: 'Sunday' }, { ...chart, yogas: [null] },
    { ...chart, planets: [p, { ...p, name: ' moon ' }] },
    ...[NaN, Infinity, -1, 30, '4.5'].map(degree => ({ ...chart, planets: [{ ...p, degree }] })),
    ...[NaN, Infinity, -1, 0, 13, 1.5, 360, 100].map(position => ({ ...chart, planets: [{ ...p, position }] })),
    { ...chart, planets: [{ ...p, isRetrograde: 'false' }] },
    { ...chart, planets: [null] }, { ...chart, transits: [null] },
  ]) {
    // Keep the Moon identity consistent so each case tests its own defect.
    const candidate = invalid && !Array.isArray(invalid) ? { ...invalid, rashi: 'Meena' } : invalid;
    assert.equal(isValidChartFacts(candidate), false);
  }
});

test('unknown birth time strips Lagna and both periods in every category', () => {
  for (const category of ['Daily','Education','Career','Love','Breakup','Relationships','Marriage','Family','Business','Property','Spiritual','Panchang']) {
    const result = packet('What can this chart support?', category, false);
    assert.equal(result.birthTimePrecision, 'unknown');
    assert.equal(result.facts.some(f => ['lagna', 'mahadasha', 'antardasha'].includes(f.field)), false, category);
  }
});
test('known-time period fields remain available', () => {
  assert.equal(packet('Career direction?').facts.find(f => f.field === 'mahadasha')?.value, 'Mercury');
});

test('periods require current, timezone-explicit dates and a valid parent interval', () => {
  const evaluate = (overrides, at = '2026-09-06T00:00:00Z') => buildEvidencePacket({
    question: 'Career direction?', category: 'Career', birthTimeKnown: true,
    language: 'en', chart: { ...chart, ...overrides }, now: new Date(at),
  }).facts.filter(f => ['mahadasha', 'antardasha'].includes(f.field));
  for (const start of ['invalid', '2024-10-27', '2024-02-30T00:00:00Z', '2027-01-01T00:00:00Z']) {
    assert.deepEqual(evaluate({ currentDasha: { ...chart.currentDasha, start } }), [], start);
  }
  assert.deepEqual(evaluate({}, '2041-10-27T00:00:00Z'), []);
  assert.deepEqual(evaluate({}, '2027-03-26T00:00:00Z').map(f => f.field), ['mahadasha']);
  assert.deepEqual(evaluate({ currentAntardasha: { ...chart.currentAntardasha, start: '2023-01-01T00:00:00Z' } }).map(f => f.field), ['mahadasha']);
  assert.equal(evaluate({}, '2024-10-27T00:00:00Z').length, 2);
  assert.deepEqual(evaluate({}, 'invalid'), []);
});

test('current context requires a recent nonfuture timestamp on the same India date', () => {
  const at = '2026-09-06T00:00:00Z';
  const evaluate = (contextCalculatedAt, now = at) => buildEvidencePacket({
    question: 'Daily guidance?', category: 'Daily', language: 'en', birthTimeKnown: true,
    now: new Date(now), chart: { ...chart, contextCalculatedAt,
      transits: [{ name: 'Moon', rasi: 'Mithuna', degree: 9, position: 69, isRetrograde: false }],
      todayPanchang: { vaara: 'Sunday' },
    },
  });
  for (const value of [undefined, 'invalid', '2026-09-05T00:00:00Z', '2026-09-06T01:00:00Z']) {
    const result = evaluate(value);
    assert.equal(result.facts.some(f => ['vaara', 'transit_moon'].includes(f.field)), false);
    assert.ok(result.missing.some(m => m.includes('context')));
  }
  assert.ok(evaluate(at).facts.some(f => f.field === 'transit_moon'));
  assert.equal(evaluate('2026-09-05T18:29:00Z', '2026-09-05T18:31:00Z').facts.some(f => f.field === 'vaara'), false);
  assert.equal(evaluate('2026-09-05T23:00:00Z').facts.some(f => f.field === 'vaara'), false);
});
test('ordinary education words are not death or illness keywords', () => {
  for (const question of ['Should I pursue higher studies?', 'My office is noisy, how can I focus?', 'My career stockroom role']) {
    assert.notEqual(packet(question, 'Education').intent, 'high_stakes', question);
  }
});
test('parent health and fertility questions are withheld before interpretation', () => {
  for (const question of ['How is my parents health?', 'என் பெற்றோரின் உடல்நலம் எப்படி இருக்கும்?', 'Baby eppo varum nu exact ah solla mudiyuma?', 'When will I die?', 'எனக்கு இந்த நோய் குணமாகுமா?']) {
    const result = packet(question, 'Family');
    assert.equal(result.intent, 'high_stakes', question);
    assert.equal(result.support, 'unsupported');
  }
});

test('unsupported responses are topic-specific and do not expose natal facts', () => {
  for (const [question, expected] of [
    ['How is my parents health?', /healthcare professional/],
    ['What is the legal outcome of my court case?', /qualified lawyer/],
    ['What is my investment return?', /verified financial information/],
  ]) {
    const result = packet(question, 'Family');
    assert.deepEqual(result.facts, []);
    assert.match(buildFallbackAnswer(result), expected);
    assert.doesNotMatch(buildFallbackAnswer(result), /emergency/);
    assert.doesNotMatch(buildFallbackAnswer(result, 'tanglish'), /[\u0B80-\u0BFF]/);
  }
  const crisis = buildFallbackAnswer(packet('I want to kill myself', 'Family'));
  assert.match(crisis, /someone you trust/);
  assert.match(crisis, /safe right now/);
  const missing = buildEvidencePacket({ category: 'Career', question: 'Career?', language: 'en', birthTimeKnown: false, chart: { planets: [], yogas: [] } });
  assert.match(buildFallbackAnswer(missing), /birth profile/);
  assert.doesNotMatch(buildFallbackAnswer(missing), /emergency|healthcare|lawyer/);
});

test('explicit other-person and matching questions never expose the account chart', () => {
  for (const question of ['Nanga rendu perum compatible ah?', 'என் குழந்தையின் படிப்பு குறித்து ஜாதகம் பார்க்கலாமா?', 'En child ku enna career suit aagum?', 'என் பேரக்குழந்தையின் திருமணம் எப்போது?', 'En child marriage eppo nadakkum?', 'Future partner oda work and nature epdi irukum?', 'Will my partner get a job?', 'எங்களுக்கு பொருத்தம் இருக்கா?']) {
    for (const category of ['Love', 'Family', 'Career', 'Marriage', 'Education']) {
      const result = packet(question, category);
      assert.equal(result.intent, 'additional_profile_required', question);
      assert.equal(result.support, 'unsupported');
      assert.deepEqual(result.facts, []);
      assert.deepEqual(result.matchedRules, []);
      assert.doesNotMatch(buildFallbackAnswer(result), /emergency|Mercury|Kanya/);
      assert.doesNotMatch(buildFallbackAnswer(result, 'tanglish'), /[\u0B80-\u0BFF]/);
    }
  }
});

test('own-person questions retain evidence and high-stakes intent takes precedence', () => {
  for (const question of ['How is my career?', 'Should I study childcare?', 'How can I communicate better in my relationship?']) {
    const result = packet(question);
    assert.notEqual(result.intent, 'additional_profile_required');
    assert.ok(result.facts.length > 0);
  }
  assert.equal(packet('Will my child recover from illness?', 'Family').intent, 'high_stakes');
});
