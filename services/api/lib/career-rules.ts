/** Curated source candidates, not model-generated predictions. Rules remain
 * disabled until interpretation, source rights and language review are recorded.
 * No API response or client body may change review status. */
export type CareerRule = {
  id: string;
  version: number;
  status: 'candidate' | 'approved' | 'withdrawn';
  source: { title: string; locator: string; url: string; transcriptionUrl: string; verification?: string };
  prerequisites: readonly string[];
  condition: { field: string; equals: string };
  additionalConditions?: readonly { field: string; equals: string }[];
  interpretation: string;
  language: 'english' | 'tamil' | 'tanglish';
  exclusions: readonly string[];
  review: { interpretation: string | null; rights: string | null; language: string | null };
};

const legacyCandidate: CareerRule = {
  id: 'CAREER-BJ10-MERCURY-001', version: 1, status: 'candidate',
  source: {
    title: 'Brihat Jataka, N. Chidambaram Iyer translation (1885)',
    locator: 'Chapter X, printed pages 110–111 (Wellcome PDF pages 153–154), stanza 1 and note (c), stanza 2 and note (a)',
    url: 'https://wellcomecollection.org/works/afmgm695',
    transcriptionUrl: 'https://chestofbooks.com.stason.org/new-age/astrology/Brihat-Jataka/Chapter-X-On-Avocation.html',
    verification: '2026-09-07 visual scan review: Mercury writing/accounting/handicraft themes and three reference chains are present. Crucial discrepancy: stanza 1 in the 1885 scan conditions the Navamsa branch on absence of tenth-house occupants from Lagna/Moon; the linked transcription omits that condition. Current candidate lacks this prerequisite. Do not approve until occupancy coverage and edition differences are resolved. Source verification is not predictive validation.',
  },
  prerequisites: ['career_reference_origin', 'tenth_sign', 'tenth_lord', 'tenth_lord_navamsa_sign', 'tenth_lord_navamsa_lord', 'career_synthesis_review'],
  condition: { field: 'tenth_lord_navamsa_lord', equals: 'Mercury' },
  interpretation: 'This traditional configuration associates livelihood themes with writing, accounting and craft skills. It does not establish a modern job title or guarantee employment.',
  language: 'english',
  exclusions: ['Do not activate from Mercury Mahadasha alone.', 'Do not activate merely because natal Mercury is present.', 'Do not supply a job date, salary, probability or guaranteed outcome.', 'Reference origin and competing indicators require reviewed synthesis.'],
  review: { interpretation: null, rights: null, language: null },
};

const origins = ['lagna', 'moon', 'sun'] as const;
const chainFields = ['reference_sign', 'tenth_sign', 'tenth_lord', 'tenth_lord_navamsa_sign', 'tenth_lord_navamsa_lord'] as const;
const interpretations = {
  english: 'The recorded natal planets leave the tenth houses from Lagna and Moon empty. The tenth-lord Navamsa chains from Lagna, Moon and Sun all end with Mercury. Under this condition, the 1885 Brihat Jataka translation associates Mercury with writing, accounting and craft-based livelihood themes. This is a traditional interpretation, not a measured assessment of your skills.',
  tamil: 'பிறப்பு கிரக நிலைகளின்படி, லக்னத்திலிருந்தும் சந்திரனிலிருந்தும் பத்தாம் வீட்டில் கிரகம் இல்லை. லக்னம், சந்திரன், சூரியன் ஆகிய மூன்றிலிருந்தும் பத்தாம் அதிபதியின் நவாம்ச ராசி அதிபதியாக புதன் வருகிறது. இந்த நிபந்தனையில், பிருஹத் ஜாதகத்தின் 1885 மொழிபெயர்ப்பு புதனை எழுத்து, கணக்கு, கைவினை சார்ந்த வாழ்வாதாரத் துறைகளுடன் தொடர்புபடுத்துகிறது. இது பாரம்பரிய விளக்கம்; உங்கள் திறன்களை அளந்து கூறும் மதிப்பீடு அல்ல.',
  tanglish: 'Pirappu graha nilaigalinpadi, Lagnathilirundhum Chandhiranilirundhum patthaam veettil graham illai. Lagnam, Chandhiran, Sooriyan aagiya moonu starting points-layum patthaam adhipathi irukkura Navamsa raasikku Budhan adhipathiya varraar. Indha condition-la, 1885 Brihat Jataka translation Budhanai writing, accounting, kaivinai saarndha vaazhvaadhaara thuraigaloda inaikkudhu. Idhu traditional vilakkam; unga skills-ai measure panni sonna assessment illai.',
};
// A bounded first review candidate: convergence only, not a rule for choosing
// one convenient branch when the three differ. Never auto-approved by tests.
const mercuryRules: readonly CareerRule[] = [legacyCandidate,
  ...(['english', 'tamil', 'tanglish'] as const).map(language => ({
    id: `CAREER-BJ10-D9-MERCURY-CONVERGENCE-${language}`, version: 2, status: language === 'english' ? 'approved' as const : 'candidate' as const,
    source: { ...legacyCandidate.source,
      verification: '2026-09-07: visually checked 1885 scan, printed110–111/PDF153–154. Version2 requires complete nine-graha coverage and empty tenth houses from Lagna and Moon before the D9 branch. Nine-graha coverage/node exclusion is a conservative implementation guard, not an assertion that the source explicitly specifies nodes. Transcription differs from this edition; interpretation and language approvals remain outstanding.' },
    prerequisites: ['career_house_convention', 'career_natal_occupancy_coverage', 'career_lagna_tenth_house_empty', 'career_moon_tenth_house_empty', ...origins.flatMap(origin => chainFields.map(field => `career_${origin}_${field}`))],
    condition: { field: 'career_lagna_tenth_lord_navamsa_lord', equals: 'Mercury' },
    additionalConditions: [
      { field: 'career_natal_occupancy_coverage', equals: 'nine-graha-complete' },
      { field: 'career_lagna_tenth_house_empty', equals: 'true' },
      { field: 'career_moon_tenth_house_empty', equals: 'true' },
      { field: 'career_moon_tenth_lord_navamsa_lord', equals: 'Mercury' },
      { field: 'career_sun_tenth_lord_navamsa_lord', equals: 'Mercury' },
      { field: 'career_house_convention', equals: 'whole-sign; Lagna, Moon and Sun kept separate' },
    ],
    interpretation: interpretations[language], language,
    exclusions: ['Career direction themes only; no timing, promotion, offer, suitability ranking or ability claim.', 'Do not apply when one of the three chains is absent or differs.', 'Not a complete chart synthesis; other combinations remain unassessed.'],
    review: { interpretation: language === 'english' ? 'AST-REVIEW-EN-MERCURY-V2-20260907: assistant source/condition review of the 1885 edition; limited vocational themes only, not independent astrology certification.' : null,
      language: language === 'english' ? 'AST-REVIEW-EN-MERCURY-V2-20260907: assistant English wording review; no asserted skill, ranking, timing or guaranteed result.' : null,
      rights: '2026-09-07: Wellcome afmgm695 identifies the 1885 source work with Public Domain Mark. This record covers that work, not Prokerala output or third-party website material.' },
  })),
];

// Same source branch and complete-evidence guard, different source theme.
// This is not activated by Moon sign or Moon Dasa alone.
const mercuryEnglish = mercuryRules.find(rule => rule.id === 'CAREER-BJ10-D9-MERCURY-CONVERGENCE-english')!;
const moonEnglish: CareerRule = {
  ...mercuryEnglish,
  id: 'CAREER-BJ10-D9-MOON-CONVERGENCE-english', version: 1,
  source: { ...mercuryEnglish.source,
    locator: '1885 edition, Chapter X stanza1 and stanza2, printed110 (Wellcome PDF153); stanza2 note(a), printed111/PDF154',
    verification: 'Assistant visually inspected scanned pages153–154 in this thread. Moon passage includes cultivation of land and trading products of water. This bounded rule selects those vocational themes only; it does not infer gender, partner income, modern skills or outcomes.' },
  condition: {field: 'career_lagna_tenth_lord_navamsa_lord', equals: 'Moon'},
  additionalConditions: mercuryEnglish.additionalConditions!.map(condition => ({...condition, equals: condition.equals === 'Mercury' ? 'Moon' : condition.equals})),
  interpretation: 'The recorded natal planets leave the tenth houses from Lagna and Moon empty. The tenth-lord Navamsa chains from Lagna, Moon and Sun all end with the Moon. Under this condition, the 1885 Brihat Jataka translation includes cultivation of land and trade in products of water among the traditional livelihood themes. This is a limited traditional reading, not evidence of your skills or future income.',
  review: {...mercuryEnglish.review,
    interpretation: 'AST-REVIEW-EN-MOON-V1-20260907: assistant source/condition review; only the cultivation and water-product trade themes, not independent certification.',
    language: 'AST-REVIEW-EN-MOON-V1-20260907: assistant English copy review; exploratory language, no success, suitability, gender or timing claims.'},
};
// Chapter X note(c) retains all three reference origins. For these two
// source-reviewed themes, report both branches without ranking their strength.
const mixedRules: CareerRule[] = Array.from({length: 6}, (_, index) => {
  const mask = index + 1;
  const planets = origins.map((_, bit) => mask & (1 << bit) ? 'Moon' : 'Mercury');
  const referenceNames = ['Lagna', 'Moon', 'Sun'];
  const branchText = planets.map((planet, i) => `${referenceNames[i]} reference: the tenth-lord Navamsa chain ends with ${planet}`).join('; ');
  return {
    ...mercuryEnglish,
    id: `CAREER-BJ10-D9-MIXED-MERCURY-MOON-${mask}-english`, version: 1,
    condition: {field: 'career_lagna_tenth_lord_navamsa_lord', equals: planets[0]},
    additionalConditions: mercuryEnglish.additionalConditions!.map(condition => {
      const index = origins.findIndex(origin => condition.field === `career_${origin}_tenth_lord_navamsa_lord`);
      return {...condition, equals: index === -1 ? condition.equals : planets[index]};
    }),
    source: {...mercuryEnglish.source, verification: 'Assistant review: 1885 printed110 note(c) retains livelihood themes from all three origins. This bounded mixed reading juxtaposes only the source-reviewed Mercury and Moon themes; it does not select a strongest origin or rank occupations.'},
    interpretation: `The recorded natal planets leave the tenth houses from Lagna and Moon empty. ${branchText}. In the 1885 Brihat Jataka translation, Mercury contributes writing, accounting and craft themes, while Moon contributes cultivation and trade in products of water. These are separate traditional indicators, not proof of ability or a ranking of suitable careers.`,
    exclusions: ['Requires all three fully recorded branches to be Mercury or Moon, with both represented.', 'No strongest-origin choice, aptitude ranking, dates, earnings or investment recommendation.', 'Only a partial reading; other chart factors are not assessed.'],
    review: {...mercuryEnglish.review,
      interpretation: 'AST-REVIEW-EN-MIXED-MERCURY-MOON-V1-20260907: assistant review of note(c) and stanza2; report both themes, no strength synthesis or predictive validation.',
      language: 'AST-REVIEW-EN-MIXED-MERCURY-MOON-V1-20260907: assistant English review of the fixed six branch descriptions and exploratory copy.'},
  };
});
// Stanza1's occupied-house branch describes traditional livelihood-support
// associations, NOT the D9 occupation themes. Keep its question scope separate.
const supportRules: CareerRule[] = (['Moon', 'Jupiter'] as const).map(planet => ({
  ...mercuryEnglish,
  id: `CAREER-BJ10-SUPPORT-${planet}-english`, version: 1,
  source: { ...mercuryEnglish.source,
    locator: '1885 edition Chapter X, stanza1 and note(a), printed110 / Wellcome PDF153',
    verification: 'AST-REVIEW-EN-SUPPORT-V1-20260907: assistant visually checked the full scanned page. Moon is associated with mother and Jupiter with brother in the occupied-tenth livelihood passage. These are historical symbolic associations, not facts about living relatives or a job/wealth forecast. No Navamsa vocation mapping is applied.' },
  prerequisites: ['career_house_convention', 'career_natal_occupancy_coverage',
    'career_lagna_reference_sign', 'career_lagna_tenth_sign', 'career_lagna_tenth_occupants',
    'career_moon_reference_sign', 'career_moon_tenth_sign', 'career_moon_tenth_occupants'],
  condition: {field: 'career_tenth_occupants', equals: planet},
  additionalConditions: [
    {field: 'career_natal_occupancy_coverage', equals: 'nine-graha-complete'},
    {field: 'career_house_convention', equals: 'whole-sign; Lagna, Moon and Sun kept separate'},
  ],
  interpretation: planet === 'Moon'
    ? 'Your recorded chart places the Moon in a tenth house counted from Lagna or Moon, with no other planet occupying either reference tenth house. In the 1885 Brihat Jataka translation, this configuration connects livelihood support with the mother. Read this as a traditional family-support theme, not confirmation that your mother is available or will provide money.'
    : 'Your recorded chart places Jupiter in a tenth house counted from Lagna or Moon, with no other planet occupying either reference tenth house. The 1885 Brihat Jataka translation associates this configuration with livelihood support through a brother. This is a traditional association; it does not establish that you have a brother or that anyone will help financially.',
  exclusions: ['Career-support questions only, not job choice, hiring dates, income or promotion.', 'Do not infer that a relative exists, is living, willing or able to help.', 'No borrowing, investment or dependence recommendation.', 'Multiple distinct occupants require a separately reviewed synthesis.'],
  review: {...mercuryEnglish.review,
    interpretation: 'AST-REVIEW-EN-SUPPORT-V1-20260907: assistant review of stanza1 and note(a); partial symbolic support reading only, not external certification.',
    language: 'AST-REVIEW-EN-SUPPORT-V1-20260907: assistant English review; conditional relative availability, no promises, pressure or financial advice.'},
}));
const supportTranslations = {
  Moon: {
    tamil: 'உங்கள் பிறப்பு ஜாதகத்தில், லக்னம் அல்லது சந்திரனிலிருந்து கணக்கிடும் பத்தாம் வீட்டில் சந்திரன் இருக்கிறார். இந்த இரு பத்தாம் வீடுகளிலும் வேறு கிரகம் இல்லை. பிருஹத் ஜாதகத்தின் 1885 மொழிபெயர்ப்பு இந்த அமைப்பை அம்மாவின் வழியாகக் கிடைக்கும் வாழ்வாதார ஆதரவுடன் தொடர்புபடுத்துகிறது. இது ஒரு பாரம்பரியக் குறிப்பு; உங்கள் அம்மாவின் தற்போதைய சூழலையோ அவர் பண உதவி செய்வாரா என்பதையோ உறுதிப்படுத்தவில்லை.',
    tanglish: 'Unga pirappu jathagathil, Lagnam allathu Chandhiranilirundhu kanakkidum patthaam veettil Chandhiran irukkiraar. Indha rendu patthaam veedugalilum vera graham illai. Brihat Jataka-vin 1885 translation indha amaippai amma vazhiyaana vaazhvaadhaara aadharavudan inaikkiradhu. Idhu oru traditional kurippu; unga amma ippo endha soozhalil irukkaanga, pana udhavi seivaangala enbadhai urudhippaduthavillai.',
  },
  Jupiter: {
    tamil: 'உங்கள் பிறப்பு ஜாதகத்தில், லக்னம் அல்லது சந்திரனிலிருந்து கணக்கிடும் பத்தாம் வீட்டில் குரு இருக்கிறார். இந்த இரு பத்தாம் வீடுகளிலும் வேறு கிரகம் இல்லை. பிருஹத் ஜாதகத்தின் 1885 மொழிபெயர்ப்பு இந்த அமைப்பை அண்ணன் அல்லது தம்பியின் வழியாகக் கிடைக்கும் வாழ்வாதார ஆதரவுடன் தொடர்புபடுத்துகிறது. உங்களுக்குச் சகோதரர் இருக்கிறாரா, அவர் உதவுவாரா என்பதை இந்தக் குறிப்பு உறுதிப்படுத்தவில்லை.',
    tanglish: 'Unga pirappu jathagathil, Lagnam allathu Chandhiranilirundhu kanakkidum patthaam veettil Guru irukkiraar. Indha rendu patthaam veedugalilum vera graham illai. Brihat Jataka-vin 1885 translation indha amaippai annan allathu thambi vazhiyaana vaazhvaadhaara aadharavudan inaikkiradhu. Ungalukku sagodharar irukkaara, avar udhavuvaara enbadhai indha kurippu urudhippaduthavillai.',
  },
};
const translatedSupportRules: CareerRule[] = supportRules.flatMap(rule => (['tamil', 'tanglish'] as const).map(language => ({
  ...rule, id: rule.id.replace(/english$/, language), language, status: 'candidate',
  interpretation: supportTranslations[rule.condition.equals as keyof typeof supportTranslations][language],
  review: {...rule.review,
    language: null},
})));
export const careerRules: readonly CareerRule[] = [...mercuryRules, moonEnglish, ...mixedRules, ...supportRules, ...translatedSupportRules];

export function eligibleCareerRules(facts: Readonly<Record<string, string>>, registry: readonly CareerRule[] = careerRules): readonly CareerRule[] {
  return registry.filter(rule => rule.status === 'approved'
    && [rule.review.interpretation, rule.review.rights, rule.review.language]
      .every(review => typeof review === 'string' && review.trim().length > 0)
    && rule.prerequisites.every(key => typeof facts[key] === 'string' && facts[key].trim().length > 0)
    && facts[rule.condition.field] === rule.condition.equals
    && (rule.additionalConditions ?? []).every(condition => facts[condition.field] === condition.equals));
}
