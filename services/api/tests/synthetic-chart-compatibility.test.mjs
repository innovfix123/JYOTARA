import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

// Entirely fabricated structural fixtures, not provider results or answer-quality evidence.
const fixture = JSON.parse(readFileSync(new URL('./fixtures/charts.synthetic.json', import.meta.url), 'utf8'));
const source = readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const { isValidChartFacts, buildEvidencePacket } = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const asModule = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const compile = file => ts.transpileModule(readFileSync(new URL(file, import.meta.url), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 },
}).outputText;
const rulesUrl = asModule(compile('../lib/career-rules.ts'));
const contractUrl = asModule(compile('../lib/career-answer-contract.ts').replaceAll('./career-rules', rulesUrl));
const { reviewedCareerResponse } = await import(asModule(compile('../lib/career-response.ts')
  .replaceAll('./astrology-evidence', asModule(js))
  .replaceAll('./career-rules', rulesUrl)
  .replaceAll('./career-answer-contract', contractUrl)));

test('all three fabricated chart fixtures pass the structural boundary', () => {
  assert.equal(fixture.profiles.length, 3);
  for (const [index, profile] of fixture.profiles.entries()) {
    assert.ok(profile.facts?.planets?.length > 0, `fixture ${index + 1} must contain planets`);
    assert.equal(isValidChartFacts(profile.facts), true, `fixture ${index + 1} rejected`);
  }
});

test('synthetic undated context is not relabelled current by new evidence code', () => {
  for (const profile of fixture.profiles) {
    const packet = buildEvidencePacket({
      category: 'Daily', question: 'What is today’s guidance?', language: 'en',
      birthTimeKnown: true, chart: profile.facts, now: new Date('2026-09-06T12:00:00Z'),
    });
    assert.equal(packet.facts.some(f => f.source === 'panchang' || f.source === 'current-planet-position'), false);
  }
});

test('synthetic occupied-tenth charts do not receive the empty-tenth vocational reading', () => {
  for (const [index, profile] of fixture.profiles.entries()) {
    const makePacket = chart => buildEvidencePacket({
      category: 'Career', question: 'Which career direction could I explore?', language: 'en',
      birthTimeKnown: true, chart, now: new Date('2026-09-07T12:00:00Z'),
    });
    const check = packet => {
      const occupied = packet.facts.filter(f => f.field.endsWith('tenth_house_empty') && f.value === 'false');
      assert.ok(occupied.length > 0, `fixture ${index + 1}: keep the occupied-house case explicit`);
      const result = reviewedCareerResponse({
        snapshotId: `synthetic-${index + 1}`, questionId: 'offline-career-coverage', packet, style: 'english',
      });
      assert.equal(result.ok, false);
      // A support association now exists, but cannot answer occupation choice.
      assert.equal(result.reason, 'no_reviewed_question_copy');
    };
    assert.equal(profile.facts.navamsa?.length ?? 0, 0, 'synthetic records have no synthetic D9');
    const original = makePacket(profile.facts);
    assert.equal(original.missing.filter(item => item.includes('Navamsa')).length, 3);
    check(original);

    // Deliberately synthetic D9: this is NOT a provider record or a personal
    // reading. Filling every tenth-lord chain with Mercury must not bypass
    // the independently required empty natal tenth houses.
    const withSyntheticD9 = makePacket({ ...profile.facts,
      navamsa: profile.facts.planets.map(planet => ({ ...planet, rasi: 'Mithuna', position: 3, degree: 1 })),
    });
    assert.equal(withSyntheticD9.missing.filter(item => item.includes('Navamsa')).length, 0);
    check(withSyntheticD9);
  }
});

test('synthetic occupied charts receive separate support readings without inventing D9 or job predictions', () => {
  for (const [index, profile] of fixture.profiles.entries()) {
    const make = (question, chart = profile.facts, birthTimeKnown = true) => buildEvidencePacket({
      category: 'Career', question, language: 'en', chart, birthTimeKnown, now: new Date('2026-09-07T12:00:00Z'),
    });
    const evaluate = packet => reviewedCareerResponse({snapshotId: `synthetic-${index + 1}`, questionId: 'support', packet, style: 'english'});
    const packet = make('Where can I look for support in my career?');
    const result = evaluate(packet);
    assert.equal(result.ok, true);
    assert.equal(result.questionKind, 'career_support');
    assert.equal(result.evidence.length, 9);
    assert.match(result.provenance.ruleVersions[0], index === 0 ? /SUPPORT-Moon/ : /SUPPORT-Jupiter/);
    assert.match(result.answer, /If|if/);
    assert.match(result.answer, /not evidence of another person/);
    assert.equal(result.evidence.some(line => /Navamsa|Dasa/.test(line)), false);
    assert.equal(evaluate(make('When will I get hired?')).ok, false);
    assert.equal(evaluate(make('Where can I look for support in my career?', profile.facts, false)).ok, false);
    assert.equal(evaluate(make('Where can I look for support in my career?', {
      ...profile.facts, planets: profile.facts.planets.filter(p => p.name !== 'Saturn'),
    })).ok, false);
    // Additional occupant and uncertain coverage cannot be silently ignored.
    const occupiedPosition = profile.facts.planets.find(p => p.name === (index === 0 ? 'Moon' : 'Jupiter')).position;
    const mixed = {...profile.facts, planets: profile.facts.planets.map(p => p.name === 'Saturn'
      ? {...p, position: occupiedPosition, rasi: profile.facts.planets.find(p => p.position === occupiedPosition).rasi} : p)};
    assert.equal(evaluate(make('Where can I look for support in my career?', mixed)).ok, false);
  }
});

test('rejected Tamil and Tanglish support tone stays inactive while English remains available', () => {
  const questions = {english: 'Where can I look for support in my career?',
    tamil: 'என் தொழிலில் ஆதரவுக்கு யாரை அணுகலாம்?', tanglish: 'En career-la support enga paarkkalaam?'};
  for (const [index, profile] of fixture.profiles.entries()) {
    for (const style of ['english', 'tamil', 'tanglish']) {
      const packet = buildEvidencePacket({category: 'Career', question: questions[style],
        language: style === 'english' ? 'en' : 'ta', birthTimeKnown: true, chart: profile.facts});
      const result = reviewedCareerResponse({snapshotId: `synthetic-${index}`, questionId: 'support-language', packet, style});
      if (style !== 'english') {
        assert.equal(result.ok, false, 'Rejected tone must not be exposed as a reviewed reading');
        assert.equal(result.reason, 'no_reviewed_applicable_rule');
        continue;
      }
      assert.equal(result.ok, true, `${index}/${style}: ${result.reason}`);
      assert.equal(result.evidence.length, 9);
      assert.equal(result.questionKind, 'career_support');
      assert.ok(result.provenance.ruleVersions[0].endsWith(`${style}@1`));
      assert.doesNotMatch(result.answer, /[\u0B80-\u0BFF]/);
      const missing = {...packet, facts: packet.facts.filter(f => f.field !== 'career_natal_occupancy_coverage')};
      assert.equal(reviewedCareerResponse({snapshotId: 'x', questionId: 'x', packet: missing, style}).ok, false);
    }
  }
});
