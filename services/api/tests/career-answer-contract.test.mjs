import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const ruleUrl = url(compile(readFileSync(new URL('../lib/career-rules.ts', import.meta.url), 'utf8')));
const { careerRules } = await import(ruleUrl);
const code = compile(readFileSync(new URL('../lib/career-answer-contract.ts', import.meta.url), 'utf8')).replace('./career-rules', ruleUrl);
const { renderCareerSelection } = await import(url(code));
// Synthetic approved rule/copy ONLY to exercise the contract. No production rule is approved.
const rule = { ...careerRules[0], status: 'approved', review: { interpretation: 'TEST', rights: 'TEST', language: 'TEST' } };
const facts = rule.prerequisites.map(field => ({ field, label: field, value: field === rule.condition.field ? 'Mercury' : 'fixture', source: 'TEST' }));
const context = { snapshotId: 'snapshot-one', questionId: 'question-one',
  packet: { category: 'Career', support: 'partially_supported', facts }, rules: [rule],
  directAnswers: [{ id: 'direct', text: 'TEST direct answer', reviewId: 'TEST' }],
  nextSteps: [{ id: 'step', text: 'TEST next step', reviewId: 'TEST' }],
  limitations: [{ id: 'limit', text: 'TEST limitation', reviewId: 'TEST' }],
};
const selection = { snapshotId: context.snapshotId, questionId: context.questionId, directAnswerId: 'direct',
  evidenceIds: facts.map(f => f.field), ruleIds: [rule.id], nextStepId: 'step', limitationId: 'limit' };

test('ID-only answer renders exact server evidence and reviewed copy', () => {
  const result = renderCareerSelection(selection, context);
  assert.equal(result.ok, true);
  assert.equal(result.evidence.at(-2), `${rule.condition.field}: Mercury`);
  assert.match(result.answer, /TEST direct answer/);
  assert.deepEqual(result.provenance.ruleVersions, [`${rule.id}@1`]);
});
test('wrong subject, invented text, unsupported evidence and unreviewed interpretations fail closed', () => {
  for (const change of [{ snapshotId: 'someone-else' }, { questionId: 'different' },
    { answer: 'You will get a job at 4 PM' }, { evidenceIds: ['invented'] }, { ruleIds: ['invented'] },
    { evidenceIds: facts.slice(1).map(f => f.field) }, { directAnswerId: 'invented' },
    { ruleIds: [] }, { evidenceIds: [...selection.evidenceIds, selection.evidenceIds[0]] }]) {
    assert.equal(renderCareerSelection({ ...selection, ...change }, context).ok, false);
  }
  assert.equal(renderCareerSelection(selection, { ...context, rules: careerRules }).ok, false);
  assert.equal(renderCareerSelection(selection, { ...context, packet: { ...context.packet, support: 'unsupported' } }).ok, false);
  assert.equal(renderCareerSelection(selection, { ...context, nextSteps: [] }).ok, false);
});

test('duplicate catalogue IDs cannot select arbitrary versions or shadow withdrawn content', () => {
  for (const rules of [[rule, {...rule, version: 2}],
    [{...rule, status: 'candidate'}, rule], [rule, {...rule, status: 'candidate'}]]) {
    assert.deepEqual(renderCareerSelection(selection, {...context, rules}),
      {ok: false, reason: 'ambiguous_catalogue'});
  }
  for (const field of ['directAnswers', 'nextSteps', 'limitations']) {
    const original = context[field][0];
    assert.deepEqual(renderCareerSelection(selection, {...context,
      [field]: [original, {...original, reviewId: '', text: 'Withdrawn'}]}),
      {ok: false, reason: 'ambiguous_catalogue'});
  }
});

test('a condition fact cannot be used silently when omitted from prerequisites', () => {
  const externalCondition = { field: 'test_condition', label: 'Synthetic condition', value: 'MATCH', source: 'TEST' };
  const changedContext = { ...context, rules: [{ ...rule, condition: { field: externalCondition.field, equals: 'MATCH' } }],
    packet: { ...context.packet, facts: [...facts, externalCondition] } };
  assert.deepEqual(renderCareerSelection(selection, changedContext), { ok: false, reason: 'missing_condition_evidence' });
  const rendered = renderCareerSelection({ ...selection, evidenceIds: [...selection.evidenceIds, externalCondition.field] }, changedContext);
  assert.equal(rendered.ok, true);
  assert.ok(rendered.evidence.includes('Synthetic condition: MATCH'));
});
