export type CareerQuestionKind = 'job_offer' | 'job_change' | 'promotion' | 'internship' | 'interview' | 'job_timing' | 'career_direction' | 'career_support' | 'retirement' | 'overseas_work' | 'job_stability' | 'salary' | 'job_transfer';
export function careerQuestionKind(question: string): CareerQuestionKind {
  const value = question.normalize('NFKC').toLowerCase();
  if (/\b(?:interview|interviews)\b|நேர்முக/u.test(value)) return 'interview';
  // Distinct outcomes need their own reviewed copy; they must not fall through
  // to a vocational-theme reading simply because no timing word is present.
  if (/\bretire(?:ment|d)?\b|பணி ஓய்வு|ஓய்வுபெற|ஓய்வு பெற/u.test(value)) return 'retirement';
  if (/\btransfer\b|இடமாற்ற/u.test(value)) return 'job_transfer';
  if (/\babroad\b|\boverseas\b|வெளிநாட்/u.test(value)) return 'overseas_work';
  if (/\b(?:salary|hike|pay rise|pay raise|pay review|pay increase|pay cut|pay package)\b|சம்பள|ஊதிய/u.test(value)) return 'salary';
  if (/\b(?:stable|stability|layoff|layoffs|fired|job security)\b|வேலை.*நிலைத்த|பணி.*நீக்க/u.test(value)) return 'job_stability';
  if (/(?:offer|வேலை|பணி).*(?:accept|reject|choose|edukkala|edukala|ஏற்க|ஏற்றுக்|தேர்ந்தெடு)|(?:accept|reject|choose).*offer/iu.test(value)) return 'job_offer';
  if (/\b(?:internship|intern|apprenticeship)\b|பயிற்சிப் பணி|பயிற்சி வேலை/u.test(value)) return 'internship';
  if (/\b(?:promotion|promoted|promote)\b|பதவி உயர்வு/u.test(value)) return 'promotion';
  if (/\b(?:resign|resignation|quit|switch|change jobs|job change|change my job|maathalaama|maathalama|maathanum)\b|வேலை.*மாற்ற|பணி.*மாற்ற|தொழில்.*மாற்ற/u.test(value)) return 'job_change';
  if (/\bwhen\b(?!\s+(?:choosing|selecting|considering)\b)|\b(?:eppo|eppoo|epo|timing|date|offer|hired)\b|எப்போது|எப்போ|கிடைக்கும்/u.test(value)) return 'job_timing';
  if (/\bcareer support\b|\b(?:support|help) (?:in|for|with) (?:my |a |the )?career\b|\bcareer(?:-la| la)?.*\bsupport\b|(?:வேலை|தொழி).*ஆதரவ/u.test(value)) return 'career_support';
  return 'career_direction';
}

export type GuidanceCategory =
  | 'Daily'
  | 'Education'
  | 'Career'
  | 'Love'
  | 'Breakup'
  | 'Relationships'
  | 'Marriage'
  | 'Family'
  | 'Business'
  | 'Property'
  | 'Spiritual'
  | 'Panchang';

export type SupportLevel = 'supported' | 'partially_supported' | 'unsupported';

export type PlanetFact = {
  name: string;
  rasi: string;
  degree: number;
  /** Prokerala zodiac sign number, 1–12; not ecliptic longitude. */
  position: number;
  isRetrograde: boolean;
};

export type PeriodFact = { name: string; start: string; end: string };
export type DashaTimeline = Array<PeriodFact & { antardasha: PeriodFact[] }>;
export type DivisionalPlanetFact = Omit<PlanetFact, 'isRetrograde'>;

export type PanchangFact = {
  vaara?: string;
  tithi?: string;
  paksha?: string;
  nakshatra?: string;
  yoga?: string;
  karana?: string;
  sunrise?: string;
  sunset?: string;
};

export type ChartFacts = {
  rashi?: string;
  rashiLord?: string;
  nakshatra?: string;
  nakshatraLord?: string;
  pada?: number;
  lagna?: string;
  lagnaLord?: string;
  mangalDosha?: { hasDosha: boolean; description: string };
  yogas: Array<{ name: string; description: string }>;
  /** Provider checks, including explicit absence; headings are not yogas. */
  yogaAssessments?: Array<{name: string; description: string; group: string; present: boolean}>;
  planets: PlanetFact[];
  /** Provider D9 positions, never mixed with natal D1 planets. */
  navamsa?: DivisionalPlanetFact[];
  transits?: PlanetFact[];
  currentDasha?: PeriodFact;
  currentAntardasha?: PeriodFact;
  /** Provider intervals retained so future questions can select the new period. */
  dashaTimeline?: DashaTimeline;
  todayPanchang?: PanchangFact;
  contextCalculatedAt?: string;
};

// Same 1-based sign convention used by the South-Indian chart renderer.
const signAliases = [
  ['mesha', 'aries', 'மேஷம்'], ['vrishabha', 'vrishabham', 'taurus', 'ரிஷபம்'],
  ['mithuna', 'mithunam', 'gemini', 'மிதுனம்'], ['karka', 'karkata', 'karkataka', 'cancer', 'கடகம்'],
  ['simha', 'leo', 'சிம்மம்'], ['kanya', 'virgo', 'கன்னி'],
  ['tula', 'thula', 'libra', 'துலாம்'], ['vrischika', 'vrishchika', 'scorpio', 'விருச்சிகம்'],
  ['dhanu', 'dhanus', 'sagittarius', 'தனுசு'], ['makara', 'capricorn', 'மகரம்'],
  ['kumbha', 'aquarius', 'கும்பம்'], ['meena', 'pisces', 'மீனம்'],
];
export function chartSignNumber(value: unknown): number | undefined {
  if (typeof value !== 'string') return undefined;
  const index = signAliases.findIndex(names => names.includes(value.normalize('NFKC').trim().toLocaleLowerCase()));
  return index < 0 ? undefined : index + 1;
}

export type CareerReferenceChain = {
  origin: 'lagna' | 'moon' | 'sun';
  referenceSign: number;
  tenthSign: number;
  tenthLord: string;
  navamsaSign?: number;
  navamsaLord?: string;
};
const traditionalSignLords = ['Mars', 'Venus', 'Mercury', 'Moon', 'Sun', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'Saturn', 'Jupiter'] as const;

/** Mechanical reference chains, not an interpretation or strength ranking.
 * Whole-sign tenth counting; Brihat Jataka X.1 note(c), X.2 note(a).
 * D9 signs come exclusively from the separately normalized provider module.
 * Do not substitute the natal position, current transit or Dasa planet. */
export function buildCareerReferenceChains(chart: ChartFacts, birthTimeKnown: boolean): CareerReferenceChain[] {
  if (!birthTimeKnown || !isValidChartFacts(chart)) return [];
  const sun = chart.planets.find(p => p.name.trim().toLowerCase() === 'sun');
  const origins: Array<[CareerReferenceChain['origin'], number | undefined]> = [
    ['lagna', chartSignNumber(chart.lagna)], ['moon', chartSignNumber(chart.rashi)], ['sun', sun?.position],
  ];
  return origins.flatMap(([origin, referenceSign]) => {
    if (referenceSign === undefined) return [];
    const tenthSign = (referenceSign + 8) % 12 + 1;
    const tenthLord = traditionalSignLords[tenthSign - 1];
    const positions = chart.navamsa?.filter(p => p.name.trim().toLowerCase() === tenthLord.toLowerCase()) ?? [];
    const d9 = positions.length === 1 ? positions[0] : undefined;
    return [{ origin, referenceSign, tenthSign, tenthLord,
      ...(d9 ? { navamsaSign: d9.position, navamsaLord: traditionalSignLords[d9.position - 1] } : {}),
    }];
  });
}

/** Shape/range validation only. This does not authenticate a chart or prove
 * that its calculations belong to the user; server-owned identity is required. */
export function isValidChartFacts(value: unknown): value is ChartFacts {
  const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
  const short = (v: unknown) => typeof v === 'string' && v.trim().length > 0 && v.length <= 80 && !/[\u0000-\u001f]/.test(v);
  const optionalShort = (v: unknown) => v === undefined || short(v);
  if (!object(value)) return false;
  if (!['rashi', 'rashiLord', 'nakshatra', 'nakshatraLord', 'lagna', 'lagnaLord'].every(key => optionalShort(value[key]))) return false;
  if (value.rashi !== undefined && chartSignNumber(value.rashi) === undefined) return false;
  if (value.lagna !== undefined && chartSignNumber(value.lagna) === undefined) return false;
  if (value.pada !== undefined && (!Number.isInteger(value.pada) || Number(value.pada) < 1 || Number(value.pada) > 4)) return false;
  const planetList = (v: unknown) => {
    if (!Array.isArray(v) || v.length > 20) return false;
    const seen = new Set<string>();
    for (const p of v) {
      if (!object(p) || !short(p.name) || !short(p.rasi) || typeof p.isRetrograde !== 'boolean') return false;
      if (typeof p.degree !== 'number' || !Number.isFinite(p.degree) || p.degree < 0 || p.degree >= 30) return false;
      if (typeof p.position !== 'number' || !Number.isInteger(p.position) || p.position < 1 || p.position > 12) return false;
      if (chartSignNumber(p.rasi) !== p.position) return false;
      const key = String(p.name).normalize('NFKC').trim().toLocaleLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
    }
    return true;
  };
  if (!planetList(value.planets) || (value.transits !== undefined && !planetList(value.transits))) return false;
  // D9 has no motion flag. Reuse numeric/sign validation without persisting
  // a synthetic retrograde value as evidence.
  if (value.navamsa !== undefined && (!Array.isArray(value.navamsa) || !planetList(value.navamsa.map(p => ({ ...(object(p) ? p : {}), isRetrograde: false }))))) return false;
  const moon = (value.planets as PlanetFact[]).find(p => p.name.trim().toLocaleLowerCase() === 'moon');
  if (moon && value.rashi !== undefined && chartSignNumber(value.rashi) !== moon.position) return false;
  if (!Array.isArray(value.yogas) || value.yogas.length > 100 || value.yogas.some(y => !object(y) || !short(y.name) || typeof y.description !== 'string' || y.description.length > 8000)) return false;
  if (value.yogaAssessments !== undefined) {
    if (!Array.isArray(value.yogaAssessments) || value.yogaAssessments.length > 100) return false;
    const seen = new Set<string>();
    for (const y of value.yogaAssessments) {
      if (!object(y) || !short(y.name) || !short(y.group) || typeof y.present !== 'boolean' || typeof y.description !== 'string' || y.description.length > 8000) return false;
      const key = String(y.name).normalize('NFKC').trim().toLowerCase();
      if (seen.has(key)) return false;
      seen.add(key);
    }
    const present = value.yogaAssessments.filter(y => y.present).map(y => ({name:y.name, description:y.description}));
    if (JSON.stringify(present) !== JSON.stringify(value.yogas)) return false;
  }
  for (const key of ['currentDasha', 'currentAntardasha']) {
    const p = value[key];
    if (p !== undefined && (!object(p) || !short(p.name) || typeof p.start !== 'string' || p.start.length > 40 || typeof p.end !== 'string' || p.end.length > 40)) return false;
  }
  if (value.dashaTimeline !== undefined && !validDashaTimeline(value.dashaTimeline)) return false;
  if (value.contextCalculatedAt !== undefined && (typeof value.contextCalculatedAt !== 'string' || value.contextCalculatedAt.length > 40)) return false;
  if (value.todayPanchang !== undefined) {
    if (!object(value.todayPanchang)) return false;
    if (!['vaara', 'tithi', 'paksha', 'nakshatra', 'yoga', 'karana', 'sunrise', 'sunset'].every(key => optionalShort((value.todayPanchang as Record<string, unknown>)[key]))) return false;
  }
  if (value.mangalDosha !== undefined && (!object(value.mangalDosha) || typeof value.mangalDosha.hasDosha !== 'boolean' || typeof value.mangalDosha.description !== 'string' || value.mangalDosha.description.length > 8000)) return false;
  return true;
}

export type EvidencePacket = {
  version: 'chart_evidence_v2_tamil';
  category: GuidanceCategory;
  intent: string;
  support: SupportLevel;
  question: string;
  language: string;
  birthTimePrecision: 'exact' | 'unknown';
  facts: Array<{ field: string; label: string; value: string; displayValue?: string; source: string }>;
  matchedRules: Array<{ id: string; text: string }>;
  missing: string[];
  allowedConclusion: string;
};

const highStakesTerms = [
  'death', 'die', 'cancer', 'disease', 'pregnant', 'pregnancy', 'suicide', 'kill myself',
  'court case', 'legal outcome', 'stock', 'investment return', 'lottery', 'medicine', 'medical',
  'health', 'illness', 'fertility', 'conception', 'baby eppo', 'baby epo',
  'maranam', 'noi', 'karpam', 'tharkolai', 'mudhaleedu', 'udalnalam', 'udal nalam',
  'மரணம்', 'நோய்', 'கர்ப்பம்', 'தற்கொலை', 'முதலீடு', 'மருந்து', 'உடல்நல', 'உடல் நல',
];

function includesAny(value: string, terms: string[], wholeLatinWords = false) {
  const text = value.toLocaleLowerCase();
  return terms.some((term) => {
    if (!wholeLatinWords || !/^[a-z ]+$/.test(term)) return text.includes(term);
    // Do not classify “studies” as “die”, or “noisy” as “noi”.
    return new RegExp(`(?<![\\p{L}\\p{N}])${term}(?![\\p{L}\\p{N}])`, 'u').test(text);
  });
}

function inferIntent(category: GuidanceCategory, question: string) {
  if (includesAny(question, highStakesTerms, true)) return 'high_stakes';
  // This endpoint currently carries only one chart. Never substitute it for
  // an explicitly mentioned other person or a two-person calculation.
  const normalized = question.normalize('NFKC').toLocaleLowerCase();
  const relationshipCategory = ['Love', 'Relationships', 'Breakup', 'Marriage'].includes(category);
  const asksCompatibility = includesAny(normalized, ['compatible', 'compatibility', 'porutham', 'பொருத்தம்', 'பொருத்தமா'], true);
  // "பொருத்தமாக" also means suitable for a course or job. It does not
  // establish that the user is asking about another person's chart.
  const pluralPeople = includesAny(normalized, ['we', 'us', 'nanga', 'naanga', 'எங்களுக்கு', 'நாங்கள்', 'நாங்க'], true);
  if (((relationshipCategory || pluralPeople) && asksCompatibility) ||
      includesAny(normalized, ['rendu per', 'rendu perum', 'இருவர'], true)) return 'additional_profile_required';
  if (includesAny(normalized, [
    'my child', 'my son', 'my daughter', 'my grandchild', 'my partner', 'my wife', 'my husband',
    'my boyfriend', 'my girlfriend', 'my parents', 'my mother', 'my father', 'future partner',
    'en child', 'en paiyan', 'en ponnu', 'en partner', 'en wife', 'en husband',
    'என் குழந்தை', 'என் மகன', 'என் மகள', 'என் பேர', 'என் துணை', 'என் கணவர', 'என் மனைவி',
    'என் காதல', 'என் பெற்றோ', 'என் அம்மா', 'என் அப்பா',
  ], true)) return 'additional_profile_required';
  if (category === 'Daily') return includesAny(question, ['time', 'neram', 'hora', 'நேர', 'ஹோர']) ? 'daily_timing' : 'daily_guidance';
  if (category === 'Panchang') return 'panchang_guidance';
  if (category === 'Education') return includesAny(question, ['exam', 'study', 'course', 'college', 'படிப்பு', 'தேர்வு', 'கல்லூரி']) ? 'education_decision' : 'education_pattern';
  if (category === 'Love') return includesAny(question, ['when', 'eppo', 'epo', 'timing', 'எப்போது', 'காலம்']) ? 'love_timing' : 'love_pattern';
  if (category === 'Breakup') return includesAny(question, ['reconnect', 'return', 'come back', 'திரும்ப', 'மீண்டும்']) ? 'reconciliation' : 'breakup_clarity';
  if (category === 'Relationships') return includesAny(question, ['communicat', 'speak', 'talk', 'பேச', 'உரையாட']) ? 'relationship_communication' : 'relationship_pattern';
  if (category === 'Marriage') return includesAny(question, ['match', 'compatib', 'porutham', 'score', 'பொருத்த']) ? 'marriage_matching' : 'marriage_timing';
  if (category === 'Career') return includesAny(question, ['when', 'change', 'switch', 'job', 'வேலை', 'மாற்ற']) ? 'career_timing' : 'career_pattern';
  if (category === 'Business') return includesAny(question, ['start', 'partner', 'expand', 'தொடங்க', 'கூட்டாளர்', 'விரிவாக்க']) ? 'business_decision' : 'business_pattern';
  if (category === 'Family') return 'family_pattern';
  if (category === 'Property') return includesAny(question, ['buy', 'sell', 'move', 'வாங்க', 'விற்க', 'இடமாற்ற']) ? 'property_timing' : 'property_pattern';
  return 'spiritual_guidance';
}

function planet(chart: ChartFacts, name: string, transit = false) {
  const list = transit ? chart.transits ?? [] : chart.planets;
  return list.find((item) => item.name.toLocaleLowerCase() === name.toLocaleLowerCase());
}

function formatPlanet(item: PlanetFact | undefined, tamil: boolean) {
  return item ? `${item.rasi} ${item.degree.toFixed(2)}°${item.isRetrograde ? (tamil ? ' (வக்ரம்)' : ' (retrograde)') : ''}` : undefined;
}

// Require an explicit timezone and reject silently normalised calendar dates.
function instant(value: unknown): number | undefined {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return undefined;
  const date = value.slice(0, 10);
  const day = Date.parse(`${date}T00:00:00Z`);
  if (!Number.isFinite(day) || new Date(day).toISOString().slice(0, 10) !== date) return undefined;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

function activePeriod(period: PeriodFact | undefined, now: number) {
  const start = instant(period?.start);
  const end = instant(period?.end);
  return !!period?.name && start !== undefined && end !== undefined && start <= now && now < end;
}

/** Bounded non-overlapping intervals. Gaps remain gaps; no dates are computed. */
export function validDashaTimeline(value: unknown): value is DashaTimeline {
  const period = (p: unknown): p is PeriodFact => {
    if (!p || typeof p !== 'object' || Array.isArray(p)) return false;
    const v = p as PeriodFact;
    const start = instant(v.start), end = instant(v.end);
    return typeof v.name === 'string' && v.name.trim().length > 0 && v.name.length <= 80 && start !== undefined && end !== undefined && start < end;
  };
  const nonoverlap = (items: PeriodFact[]) => {
    const sorted = [...items].sort((a,b) => instant(a.start)! - instant(b.start)!);
    return sorted.every((p,i) => i === 0 || instant(sorted[i-1].end)! <= instant(p.start)!);
  };
  if (!Array.isArray(value) || value.length === 0 || value.length > 12 || !value.every(period) || !nonoverlap(value)) return false;
  return value.every(p => {
    const children = (p as PeriodFact & {antardasha?: unknown}).antardasha;
    return Array.isArray(children) && children.length <= 12 && children.every(period) && nonoverlap(children) &&
      children.every(c => instant(c.start)! >= instant(p.start)! && instant(c.end)! <= instant(p.end)!);
  });
}

export function selectDashaTimeline(value: unknown, now: number): Pick<ChartFacts, 'currentDasha' | 'currentAntardasha'> {
  if (!Number.isFinite(now) || !validDashaTimeline(value)) return {};
  const parent = value.find(p => activePeriod(p, now));
  if (!parent) return {};
  const child = parent.antardasha.find(p => activePeriod(p, now));
  const plain = (p: PeriodFact): PeriodFact => ({name:p.name,start:p.start,end:p.end});
  return {currentDasha:plain(parent), ...(child ? {currentAntardasha:plain(child)} : {})};
}

export function buildEvidencePacket(input: {
  category: GuidanceCategory;
  question: string;
  language: string;
  birthTimeKnown: boolean;
  chart: ChartFacts;
  /** Server clock or an explicit deterministic evaluation clock; never request body time. */
  now?: Date;
}): EvidencePacket {
  const { category, question, language, birthTimeKnown } = input;
  const now = (input.now ?? new Date()).getTime();
  const contextAt = instant(input.chart.contextCalculatedAt);
  const indiaDay = (time: number) => new Date(time + 19_800_000).toISOString().slice(0, 10);
  // Tamil-first context currently uses India time. No clock windows are inferred
  // from these point-in-time positions. Authentication of this metadata remains
  // the responsibility of the forthcoming server-owned profile contract.
  const freshContext = Number.isFinite(now) && contextAt !== undefined && contextAt <= now
    && now - contextAt < 3_600_000 && indiaDay(contextAt) === indiaDay(now);
  const chart: ChartFacts = freshContext ? input.chart : { ...input.chart, transits: undefined, todayPanchang: undefined };
  const tamil = language === 'ta';
  const degreeValue = (item?: PlanetFact) => formatPlanet(item, tamil);
  const intent = inferIntent(category, question);
  const facts: EvidencePacket['facts'] = [];
  const missing: string[] = [];
  if (!freshContext && (input.chart.transits?.length || input.chart.todayPanchang)) {
    missing.push(language === 'ta'
      ? 'புதுப்பிக்கப்பட்ட கோச்சாரம் மற்றும் பஞ்சாங்கம்; பழைய அல்லது தேதியற்ற தகவல் பயன்படுத்தப்படவில்லை'
      : 'fresh transit and Panchangam context; stale, future or undated context was excluded');
  }
  const matchedRules: EvidencePacket['matchedRules'] = [];
  const text = (english: string, tamilCopy: string) => tamil ? tamilCopy : english;
  const add = (field: string, label: string, value: string | number | boolean | undefined, source: string) => {
    if (value === undefined || value === '') return;
    const canonical = String(value);
    // Preserve rule-matching values. Display terminology must not be invented
    // by a model or replace the server's canonical evidence.
    let displayValue: string | undefined;
    if (tamil && (['moon_sign', 'lagna'].includes(field) || /^career_.*_sign$/.test(field))) {
      const sign = chartSignNumber(canonical);
      if (sign !== undefined) displayValue = signAliases[sign - 1].at(-1);
    }
    if (tamil && (['mahadasha', 'antardasha'].includes(field) || /^career_.*_(?:lord|occupants)$/.test(field))) {
      const names: Record<string, string> = { sun: 'சூரியன்', moon: 'சந்திரன்', mars: 'செவ்வாய்', mercury: 'புதன்', jupiter: 'குரு', venus: 'சுக்கிரன்', saturn: 'சனி', rahu: 'ராகு', ketu: 'கேது' };
      displayValue = canonical === 'none' ? 'கிரகம் இல்லை' : canonical.split(', ').map(name => names[name.trim().toLowerCase()] ?? name).join(', ');
    }
    if (tamil && field === 'career_natal_occupancy_coverage' && canonical === 'nine-graha-complete') displayValue = 'ஒன்பது கிரகங்களின் நிலைகளும் உள்ளன';
    if (tamil && field === 'career_house_convention') displayValue = 'முழு ராசி வீடுகள்; லக்னம், சந்திரன், சூரியன் தனித்தனியாக';
    if (tamil && /^(?:natal|transit)_/.test(field)) {
      const match = canonical.match(/^(.+?) (\d+(?:\.\d+)?°.*)$/u);
      const sign = match ? chartSignNumber(match[1]) : undefined;
      if (match && sign !== undefined) displayValue = `${signAliases[sign - 1].at(-1)} ${match[2]}`;
    }
    facts.push({ field, label, value: canonical, ...(displayValue ? { displayValue } : {}), source });
  };
  const addPeriodFacts = () => {
    // Defense in depth: API callers can bypass the Flutter normalizer.
    // An unknown birth time must never leak period claims into model context.
    if (!birthTimeKnown) return;
    const periods = chart.dashaTimeline === undefined ? chart : selectDashaTimeline(chart.dashaTimeline, now);
    const md = periods.currentDasha;
    const ad = periods.currentAntardasha;
    if (!activePeriod(md, now)) {
      missing.push(text('a validated Mahadasha interval containing the current time', 'நடப்பு நேரத்தை உள்ளடக்கிய சரிபார்க்கப்பட்ட மகாதசா காலம்'));
      return;
    }
    add('mahadasha', text('Current Mahadasha', 'நடப்பு மகாதசா'), md?.name, 'dasha-periods');
    if (activePeriod(ad, now) && instant(ad?.start)! >= instant(md?.start)! && instant(ad?.end)! <= instant(md?.end)!) {
      add('antardasha', text('Current Antardasha', 'நடப்பு அந்தர்தசா'), ad?.name, 'dasha-periods');
    } else {
      missing.push(text('a validated Antardasha interval within the current Mahadasha', 'நடப்பு மகாதசாவிற்குள் சரிபார்க்கப்பட்ட அந்தர்தசா காலம்'));
    }
  };

  add('moon_sign', text('Moon sign', 'சந்திர ராசி'), chart.rashi, 'kundli');
  add('nakshatra', text('Nakshatra', 'நட்சத்திரம்'), chart.nakshatra ? `${chart.nakshatra}${chart.pada ? ` · ${text('Pada', 'பாதம்')} ${chart.pada}` : ''}` : undefined, 'kundli');

  if (birthTimeKnown) add('lagna', text('Lagna', 'லக்னம்'), chart.lagna, 'planet-position');
  else missing.push(text('exact birth time for Lagna, houses, Dasa and narrow timing', 'லக்னம், வீடுகள், தசை மற்றும் நுணுக்கமான காலக் கணிப்பிற்கு சரியான பிறந்த நேரம்'));

  if (intent === 'high_stakes') {
    return {
      version: 'chart_evidence_v2_tamil', category, intent, support: 'unsupported', question, language,
      birthTimePrecision: birthTimeKnown ? 'exact' : 'unknown', facts: [], matchedRules: [],
      missing: [text('qualified professional support for this high-stakes topic', 'இந்த முக்கிய விஷயத்திற்கு தகுதியான நிபுணர் உதவி')],
      allowedConclusion: 'Do not predict an outcome. Encourage appropriate professional or emergency support.',
    };
  }

  if (intent === 'additional_profile_required') {
    return {
      version: 'chart_evidence_v2_tamil', category, intent, support: 'unsupported', question, language,
      birthTimePrecision: birthTimeKnown ? 'exact' : 'unknown', facts: [], matchedRules: [],
      missing: [text('a separately identified and appropriately consented profile for the other person', 'மற்ற நபருக்கான தனிப்பட்ட பிறப்பு விவரமும் உரிய சம்மதமும்')],
      allowedConclusion: 'Do not assign this chart to another person, infer their intentions or calculate compatibility from one chart. Explain the missing profile without predicting an outcome.',
    };
  }

  if (['daily_guidance', 'daily_timing', 'panchang_guidance'].includes(intent)) {
    const p = chart.todayPanchang;
    add('vaara', text("Today's Vaara", 'இன்றைய வாரம்'), p?.vaara, 'panchang');
    add('tithi', text("Today's Tithi", 'இன்றைய திதி'), p?.tithi ? `${p.tithi}${p.paksha ? ` · ${p.paksha}` : ''}` : undefined, 'panchang');
    add('day_nakshatra', text("Today's Nakshatra", 'இன்றைய நட்சத்திரம்'), p?.nakshatra, 'panchang');
    add('day_yoga', text("Today's Yoga", 'இன்றைய யோகம்'), p?.yoga, 'panchang');
    add('transit_moon', text('Current Moon', 'நடப்பு சந்திரன்'), degreeValue(planet(chart, 'Moon', true)), 'current-planet-position');
    matchedRules.push({ id: 'DAILY-001', text: 'Use Panchang and current Moon as reflective context; never promise a guaranteed event.' });
    if (!p) missing.push(text("today's Panchang", 'இன்றைய பஞ்சாங்கம்'));
    if (!chart.transits?.length) missing.push(text('current transit positions', 'நடப்பு கோச்சார கிரக நிலைகள்'));
    if (intent === 'daily_timing') missing.push(text('activity-specific Muhurta or Hora', 'செயலுக்கேற்ற முகூர்த்தம் அல்லது ஹோரா'));
  }

  if (['love_pattern', 'love_timing', 'breakup_clarity', 'reconciliation', 'relationship_communication', 'relationship_pattern'].includes(intent)) {
    add('natal_venus', text('Natal Venus', 'பிறப்பு சுக்கிரன்'), degreeValue(planet(chart, 'Venus')), 'planet-position');
    add('natal_mercury', text('Natal Mercury', 'பிறப்பு புதன்'), degreeValue(planet(chart, 'Mercury')), 'planet-position');
    addPeriodFacts();
    add('transit_venus', text('Current Venus', 'நடப்பு சுக்கிரன்'), degreeValue(planet(chart, 'Venus', true)), 'current-planet-position');
    matchedRules.push({ id: 'RELATIONSHIP-001', text: "Combine multiple indicators; never promise another person's actions or return." });
    if (['love_timing', 'reconciliation'].includes(intent)) missing.push(text('documented 5th- and 7th-house activation rules', '5 மற்றும் 7ஆம் வீட்டு செயல்பாட்டு விதிகள்'));
  }

  if (['marriage_timing', 'marriage_matching'].includes(intent)) {
    add('mangal_dosha', text('Mangal Dosha', 'செவ்வாய் தோஷம்'), chart.mangalDosha ? (chart.mangalDosha.hasDosha ? text('Detected', 'கண்டறியப்பட்டது') : text('Not detected', 'கண்டறியப்படவில்லை')) : undefined, 'kundli');
    add('natal_venus', text('Natal Venus', 'பிறப்பு சுக்கிரன்'), degreeValue(planet(chart, 'Venus')), 'planet-position');
    addPeriodFacts();
    matchedRules.push({ id: 'MARRIAGE-001', text: 'One indicator or one chart cannot decide marriage suitability.' });
    if (intent === 'marriage_matching') missing.push(text("second person's consented birth profile and Tamil Porutham calculation", 'மற்ற நபரின் சம்மதத்துடன் பெறப்பட்ட பிறப்பு விவரம் மற்றும் தமிழ் பொருத்தக் கணக்கீடு'));
    else missing.push(text('documented 7th-house and Navamsa synthesis rules', '7ஆம் வீடு மற்றும் நவாம்ச ஒருங்கிணைப்பு விதிகள்'));
  }

  if (['education_pattern', 'education_decision', 'career_pattern', 'career_timing', 'business_pattern', 'business_decision'].includes(intent)) {
    addPeriodFacts();
    add('natal_mercury', text('Natal Mercury', 'பிறப்பு புதன்'), degreeValue(planet(chart, 'Mercury')), 'planet-position');
    add('natal_jupiter', text('Natal Jupiter', 'பிறப்பு குரு'), degreeValue(planet(chart, 'Jupiter')), 'planet-position');
    add('natal_saturn', text('Natal Saturn', 'பிறப்பு சனி'), degreeValue(planet(chart, 'Saturn')), 'planet-position');
    add('transit_jupiter', text('Current Jupiter', 'நடப்பு குரு'), degreeValue(planet(chart, 'Jupiter', true)), 'current-planet-position');
    add('transit_saturn', text('Current Saturn', 'நடப்பு சனி'), degreeValue(planet(chart, 'Saturn', true)), 'current-planet-position');
    matchedRules.push({ id: 'WORK-001', text: 'Frame study, career and business guidance as patterns and decision support, never guaranteed admission, jobs or income.' });
    missing.push(text('documented education, income and career-house synthesis rules', 'கல்வி, வருமானம் மற்றும் தொழில் வீட்டு ஒருங்கிணைப்பு விதிகள்'));
    if (category === 'Career') {
      const chains = buildCareerReferenceChains(chart, birthTimeKnown);
      const requiredPlanets = ['sun', 'moon', 'mars', 'mercury', 'jupiter', 'venus', 'saturn', 'rahu', 'ketu'];
      const natalNames = new Set(chart.planets.map(p => p.name.normalize('NFKC').trim().toLowerCase()));
      const completeNatal = isValidChartFacts(chart) && requiredPlanets.every(name => natalNames.has(name));
      if (birthTimeKnown && chains.length && completeNatal) {
        add('career_natal_occupancy_coverage', text('Natal occupancy coverage', 'பிறப்பு கிரக நிலைத் தரவின் முழுமை'), 'nine-graha-complete', 'planet-position/nine-graha-coverage-v1');
        for (const chain of chains.filter(c => c.origin !== 'sun')) {
          const occupants = chart.planets.filter(p => p.position === chain.tenthSign).map(p => p.name).sort();
          const empty = occupants.length === 0;
          add(`career_${chain.origin}_tenth_house_empty`, text(`${chain.origin}: tenth house empty`, `${chain.origin === 'lagna' ? 'லக்னம்' : 'சந்திரன்'}: பத்தாம் வீட்டில் கிரகம் இல்லை`), empty ? 'true' : 'false', 'planet-position/whole-sign-occupancy-v1');
          add(`career_${chain.origin}_tenth_occupants`, text(`${chain.origin}: natal tenth-house planets`, `${chain.origin === 'lagna' ? 'லக்னம்' : 'சந்திரன்'}: பிறப்பு பத்தாம் வீட்டுக் கிரகங்கள்`), occupants.join(', ') || 'none', 'planet-position/whole-sign-occupancy-v1');
        }
        const tenthSigns = new Set(chains.filter(c => c.origin !== 'sun').map(c => c.tenthSign));
        add('career_tenth_occupants', text('Combined Lagna/Moon tenth-house planets', 'லக்னம்/சந்திரன் பத்தாம் வீட்டுக் கிரகங்கள்'),
          [...new Set(chart.planets.filter(p => tenthSigns.has(p.position)).map(p => p.name))].sort().join(', ') || 'none', 'planet-position/whole-sign-occupancy-v1');
      } else if (birthTimeKnown && chains.length) {
        missing.push(text('complete natal planet coverage for tenth-house occupancy', 'பத்தாம் வீட்டைச் சரிபார்க்க முழுமையான பிறப்பு கிரக நிலைகள்'));
      }
      const signName = (number: number) => signAliases[number - 1][0];
      for (const chain of chains) {
        const origin = chain.origin === 'lagna' ? text('Lagna', 'லக்னம்') : chain.origin === 'moon' ? text('Moon', 'சந்திரன்') : text('Sun', 'சூரியன்');
        const prefix = `career_${chain.origin}`;
        add(`${prefix}_reference_sign`, `${origin}: ${text('reference sign', 'தொடக்க ராசி')}`, signName(chain.referenceSign), 'planet-position/whole-sign-reference-v1');
        add(`${prefix}_tenth_sign`, `${origin}: ${text('tenth sign', 'பத்தாம் ராசி')}`, signName(chain.tenthSign), 'whole-sign-reference-v1');
        add(`${prefix}_tenth_lord`, `${origin}: ${text('tenth lord', 'பத்தாம் அதிபதி')}`, chain.tenthLord, 'traditional-sign-lord-table-v1');
        if (chain.navamsaSign !== undefined) {
          add(`${prefix}_tenth_lord_navamsa_sign`, `${origin}: ${text('tenth lord in Navamsa', 'பத்தாம் அதிபதியின் நவாம்ச ராசி')}`, signName(chain.navamsaSign), 'divisional-planet-position/navamsa');
          add(`${prefix}_tenth_lord_navamsa_lord`, `${origin}: ${text('Navamsa sign lord', 'நவாம்ச ராசி அதிபதி')}`, chain.navamsaLord, 'divisional-planet-position/navamsa+traditional-sign-lord-table-v1');
        } else missing.push(text(`provider Navamsa placement of the tenth lord from ${chain.origin}`, `${origin} வழியில் பத்தாம் அதிபதியின் சரிபார்க்கப்பட்ட நவாம்ச நிலை`));
      }
      if (chains.length) add('career_house_convention', text('Career house convention', 'தொழில் வீட்டு கணக்கீட்டு முறை'), 'whole-sign; Lagna, Moon and Sun kept separate', 'whole-sign-reference-v1');
      // Deliberately do not generate career_synthesis_review or a "best"
      // origin. Calculated branches cannot approve their own interpretation.
    }
  }

  if (['family_pattern', 'property_pattern', 'property_timing'].includes(intent)) {
    addPeriodFacts();
    add('natal_moon', text('Natal Moon', 'பிறப்பு சந்திரன்'), degreeValue(planet(chart, 'Moon')), 'planet-position');
    add('natal_mars', text('Natal Mars', 'பிறப்பு செவ்வாய்'), degreeValue(planet(chart, 'Mars')), 'planet-position');
    add('transit_saturn', text('Current Saturn', 'நடப்பு சனி'), degreeValue(planet(chart, 'Saturn', true)), 'current-planet-position');
    matchedRules.push({ id: 'HOME-001', text: 'Use family and property indicators only as reflective planning context; never replace legal or financial due diligence.' });
    missing.push(text('documented 2nd- and 4th-house synthesis rules', '2 மற்றும் 4ஆம் வீட்டு ஒருங்கிணைப்பு விதிகள்'));
  }

  if (intent === 'spiritual_guidance') {
    addPeriodFacts();
    add('natal_jupiter', text('Natal Jupiter', 'பிறப்பு குரு'), degreeValue(planet(chart, 'Jupiter')), 'planet-position');
    add('natal_ketu', text('Natal Ketu', 'பிறப்பு கேது'), degreeValue(planet(chart, 'Ketu')), 'planet-position');
    matchedRules.push({ id: 'SPIRITUAL-001', text: 'Offer optional reflective practices without claiming that a ritual guarantees an outcome.' });
    missing.push(text('documented 5th-, 9th- and 12th-house synthesis rules', '5, 9 மற்றும் 12ஆம் வீட்டு ஒருங்கிணைப்பு விதிகள்'));
  }

  const coreFactsPresent = Boolean(chart.rashi && chart.nakshatra);
  const support: SupportLevel = !coreFactsPresent ? 'unsupported' : missing.length ? 'partially_supported' : 'supported';
  return {
    version: 'chart_evidence_v2_tamil', category, intent, support, question, language,
    birthTimePrecision: birthTimeKnown ? 'exact' : 'unknown', facts, matchedRules, missing,
    allowedConclusion: support === 'supported'
      ? 'Give a concise personalised traditional-guidance explanation based only on these facts and rules.'
      : 'Explain the available chart pattern, name the missing inputs, and do not state an exact or guaranteed outcome.',
  };
}

const tamilFocus: Record<GuidanceCategory, string> = {
  Daily: 'இன்றைய வழிகாட்டலுக்கான தொடர்புடைய கணக்கீடுகள்',
  Education: 'உங்கள் படிப்பு கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Career: 'உங்கள் தொழில் கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Love: 'உங்கள் காதல் கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Breakup: 'உங்கள் பிரிவு கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Relationships: 'உங்கள் உறவு கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Marriage: 'உங்கள் திருமண கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Family: 'உங்கள் குடும்ப கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Business: 'உங்கள் வணிக கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Property: 'உங்கள் வீடு அல்லது இடமாற்ற கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Spiritual: 'உங்கள் ஆன்மீக கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
  Panchang: 'இன்றைய பஞ்சாங்க கேள்விக்கான தொடர்புடைய கணக்கீடுகள்',
};

const englishFocus: Record<GuidanceCategory, string> = {
  Daily: "For today's guidance, the relevant calculations are",
  Education: 'For your education question, the relevant calculations are',
  Career: 'For your career question, the relevant calculations are',
  Love: 'For your love question, the relevant calculations are',
  Breakup: 'For your breakup question, the relevant calculations are',
  Relationships: 'For your relationship question, the relevant calculations are',
  Marriage: 'For your marriage question, the relevant calculations are',
  Family: 'For your family question, the relevant calculations are',
  Business: 'For your business question, the relevant calculations are',
  Property: 'For your property or relocation question, the relevant calculations are',
  Spiritual: 'For your spiritual question, the relevant calculations are',
  Panchang: 'For your Panchang question, the relevant calculations are',
};

export function buildFallbackAnswer(packet: EvidencePacket, style?: string) {
  const copy = (en: string, ta: string, tanglish: string) => style === 'tanglish' ? tanglish : packet.language === 'ta' ? ta : en;
  if (packet.intent === 'high_stakes') {
    if (includesAny(packet.question, ['suicide', 'kill myself', 'tharkolai', 'தற்கொலை'], true)) {
      return copy(
        'Your safety matters more than a chart reading. If you might hurt yourself or are in immediate danger, contact local emergency help and someone you trust who can stay with you. Are you safe right now?',
        'ஜாதக விளக்கத்தைவிட உங்கள் பாதுகாப்பு முக்கியம். உங்களை காயப்படுத்திக்கொள்ளும் அபாயம் அல்லது உடனடி ஆபத்து இருந்தால், உள்ளூர் அவசர உதவியையும் உங்களுடன் இருக்கக்கூடிய நம்பகமான ஒருவரையும் தொடர்புகொள்ளுங்கள். இப்போது பாதுகாப்பாக இருக்கிறீர்களா?',
        'Jathaga vilakkathai vida unga paadhukaappu mukkiyam. Ungalai kaayapaduthikkollum abayam allathu udanadi aabathu irundhaal, local emergency help-aiyum unga kooda irukkakoodiya nambagamaana oruvaraiyum thodarbu kollunga. Ippo paadhukaappa irukkeengala?',
      );
    }
    if (includesAny(packet.question, ['court case', 'legal outcome'], true)) return copy(
      'A birth chart cannot establish the outcome of a legal case. A qualified lawyer can assess the documents, deadlines and options relevant to your situation.',
      'ஒரு வழக்கின் முடிவை ஜாதகத்தால் உறுதிசெய்ய முடியாது. உங்கள் ஆவணங்கள், காலக்கெடுகள் மற்றும் வாய்ப்புகளை தகுதியான வழக்கறிஞருடன் மதிப்பிடுங்கள்.',
      'Oru legal case-oda mudivai jathagathaal urudhi seyya mudiyaadhu. Unga documents, deadlines, options-ai qualified lawyer kooda review pannunga.',
    );
    if (includesAny(packet.question, ['stock', 'investment return', 'lottery', 'mudhaleedu', 'முதலீடு'], true)) return copy(
      'A birth chart cannot establish investment returns or lottery results. Base money decisions on affordability, risk and verified financial information, not an astrological prediction.',
      'முதலீட்டு லாபத்தையோ லாட்டரி முடிவையோ ஜாதகத்தால் உறுதிசெய்ய முடியாது. செலவுத்திறன், ஆபத்து மற்றும் சரிபார்க்கப்பட்ட நிதித் தகவல்களின் அடிப்படையில் முடிவெடுங்கள்.',
      'Investment profit allathu lottery result-ai jathagathaal urudhi seyya mudiyaadhu. Unga budget, risk, verified financial information-ai vechu mudivu edunga; jathaga prediction-ai vechu alla.',
    );
    return copy(
      'A birth chart cannot determine health, pregnancy or lifespan outcomes. For a personal assessment, speak with a qualified healthcare professional; do not change treatment based on astrology.',
      'உடல்நலம், கர்ப்பம் அல்லது ஆயுட்காலம் பற்றிய முடிவுகளை ஜாதகத்தால் உறுதிசெய்ய முடியாது. தனிப்பட்ட மதிப்பீட்டிற்கு தகுதியான மருத்துவரை அணுகுங்கள்; ஜாதகத்தின் அடிப்படையில் சிகிச்சையை மாற்ற வேண்டாம்.',
      'Udalnalam, pregnancy allathu aayutkaalam patriya mudivugalai jathagathaal urudhi seyya mudiyaadhu. Personal assessment-ku qualified doctor-ai anugunga; jathagathai vechu treatment-ai maatha vendaam.',
    );
  }
  if (packet.intent === 'additional_profile_required') {
    if (style === 'tanglish') return 'Inga oruvaroda jathagam mattum irukku. Adhai innoruvaroda jathagama use panna mudiyadhu. Avangalai patri thanippatta jathaga vilakkathukku, avangaloda birth details-um uriya sammadhamum thevai. Rendu peroda details irundhaalum, avanga mudivaiyo uravin vetriyaiyo urudhiya solla mudiyadhu.';
    return packet.language === 'ta'
      ? 'இங்கு ஒருவரின் ஜாதகம் மட்டுமே உள்ளது. அதை மற்றவரின் ஜாதகமாகப் பயன்படுத்த முடியாது. அவரைப் பற்றிய தனிப்பட்ட ஜாதக விளக்கத்திற்கு அவரது பிறப்பு விவரமும் உரிய சம்மதமும் தேவை. இருவரின் விவரங்கள் இருந்தாலும், அவர்களின் முடிவையோ உறவின் வெற்றியையோ உறுதியாகக் கணிக்க முடியாது.'
      : 'Only one person’s chart is available here. It cannot stand in for someone else’s chart. A personal chart reading for another person needs their own birth details and appropriate consent. Even two charts cannot establish someone’s intentions or guarantee a relationship outcome.';
  }
  if (packet.support === 'unsupported') {
    return copy('The required chart details are missing or could not be verified. Please complete or refresh your birth profile before requesting a personal reading.',
      'தேவையான ஜாதக விவரங்கள் இல்லை அல்லது சரிபார்க்கப்படவில்லை. தனிப்பட்ட விளக்கத்தைப் பெற உங்கள் பிறப்பு விவரங்களை நிறைவுசெய்யுங்கள் அல்லது புதுப்பியுங்கள்.',
      'Thevaiyaana jathaga details illai allathu verify aagala. Personal reading-ku unga birth profile-ai complete allathu refresh pannunga.');
  }
  if (packet.category === 'Career') {
    // This is a transparent limited response, NOT a reviewed chart reading.
    // Keep practical advice separate from calculations; never imply that a
    // generic next step was derived from a planet placement.
    const kind = careerQuestionKind(packet.question);
    const interview = kind === 'interview';
    const focused = kind === 'retirement' ? [
      copy('You can start preparing for retirement now; this chart does not determine when you should stop working.', 'பணி ஓய்வுக்கான தயாரிப்பை இப்போதே தொடங்கலாம்; வேலையை எப்போது நிறுத்த வேண்டும் என்பதை இந்த ஜாதகம் தீர்மானிக்காது.', 'Retirement-ku ippo preparation start pannalaam; velaiyai eppo niruthanumnu indha jathagam mudivu seyyaadhu.'),
      copy('Practical next step: list your responsibilities and the activities you want after retirement, then discuss a possible transition with your family and employer.', 'நடைமுறை அடுத்த படி: உங்கள் பொறுப்புகளையும் ஓய்வுக்குப் பின் செய்ய விரும்புவதையும் எழுதுங்கள். படிப்படியாக மாறும் வாய்ப்பைக் குடும்பத்தினருடனும் நிறுவனத்துடனும் பேசுங்கள்.', 'Practical next step: unga responsibilities, retirement-kku appuram seyya virumburadhai ezhudhunga; gradual transition pathi family-odavum employer-odavum pesunga.'),
    ] : kind === 'job_transfer' ? [
      copy('Decide on the transfer using its actual conditions; the chart does not establish whether accepting it will work out better.', 'இடமாற்றத்தின் உண்மையான நிபந்தனைகளைப் பார்த்து முடிவெடுங்கள்; அதை ஏற்பதால் சிறந்த முடிவு வரும் என்பதை ஜாதகம் உறுதிசெய்யாது.', 'Transfer-oda actual conditions-ai paarthu decide pannunga; accept panninaa better result varumnu jathagam urudhi seyyaadhu.'),
      copy('Practical next step: compare the new location, duties, travel time and family needs with your current arrangement, and clarify the transfer terms in writing.', 'நடைமுறை அடுத்த படி: புதிய பணியிடம், பொறுப்புகள், பயண நேரம், குடும்பத் தேவைகளை தற்போதைய நிலையுடன் ஒப்பிட்டு, இடமாற்ற நிபந்தனைகளை எழுத்துப்பூர்வமாகத் தெளிவுபடுத்துங்கள்.', 'Practical next step: pudhu location, responsibilities, travel time, family needs-ai current setup-oda compare panni, transfer terms-ai written-a confirm pannunga.'),
    ] : kind === 'overseas_work' ? [
      copy('An overseas job is an option to investigate, not an outcome or date established by this chart.', 'வெளிநாட்டு வேலை வாய்ப்புகளை ஆராயலாம்; அது கிடைக்கும் என்பதையோ தேதியையோ இந்த ஜாதகம் உறுதிசெய்யவில்லை.', 'Abroad job openings-ai explore pannalaam; velai kidaikkum allathu indha date-la varumnu indha jathagam urudhi seyyaadhu.'),
      copy('Practical next step: choose one advertised role and check its required skills, employer identity and work-authorisation requirements through official sources.', 'நடைமுறை அடுத்த படி: ஒரு வேலை அறிவிப்பைத் தேர்ந்தெடுத்து, தேவையான திறன்கள், நிறுவனத்தின் விவரங்கள், வேலை அனுமதிக்கான தேவைகளை அதிகாரப்பூர்வ ஆதாரங்களில் சரிபாருங்கள்.', 'Practical next step: oru job posting-ai choose panni, required skills, employer details, work permission requirements-ai official sources-la verify pannunga.'),
    ] : kind === 'salary' ? [
      copy('A salary increase and its timing depend on the employer’s decision; this chart does not establish either.', 'சம்பள உயர்வும் அதன் நேரமும் நிறுவனத்தின் முடிவைப் பொறுத்தவை; இரண்டையும் இந்த ஜாதகம் உறுதிசெய்யவில்லை.', 'Salary hike-um adhu eppo varumngaradhum company decision-ai poruthadhu; indha jathagam rendaiyum urudhi seyyaadhu.'),
      copy('Practical next step: document your recent contributions and ask your manager about the pay-review process and its stated timetable.', 'நடைமுறை அடுத்த படி: உங்கள் சமீபத்திய பங்களிப்புகளைத் தொகுத்து, சம்பள மதிப்பீட்டு நடைமுறையும் கால அட்டவணையும் பற்றி மேலாளரிடம் கேளுங்கள்.', 'Practical next step: unga recent contributions-ai list panni, salary review process-um timetable-um pathi manager-kitta kelunga.'),
    ] : kind === 'job_stability' ? [
      copy('The chart cannot confirm job security or a dismissal. Assess stability using information about your role and organisation.', 'வேலை நிலைத்திருக்கும் என்பதையோ பணி நீக்கம் ஏற்படும் என்பதையோ ஜாதகம் உறுதிசெய்யாது. உங்கள் பணி மற்றும் நிறுவனத்தின் நிலை பற்றிய தகவல்களைப் பார்த்து மதிப்பிடுங்கள்.', 'Job secure-a irukkum allathu dismissal varumnu jathagam confirm seyyaadhu. Unga role, company situation pathina information-ai vechu assess pannunga.'),
      copy('Practical next step: clarify your current priorities and feedback with your manager, and keep an up-to-date record of your skills and work.', 'நடைமுறை அடுத்த படி: தற்போதைய பணியின் முன்னுரிமைகளையும் உங்கள் செயல்பாடு பற்றிய கருத்தையும் மேலாளரிடம் தெளிவுபடுத்தி, திறன்கள் மற்றும் பணிச் சான்றுகளைப் புதுப்பித்து வைத்திருங்கள்.', 'Practical next step: current priorities, unga work feedback pathi manager-kitta clarify panni, skills-um work examples-um update panni vechukkonga.'),
    ] : undefined;
    const offerDecision = kind === 'job_offer';
    const internship = kind === 'internship';
    const changing = kind === 'job_change';
    const promotion = kind === 'promotion';
    const timing = kind === 'job_timing';
    const direct = offerDecision ? copy(
      'A chart reading alone is not a sound basis for accepting or rejecting this job offer. Compare what the role actually offers with your priorities before deciding.',
      'இந்த வேலை வாய்ப்பை ஏற்கலாமா, வேண்டாமா என்பதை ஜாதகத்தை மட்டும் வைத்து முடிவு செய்ய வேண்டாம். அந்தப் பணியின் நிபந்தனைகள் உங்கள் தேவைகளுக்குப் பொருந்துகிறதா என்பதைப் பார்த்து முடிவெடுங்கள்.',
      'Indha job offer-ai accept pannalaamaa vendaamaa nu jathagathai mattum vechu mudivu panna vendaam. Andha role-oda conditions unga needs-ku porundhudhaanu paarthu mudivu pannunga.',
    ) : internship ? copy(
      'This chart reading does not establish whether you will be selected for an internship.',
      'பயிற்சிப் பணிக்கு நீங்கள் தேர்ந்தெடுக்கப்படுவீர்களா என்பதை இந்த ஜாதக விளக்கம் உறுதிசெய்யவில்லை.',
      'Internship-ku neenga select aaveengalaa enbadhai indha jathaga vilakkam urudhi seyyala.',
    ) : interview ? copy(
      'This chart reading does not establish the result of your interview.',
      'உங்கள் நேர்முகத் தேர்வின் முடிவை இந்த ஜாதக விளக்கம் உறுதிசெய்யவில்லை.',
      'Unga interview result-ai indha jathaga vilakkam urudhi seyyala.',
    ) : promotion ? copy(
      'The available chart reading does not establish whether or when you will receive a promotion.',
      'பதவி உயர்வு கிடைக்குமா, எப்போது கிடைக்கும் என்பதை இப்போது கிடைக்கும் ஜாதக விளக்கம் உறுதிசெய்யவில்லை.',
      'Promotion kidaikkumaa, eppo kidaikkum enbadhai ippo irukkura jathaga vilakkam urudhi seyyala.',
    ) : changing ? copy(
      'The available chart reading does not establish whether this is a favourable time to change jobs.',
      'வேலை மாற்றுவதற்கு இது சாதகமான காலமா என்பதை இப்போது கிடைக்கும் ஜாதக விளக்கம் உறுதிசெய்யவில்லை.',
      'Velai maathuradhukku idhu saadhagamaana neramaa enbadhai ippo irukkura jathaga vilakkam urudhi seyyala.',
    ) : timing ? copy(
      'This chart reading does not establish when a job offer will arrive. I cannot give you a supported offer date or probability from it.',
      'வேலை வாய்ப்பு எப்போது கிடைக்கும் என்பதை இந்த ஜாதக விளக்கம் உறுதிசெய்யவில்லை. இதிலிருந்து ஆதாரமுள்ள தேதியையோ சதவீதத்தையோ கூற முடியாது.',
      'Job offer eppo varumnu indha jathaga vilakkam urudhi seyyala. Idhai vechu aadharathoda oru date allathu percentage solla mudiyadhu.',
    ) : copy(
      'The available chart reading is not sufficient to identify a suitable career or a job-offer date for you.',
      'உங்களுக்கு ஏற்ற தொழிலையோ வேலை கிடைக்கும் தேதியையோ குறிப்பிட இப்போது கிடைக்கும் ஜாதக விளக்கம் போதுமானதாக இல்லை.',
      'Ungalukku etha career allathu velai kidaikkura thedhiyai solla ippo irukkura jathaga vilakkam podhumaana alavukku illai.',
    );
    const step = offerDecision ? copy(
      'Practical next step: check the written responsibilities, pay, work location, hours and joining conditions against your priorities; clarify any missing terms with the employer.',
      'நடைமுறை அடுத்த படி: பணிப் பொறுப்புகள், சம்பளம், பணியிடம், வேலை நேரம், சேரும் நிபந்தனைகள் ஆகியவற்றை எழுத்துப்பூர்வமாகப் பார்த்து உங்கள் தேவைகளுடன் ஒப்பிடுங்கள்; தெளிவில்லாதவற்றை நிறுவனத்திடம் கேளுங்கள்.',
      'Practical next step: written responsibilities, salary, work location, timings, joining conditions-ai unga priorities-oda compare pannunga; clear-a illaadha terms-ai company-kitta kelunga.',
    ) : internship ? copy(
      'Practical next step: choose one internship opening and prepare a small work sample matching its listed requirements.',
      'நடைமுறை அடுத்த படி: ஒரு பயிற்சிப் பணி வாய்ப்பைத் தேர்ந்தெடுத்து, அதன் தேவைகளுக்குப் பொருந்தும் சிறிய செயல்முறைப் படைப்பைத் தயாரியுங்கள்.',
      'Practical next step: oru internship opening-ai choose panni, adhul ketkura skills-ku etha oru chinna work sample ready pannunga.',
    ) : interview ? copy(
      'Practical next step: rehearse a short example showing how you handled a task relevant to this role, including what you did and the result.',
      'நடைமுறை அடுத்த படி: இந்தப் பணிக்குத் தொடர்புள்ள ஒரு செயலை நீங்கள் எப்படிச் செய்தீர்கள், அதன் முடிவு என்ன என்பதைச் சுருக்கமாக விளக்கிப் பயிற்சி செய்யுங்கள்.',
      'Practical next step: indha role-ku related-a neenga senja oru task, adhul unga seyal, adhan result-ai surukkamaa solli practice pannunga.',
    ) : promotion ? copy(
      'Practical next step: list your recent measurable contributions and ask your manager which promotion criteria you still need to meet.',
      'நடைமுறை அடுத்த படி: உங்கள் சமீபத்திய சாதனைகளைத் தொகுத்து, பதவி உயர்விற்காக இன்னும் எந்தத் தகுதிகளை நிறைவேற்ற வேண்டும் என்று மேலாளரிடம் கேளுங்கள்.',
      'Practical next step: unga recent achievements-ai list panni, promotion-ku innum enna criteria meet pannanumnu manager-kitta kelunga.',
    ) : changing ? copy(
      'Practical next step: compare the new role’s responsibilities, written offer and joining conditions with your current position before resigning.',
      'நடைமுறை அடுத்த படி: விலகல் முடிவிற்கு முன் புதிய வேலையின் பொறுப்புகள், எழுத்துப்பூர்வமான பணி நியமனம் மற்றும் சேரும் நிபந்தனைகளை தற்போதைய வேலையுடன் ஒப்பிடுங்கள்.',
      'Practical next step: resign panradhukku munnaadi pudhu role-oda responsibilities, written offer, joining conditions-ai unga current velaiyoda compare pannunga.',
    ) : timing ? copy(
      'Practical next step: review your active applications and follow up on one whose stated response date has passed; otherwise choose one suitable opening to apply for.',
      'நடைமுறை அடுத்த படி: விண்ணப்பங்களின் நிலையைப் பாருங்கள். குறிப்பிட்ட பதில் தேதி கடந்திருந்தால் ஒரு நிறுவனத்திடம் நிலையை விசாரியுங்கள்; இல்லையெனில் பொருத்தமான ஒரு பணிக்கு விண்ணப்பியுங்கள்.',
      'Practical next step: unga applications status-ai paarunga. Sonna response date kadandhirundhaa oru company-kitta follow up pannunga; illainaa poruthamaana oru opening-ku apply pannunga.',
    ) : copy(
      'Practical next step: choose two roles you are considering and compare their required skills with examples of work you can already demonstrate.',
      'நடைமுறை அடுத்த படி: நீங்கள் விரும்பும் இரண்டு பணிகளைத் தேர்ந்தெடுத்து, அவற்றுக்குத் தேவையான திறன்களை உங்கள் முந்தைய பணிச் சான்றுகளுடன் ஒப்பிடுங்கள்.',
      'Practical next step: neenga yosikkura rendu roles-ai choose panni, adhukku thevaiyaana skills-ai unga work examples-oda compare pannunga.',
    );
    return [focused?.[0] ?? direct, focused?.[1] ?? step, copy(
      'This is practical guidance, not a personalised astrological conclusion. The Career interpretation still needs review; the chart facts below are context, not proof of an outcome.',
      'இது நடைமுறை வழிகாட்டல்; தனிப்பட்ட ஜோதிட முடிவு அல்ல. தொழில் பற்றிய ஜாதக விளக்கம் இன்னும் சரிபார்க்கப்பட வேண்டும். கீழுள்ள ஜாதக விவரங்கள் பின்னணித் தகவல் மட்டுமே; முடிவிற்கான ஆதாரம் அல்ல.',
      'Idhu practical guidance; personal jothida mudivu illai. Career jathaga vilakkam innum review aaganum. Keezha irukkura chart facts context mattum; oru result-ukku proof illai.',
    )].join('\n\n');
  }
  const facts = packet.facts.slice(0, 6).map((fact) => `${fact.label}: ${fact.displayValue ?? fact.value}`).join(' · ');
  if (packet.language === 'ta') {
    return `${tamilFocus[packet.category]}: ${facts}. இவை சிந்தனைக்கான பாரம்பரிய குறிப்புகள். ஆழமான பதிலுக்கு கீழே காட்டப்பட்டுள்ள கூடுதல் கணக்கீடுகள் தேவை; இதை உறுதியான கணிப்பாக எடுத்துக்கொள்ள வேண்டாம்.`;
  }
  return `${englishFocus[packet.category]}: ${facts}. Treat these as reflective traditional indicators, not a guaranteed prediction.`;
}

/** Calculation context for a conversational traditional reading. House topics
 * are interpretive conventions, not provider predictions or verified outcomes.
 * Reference: https://vedicastrology.com/articles/houses (9 Sep 2026).
 * All positions below are derived only from authenticated Prokerala positions;
 * whole-sign Lagna houses are withheld when the birth time is unknown. */
export function buildTopicContext(chart: ChartFacts, category: GuidanceCategory, known: boolean, now = Date.now()) {
  const topics: Record<GuidanceCategory, {houses:number[]; focus:string}> = {
    Love:{houses:[5,7],focus:'romance and partnership'}, Relationships:{houses:[5,7],focus:'partnership and connection'},
    Breakup:{houses:[5,7],focus:'relationship reflection; never infer another person’s return'},
    Marriage:{houses:[7,2,4],focus:'partnership, family resources and home'},
    Family:{houses:[2,4,5],focus:'family resources, home and children'},
    Career:{houses:[10,2,11],focus:'work, income and goals'}, Business:{houses:[7,10,2,11],focus:'partnership, work and resources'},
    Education:{houses:[5,9],focus:'learning, teachers and higher study'}, Property:{houses:[4,2],focus:'home and resources'},
    Spiritual:{houses:[9,12],focus:'reflection, teachers and retreat'}, Daily:{houses:[1,3],focus:'daily focus and initiative'},
    Panchang:{houses:[],focus:'current calendar details'},
  };
  const topic=topics[category];
  const meanings:Record<number,string>={1:'self and daily direction',2:'family and resources',3:'communication and initiative',4:'home and stability',5:'learning and romance',6:'service and routines',7:'partnership',8:'shared resources and change',9:'teachers and higher study',10:'work and public responsibilities',11:'goals and gains',12:'retreat and reflection'};
  const lagna=known ? chartSignNumber(chart.lagna) : undefined;
  const houseOf=(position:number) => lagna === undefined ? undefined : (position-lagna+12)%12+1;
  const houses=lagna === undefined ? [] : topic.houses.map(house=>{
    const sign=(lagna+house-2)%12+1;
    const lord=traditionalSignLords[sign-1];
    const placement=chart.planets.find(p=>p.name.toLowerCase()===lord.toLowerCase());
    return {house,topic:meanings[house],sign,lord,occupants:chart.planets.filter(p=>p.position===sign).map(p=>p.name),
      ...(placement ? {lordSign:placement.rasi,lordHouse:houseOf(placement.position),linkedTheme:meanings[houseOf(placement.position)!]} : {})};
  });
  const periods=known ? chart.dashaTimeline ? selectDashaTimeline(chart.dashaTimeline,now) : {
    ...(activePeriod(chart.currentDasha,now)?{currentDasha:chart.currentDasha}:{}),
    ...(activePeriod(chart.currentAntardasha,now)?{currentAntardasha:chart.currentAntardasha}:{}),
  } : {};
  return {basis:'Jyotara traditional interpretation of Prokerala calculations; not a Prokerala-written prediction',
    focus:topic.focus, birthTimeKnown:known, houseConvention:'whole-sign from Lagna',
    moonSign:chart.rashi, nakshatra:chart.nakshatra, ...(lagna?{lagna:chart.lagna}:{}), houses,
    planets:known?chart.planets:[], periods,
    navamsa:known && ['Love','Relationships','Marriage'].includes(category)?chart.navamsa:undefined,
    currentPanchang:['Daily','Panchang'].includes(category)?chart.todayPanchang:undefined,
    interpretationScope:'Only connect each supplied house topic with its supplied linkedTheme as a traditional area of reflection. Do not invent sign or nakshatra personality, planet-based occupations, skills, strengths or outcomes. Planet periods are calculated intervals, not evidence that a desired event will happen. A practical action comes from the user situation, not from the chart.',
    constraint:known?'Discuss themes cautiously; no strength ranking, concrete event date, success probability, diagnosis or hidden feelings follows from these calculations alone.':'Unknown birth time: Moon sign and nakshatra are based on a noon reference and may vary during the birth day; do not treat them as precise or infer personality. Do not infer Lagna, houses, divisional charts or exact timing. Ask about the user’s situation; do not ask again for a time already marked unknown.',
  };
}
