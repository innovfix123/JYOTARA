import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = source => ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = code => `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`;
const evidence = url(compile(readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8')));
const { normalizeProviderChart, normalizeProviderNavamsa, normalizeProviderYogaAssessments } = await import(url(compile(readFileSync(new URL('../lib/provider-chart.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidence)));
const at = new Date('2026-09-06T00:00:00Z');
const p = { name: 'Mercury', start: '2020-01-01T00:00:00Z', end: '2030-01-01T00:00:00Z' };
const fixture = () => ({ sandbox: false, contextCalculatedAt: at.toISOString(),
  result: { data: { nakshatra_details: { chandra_rasi: { name: 'Meena' }, nakshatra: { name: 'Uttara Bhadrapada', pada: 1 } } } },
  planetPosition: { data: { planet_position: [
    { id: 100, rasi: { name: 'Mithuna' } },
    { id: 1, name: 'Moon', rasi: { name: 'Meena' }, position: 12, degree: 4.5 },
    { id: 2, name: 'Mars', rasi: { name: 'Karka' } },
  ] } }, dashaPeriods: { data: { dasha_periods: [{ ...p, antardasha: [p] }] } },
  panchang: { data: { tithi: [{ name: 'Expired', start: '2020-01-01T00:00:00Z', end: '2020-01-02T00:00:00Z' }] } },
});

test('nested yoga detections preserve true and false without treating headings as yogas', () => {
  const groups = [{name:'Major Yogas', description:'Summary only', yoga_list:[
    {name:'Raja Yoga',has_yoga:true,description:'Synthetic provider explanation'},
    {name:'Hamsa Yoga',has_yoga:false,description:'Synthetic absence'},
  ]}];
  const f = fixture(); f.result.data.yoga_details = groups;
  const mapped = normalizeProviderChart(f,true,at);
  assert.deepEqual(mapped.yogas,[{name:'Raja Yoga',description:'Synthetic provider explanation'}]);
  assert.equal(mapped.yogaAssessments.length,2);
  assert.equal(mapped.yogaAssessments[1].present,false);
  assert.deepEqual(normalizeProviderChart(f,false,at).yogas,[]);
  assert.equal(normalizeProviderChart(f,false,at).yogaAssessments,undefined);
  for(const malformed of [
    [{name:'Major Yogas',description:'2 yogas'}],
    [{...groups[0],yoga_list:[{...groups[0].yoga_list[0],has_yoga:'true'}]}],
    [{...groups[0],yoga_list:[groups[0].yoga_list[0],{...groups[0].yoga_list[0],has_yoga:false}]}],
  ]) assert.equal(normalizeProviderYogaAssessments(malformed,true),undefined);
});

test('fabricated multi-group Tamil yoga fixture preserves all positive and negative checks', () => {
  // Fabricated nested structure; no provider payload or person is included.
  const groups = Array.from({length:3}, (_,g) => ({name: `Group ${g}`, yoga_list: Array.from({length:7},(_,i) => ({name: g===0 && i===0 ? '\u0bb0\u0bbe\u0b9c \u0baf\u0bcb\u0b95\u0bae\u0bcd' : g===1 && i===0 ? '\u0bb9\u0bae\u0bcd\u0bb8 \u0baf\u0bcb\u0b95\u0bae\u0bcd' : `Synthetic ${g}-${i}`, has_yoga:g===0, description:'Fabricated check'}))}));
  const checks = normalizeProviderYogaAssessments(groups,true);
  assert.equal(checks.length,21);
  assert.equal(checks.filter(y=>y.present).length,7);
  assert.equal(checks.find(y=>y.name==='ராஜ யோகம்').present,true);
  assert.equal(checks.find(y=>y.name==='ஹம்ஸ யோகம்').present,false);
  assert.ok(checks.every(y=>!groups.some(group=>group.name===y.name)));
});

const d9 = () => ({ status: 'ok', data: { divisional_positions: ['Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', 'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena'].map((name, id) => ({
  rasi: { name, id }, planet_positions: id < 9 ? [{ planet: { id: id < 7 ? id : id + 94, name: ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Rahu', 'Ketu'][id] }, rasi: { name, id }, sign_degree: 12.5 }] : [],
})) } });
test('Navamsa uses separate provider positions and zero-based sign IDs', () => {
  const result = normalizeProviderNavamsa(d9(), true);
  assert.equal(result.length, 9);
  assert.deepEqual(result[0], { name: 'Sun', rasi: 'Mesha', position: 1, degree: 12.5 });
  assert.equal(result.some(p => 'isRetrograde' in p), false);
  assert.equal(result.find(p => p.name === 'Rahu').position, 8);
  assert.equal(result.find(p => p.name === 'Ketu').position, 9);
  const mapped = normalizeProviderChart({ ...fixture(), navamsa: d9() }, true, at);
  assert.equal(mapped.planets[0].position, 12);
  assert.equal(mapped.navamsa.find(p => p.name === 'Moon').position, 2);
  assert.equal(normalizeProviderChart({ ...fixture(), navamsa: d9() }, false, at).navamsa, undefined);
});
test('missing, incomplete, contradictory or duplicated D9 data is withheld', () => {
  assert.equal(normalizeProviderNavamsa(undefined, true), undefined);
  assert.equal(normalizeProviderNavamsa(d9(), false), undefined);
  for (const mutate of [
    p => p.data.divisional_positions.pop(),
    p => p.data.divisional_positions[0].planet_positions[0].rasi.id = 1,
    p => p.data.divisional_positions[0].planet_positions[0].sign_degree = 30,
    p => p.data.divisional_positions[0].planet_positions[0].planet.name = 'Moon',
    p => p.data.divisional_positions[1].planet_positions = [],
    p => p.data.divisional_positions[1] = p.data.divisional_positions[0],
    p => p.data.divisional_positions[7].planet_positions[0].planet.id = 7,
  ]) {
    const p = d9(); mutate(p);
    assert.equal(normalizeProviderNavamsa(p, true), undefined);
    assert.equal(normalizeProviderChart({ ...fixture(), navamsa: p }, true, at).navamsa, undefined);
  }
});
test('provider mapping preserves real fields and excludes missing/expired values', () => {
  const result = normalizeProviderChart(fixture(), true, at);
  assert.equal(result.lagna, 'Mithuna');
  assert.equal(result.planets.length, 1);
  assert.equal(result.planets[0].position, 12);
  assert.equal(result.currentDasha.name, 'Mercury');
  assert.equal(result.currentAntardasha.name, 'Mercury');
  assert.equal(result.dashaTimeline.length, 1);
  assert.equal(result.dashaTimeline[0].antardasha[0].name, 'Mercury');
  assert.equal(result.todayPanchang.tithi, undefined);
  assert.equal(result.contextCalculatedAt, at.toISOString());
});
test('unknown time, ambiguous periods and sandbox cannot become supported facts', () => {
  const unknown = normalizeProviderChart(fixture(), false, at);
  assert.equal(unknown.lagna, undefined);
  assert.equal(unknown.currentDasha, undefined);
  assert.equal(unknown.currentAntardasha, undefined);
  assert.equal(unknown.dashaTimeline, undefined);
  const duplicate = fixture(); duplicate.dashaPeriods.data.dasha_periods.push(p);
  assert.equal(normalizeProviderChart(duplicate, true, at).currentDasha, undefined);
  assert.throws(() => normalizeProviderChart({ ...fixture(), sandbox: true }, true, at));
  assert.throws(() => normalizeProviderChart({}, true, at));
});
