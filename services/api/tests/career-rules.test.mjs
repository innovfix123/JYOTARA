import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const source = readFileSync(new URL('../lib/career-rules.ts', import.meta.url), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const { careerRules, eligibleCareerRules } = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);

test('candidate source is recorded but cannot enter answers', () => {
  assert.equal(careerRules[0].status, 'candidate');
  assert.match(careerRules[0].source.locator, /Chapter X/);
  assert.deepEqual(eligibleCareerRules({ mahadasha: 'Mercury', natal_mercury: 'Karka' }), []);
});

test('review and all dependencies are mandatory, not merely a planet match', () => {
  const candidate = careerRules[0];
  const facts = Object.fromEntries(candidate.prerequisites.map(key => [key, 'test evidence']));
  facts.tenth_lord_navamsa_lord = 'Mercury';
  assert.deepEqual(eligibleCareerRules(facts), []);
  // Synthetic review records only; never modify the production registry.
  const approved = { ...candidate, status: 'approved', review: { interpretation: 'TEST', rights: 'TEST', language: 'TEST' } };
  assert.equal(eligibleCareerRules(facts, [approved]).length, 1);
  for (const key of candidate.prerequisites) {
    const incomplete = { ...facts }; delete incomplete[key];
    assert.deepEqual(eligibleCareerRules(incomplete, [approved]), [], key);
  }
  assert.deepEqual(eligibleCareerRules({ ...facts, tenth_lord_navamsa_lord: 'Venus' }, [approved]), []);
  assert.deepEqual(eligibleCareerRules(facts, [{ ...approved, review: { ...approved.review, rights: null } }]), []);
  assert.deepEqual(eligibleCareerRules(facts, [{ ...approved, review: { ...approved.review, interpretation: '   ' } }]), []);
  assert.deepEqual(eligibleCareerRules(facts, [{ ...approved, status: 'withdrawn' }]), []);
});
