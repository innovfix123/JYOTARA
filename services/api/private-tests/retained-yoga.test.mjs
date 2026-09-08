import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = source => ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = code => `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`;
const evidence = url(compile(readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8')));
const { normalizeProviderChart, normalizeProviderNavamsa, normalizeProviderYogaAssessments } = await import(url(compile(readFileSync(new URL('../lib/provider-chart.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidence)));
test('retained paid Advanced Kundli resolves nested checks without another provider call', () => {
  const retained = JSON.parse(readFileSync(process.env.JYOTARA_PRIVATE_YOGA_FILE,'utf8'));
  const groups = retained.results.advancedKundli.response.data.yoga_details;
  const checks = normalizeProviderYogaAssessments(groups,true);
  assert.equal(checks.length,21);
  assert.equal(checks.filter(y=>y.present).length,7);
  assert.equal(checks.find(y=>y.name==='ராஜ யோகம்').present,true);
  assert.equal(checks.find(y=>y.name==='ஹம்ஸ யோகம்').present,false);
  assert.ok(checks.every(y=>!groups.some(group=>group.name===y.name)));
});
