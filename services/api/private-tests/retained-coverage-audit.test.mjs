import test from 'node:test';
import assert from 'node:assert/strict';
import {evaluateRetainedCoverage} from '../scripts/evaluate-retained-coverage.mjs';

test('offline coverage accounts for all 300 historical cases without inventing quality passes', async () => {
  const audit = await evaluateRetainedCoverage();
  assert.equal(audit.summary.total, 300);
  assert.equal(audit.summary.categories.Career, 48);
  assert.equal(new Set(audit.cases.map(row => `${row.profile}:${row.questionId}`)).size, 300);
  assert.equal(Object.values(audit.summary.statuses).reduce((a, b) => a + b, 0), 300);
  assert.equal(Object.values(audit.summary.priorVerdicts).reduce((a, b) => a + b, 0), 300);
  assert.ok(audit.cases.every(row => row.category === 'Career' || row.status !== 'reviewed_reading_available'));
  assert.ok(audit.cases.every(row => !('question' in row) && !('answer' in row) && !('datetime' in row)));
  assert.ok(audit.cases.every(row => row.status !== 'reviewed_reading_available' || row.appliedRuleVersions.length > 0));
  assert.match(audit.fingerprints.corpus, /^[a-f0-9]{64}$/);
  assert.match(audit.method, /no model generation or live provider calls/);
});
