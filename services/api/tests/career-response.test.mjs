import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const source = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const rules = url(compile(source('../lib/career-rules.ts')));
const contract = url(compile(source('../lib/career-answer-contract.ts')).replace('./career-rules', rules));
const { reviewedCareerResponse, careerQuestionKind } = await import(url(compile(source('../lib/career-response.ts')).replaceAll('./astrology-evidence', url(compile(source('../lib/astrology-evidence.ts')))).replace('./career-rules', rules).replace('./career-answer-contract', contract)));

// Entirely synthetic approvals exercise plumbing, never actual astrology review.
const rule = { id: 'SYNTHETIC-RULE', version: 1, status: 'approved', language: 'english',
  prerequisites: ['test_field'], condition: { field: 'test_field', equals: 'test_value' },
  interpretation: 'SYNTHETIC traditional interpretation.', review: { interpretation: 'TEST', rights: 'TEST', language: 'TEST' } };
const bundle = { id: 'SYNTHETIC-BUNDLE', version: 1, status: 'approved', questionKind: 'career_direction', responseStyle: 'english', ruleIds: [rule.id],
  direct: { id: 'direct', text: 'SYNTHETIC direct response.', reviewId: 'TEST' },
  step: { id: 'step', text: 'SYNTHETIC useful step.', reviewId: 'TEST' },
  limitation: { id: 'limit', text: 'SYNTHETIC limitation.', reviewId: 'TEST' } };
const input = { snapshotId: 'profile-test', questionId: 'request-test', style: 'english',
  packet: { category: 'Career', support: 'partially_supported', question: 'Which career direction suits me?',
    facts: [{ field: 'test_field', label: 'TEST fact', value: 'test_value', source: 'TEST source' }] } };
const registry = { rules: [rule], bundles: [bundle] };

test('Career renderer connects direct response, interpretation, exact evidence, step and limitation', () => {
  const result = reviewedCareerResponse(input, registry);
  assert.equal(result.ok, true);
  assert.equal(result.answer, [bundle.direct.text, rule.interpretation, bundle.step.text, bundle.limitation.text].join('\n\n'));
  assert.deepEqual(result.evidence, ['TEST fact: test_value']);
  assert.equal(result.provenance.snapshotId, input.snapshotId);
  assert.equal(result.provenance.questionId, input.questionId);
  assert.equal(result.bundleVersion, 'SYNTHETIC-BUNDLE@1');
});

test('renderer automatically includes the exact condition fact as evidence', () => {
  const conditionFact = { field: 'separate_condition', label: 'Synthetic trigger', value: 'MATCH', source: 'TEST' };
  const result = reviewedCareerResponse({ ...input, packet: { ...input.packet, facts: [...input.packet.facts, conditionFact] } }, {
    ...registry, rules: [{ ...rule, condition: { field: conditionFact.field, equals: conditionFact.value } }],
  });
  assert.equal(result.ok, true);
  assert.deepEqual(result.evidence, ['TEST fact: test_value', 'Synthetic trigger: MATCH']);
});

test('display terminology does not change the canonical rule condition', () => {
  const localized = { ...input, packet: { ...input.packet, facts: input.packet.facts.map(f => ({ ...f, displayValue: 'காட்சி மதிப்பு' })) } };
  const result = reviewedCareerResponse(localized, registry);
  assert.equal(result.ok, true);
  assert.deepEqual(result.evidence, ['TEST fact: காட்சி மதிப்பு']);
  const wrongCanonical = { ...localized, packet: { ...localized.packet, facts: localized.packet.facts.map(f => ({ ...f, value: 'WRONG', displayValue: 'test_value' })) } };
  assert.equal(reviewedCareerResponse(wrongCanonical, registry).ok, false);
});

test('live catalogue cannot turn irrelevant or missing evidence into a reviewed reading', () => {
  assert.equal(reviewedCareerResponse(input).ok, false);
  for (const question of ['Enaku internship chance iruka?', 'என் முதல் வேலை எந்த துறையில் அமையலாம்?', 'Enaku first job eppo kedaikum?', 'இந்த வாரம் இருக்கும் நேர்முகத் தேர்வு எப்படி இருக்கும்?']) {
    assert.equal(reviewedCareerResponse({ ...input, packet: { ...input.packet, question } }).ok, false);
  }
});

test('review status, question type, language, missing facts and competing synthesis are enforced', () => {
  const reject = (change, catalog = registry) => assert.equal(reviewedCareerResponse({ ...input, ...change }, catalog).ok, false);
  reject({}, { ...registry, rules: [{ ...rule, status: 'candidate' }] });
  reject({}, { ...registry, bundles: [{ ...bundle, status: 'withdrawn' }] });
  reject({}, { ...registry, bundles: [{ ...bundle, direct: { ...bundle.direct, reviewId: '' } }] });
  reject({}, { ...registry, bundles: [bundle, { ...bundle, id: 'SECOND-SYNTHESIS' }] });
  reject({ style: 'tamil' });
  reject({ style: 'tamil' }, { ...registry, bundles: [{ ...bundle, responseStyle: 'tamil' }] });
  reject({ packet: { ...input.packet, question: 'When will I get a job?' } });
  reject({ packet: { ...input.packet, facts: [] } });
  reject({ packet: { ...input.packet, support: 'unsupported' } });
  reject({}, { ...registry, rules: [rule, { ...rule, status: 'withdrawn' }] });
});

test('Career questions distinguish intent across English, Tamil and Tanglish', () => {
  for (const [question, expected] of [
    ['Enaku internship chance iruka?', 'internship'],
    ['Should I accept this job offer?', 'job_offer'],
    ['Indha offer accept pannalama?', 'job_offer'],
    ['இந்த வேலை வாய்ப்பை ஏற்கலாமா?', 'job_offer'],
    ['When will I get a job offer?', 'job_timing'],
    ['இந்த வாரம் இருக்கும் நேர்முகத் தேர்வு எப்படி இருக்கும்?', 'interview'],
    ['Enaku first job eppo kedaikum?', 'job_timing'],
    ['என் முதல் வேலை எந்த துறையில் அமையலாம்?', 'career_direction'],
    ['Should I change jobs now?', 'job_change'],
    ['Velai maathalama?', 'job_change'],
    ['எனக்கு பதவி உயர்வு கிடைக்குமா?', 'promotion'],
    // Recorded failed QA questions: retain intent, never train on old answers.
    ['Retirement plan start panna nalla period ah?', 'retirement'],
    ['Job transfer accept pannalama?', 'job_transfer'],
    ['Abroad job chance iruka?', 'overseas_work'],
    ['வெளிநாட்டு வேலை வாய்ப்புக்கான நல்ல காலம் எது?', 'overseas_work'],
    ['En career stable ah poguma?', 'job_stability'],
    ['சம்பள உயர்வு கிடைக்கும் காலம் எப்போது?', 'salary'],
    ['இப்போது தொழில் மாற்றம் செய்வது ஏற்ற காலமா?', 'job_change'],
    ['What should I pay attention to in my interview?', 'interview'],
    ['How will my overseas job interview go?', 'interview'],
    ['Job transfer interview eppadi irukkum?', 'interview'],
    ['வெளிநாட்டு வேலை நேர்முகத் தேர்வு எப்படி இருக்கும்?', 'interview'],
    ['What should I pay attention to when choosing a career?', 'career_direction'],
    ['When is my pay review?', 'salary'],
  ]) assert.equal(careerQuestionKind(question), expected, question);
});

test('direction-only reviewed copy cannot answer unrelated employment outcomes', () => {
  for (const question of ['Retirement plan start panna nalla period ah?', 'Job transfer accept pannalama?',
    'Abroad job chance iruka?', 'En career stable ah poguma?', 'சம்பள உயர்வு கிடைக்கும் காலம் எப்போது?']) {
    const result = reviewedCareerResponse({ ...input, packet: { ...input.packet, question } }, registry);
    assert.equal(result.ok, false, question);
  }
});
