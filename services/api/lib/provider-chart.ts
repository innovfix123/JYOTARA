import { chartSignNumber, isValidChartFacts, validDashaTimeline, type ChartFacts, type PlanetFact, type PeriodFact, type DivisionalPlanetFact } from './astrology-evidence';

type Obj = Record<string, unknown>;
const object = (value: unknown): Obj => value && typeof value === 'object' && !Array.isArray(value) ? value as Obj : {};
const list = (value: unknown): Obj[] => Array.isArray(value) ? value.map(object) : [];
const name = (value: unknown): string | undefined => {
  const text = object(value).name;
  return typeof text === 'string' && text.trim() ? text : undefined;
};
const timestamp = (value: unknown) => typeof value === 'string' && /(?:Z|[+-]\d{2}:\d{2})$/.test(value) ? Date.parse(value) : NaN;

/** /kundli/advanced yoga_details[].yoga_list[]: verified against the official
 * spec and the retained paid response. Preserve false separately; never turn
 * group summaries or descriptive prose into a positive detection. */
export function normalizeProviderYogaAssessments(groups: unknown, known: boolean): ChartFacts['yogaAssessments'] {
  if (!known || !Array.isArray(groups) || groups.length > 20) return undefined;
  const result: NonNullable<ChartFacts['yogaAssessments']> = [];
  const seen = new Set<string>();
  const validName = (value: unknown): value is string => typeof value === 'string' && !!value.trim() && value.length <= 80 && !/[\u0000-\u001f]/.test(value);
  for (const group of groups) {
    const g = object(group);
    if (!validName(g.name) || !Array.isArray(g.yoga_list)) return undefined;
    for (const value of g.yoga_list) {
      const y = object(value);
      if (!validName(y.name) || typeof y.has_yoga !== 'boolean' || typeof y.description !== 'string' || y.description.length > 8000) return undefined;
      const key = y.name.normalize('NFKC').trim().toLowerCase();
      if (seen.has(key) || result.length >= 100) return undefined;
      seen.add(key);
      result.push({name:y.name.trim(), description:y.description, group:g.name.trim(), present:y.has_yoga});
    }
  }
  return result;
}

/** Official /astrology/divisional-planet-position schema, chart_type=navamsa.
 * rasi.id is ZERO based here, unlike natal planet.position. Never substitute
 * natal degree/positions if this separate module is missing or malformed.
 * Source: https://api.prokerala.com/spec/astrology.v2.yaml (2026-09-07). */
export function normalizeProviderNavamsa(payload: unknown, birthTimeKnown: boolean): DivisionalPlanetFact[] | undefined {
  if (!birthTimeKnown) return undefined;
  const raw = object(payload);
  const groups = object(raw.data).divisional_positions;
  if (raw.status !== 'ok' || !Array.isArray(groups) || groups.length !== 12) return undefined;
  const result: DivisionalPlanetFact[] = [];
  const seenSigns = new Set<number>();
  const seenPlanets = new Set<string>();
  const planetNames: Record<number, string> = { 0: 'Sun', 1: 'Moon', 2: 'Mercury', 3: 'Venus', 4: 'Mars', 5: 'Jupiter', 6: 'Saturn', 100: 'Ascendant', 101: 'Rahu', 102: 'Ketu' };
  for (const value of groups) {
    const group = object(value);
    const sign = object(group.rasi);
    if (typeof sign.id !== 'number' || !Number.isInteger(sign.id) || sign.id < 0 || sign.id > 11 || chartSignNumber(name(sign)) !== sign.id + 1 || seenSigns.has(sign.id) || !Array.isArray(group.planet_positions)) return undefined;
    seenSigns.add(sign.id);
    for (const value of group.planet_positions) {
      const entry = object(value);
      const p = object(entry.planet);
      const rasi = object(entry.rasi);
      const canonical = typeof p.id === 'number' ? planetNames[p.id] : undefined;
      if (!canonical || name(p) !== canonical || seenPlanets.has(canonical) || rasi.id !== sign.id || chartSignNumber(name(rasi)) !== sign.id + 1 || typeof entry.sign_degree !== 'number' || !Number.isFinite(entry.sign_degree) || entry.sign_degree < 0 || entry.sign_degree >= 30) return undefined;
      seenPlanets.add(canonical);
      if (p.id !== 100) result.push({ name: canonical, rasi: name(rasi)!, position: sign.id + 1, degree: entry.sign_degree });
    }
  }
  // The divisional endpoint does not provide retrograde state. D9 records
  // must not be used to infer motion; natal motion remains in chart.planets.
  return result.length === 9 ? result : undefined;
}

/** The cache retains raw time intervals; select today's active values afresh
 * for each question, even when a Panchang response was fetched earlier today. */
export function normalizeProviderContext(payload: unknown, at: Date): Pick<ChartFacts, 'transits' | 'todayPanchang' | 'contextCalculatedAt'> {
  const raw = object(payload);
  if (!Number.isFinite(at.getTime())) throw new Error('Invalid context time');
  const active = (value: unknown) => {
    const matches = list(value).filter(p => timestamp(p.start) <= at.getTime() && at.getTime() < timestamp(p.end));
    return matches.length === 1 ? matches[0] : undefined;
  };
  const positions = object(object(raw.transitPosition).data);
  const transits: PlanetFact[] = list(positions.planet_position)
    .filter(p => p.id !== 100 && name(p) && name(p.rasi) &&
      typeof p.degree === 'number' && Number.isFinite(p.degree) && p.degree >= 0 && p.degree < 30 &&
      typeof p.position === 'number' && Number.isInteger(p.position) && p.position >= 1 && p.position <= 12)
    .map(p => ({ name: name(p)!, rasi: name(p.rasi)!, degree: p.degree as number, position: p.position as number, isRetrograde: p.is_retrograde === true }));
  const panchang = object(object(raw.panchang).data);
  const context = { transits,
    ...(typeof raw.contextCalculatedAt === 'string' ? { contextCalculatedAt: raw.contextCalculatedAt } : {}),
    ...(Object.keys(panchang).length ? { todayPanchang: {
      vaara: typeof panchang.vaara === 'string' ? panchang.vaara : undefined,
      tithi: name(active(panchang.tithi)), nakshatra: name(active(panchang.nakshatra)),
      yoga: name(active(panchang.yoga)), karana: name(active(panchang.karana)),
    } } : {}),
  };
  if (!isValidChartFacts({ planets: [], yogas: [], ...context })) throw new Error('Invalid provider context');
  return context;
}

/** Only call with the response assembled by our provider adapter, never with
 * arbitrary HTTP request JSON. sandbox:false is a guard, not authentication. */
export function normalizeProviderChart(payload: unknown, birthTimeKnown: boolean, at: Date): ChartFacts {
  const raw = object(payload);
  if (raw.sandbox !== false || typeof birthTimeKnown !== 'boolean' || !Number.isFinite(at.getTime())) throw new Error('Confirmed provider calculation required');
  const data = (key: string) => object(object(raw[key]).data);
  const current = (p: Obj) => timestamp(p.start) <= at.getTime() && at.getTime() < timestamp(p.end);
  // Ambiguous overlapping periods are not resolved by choosing the first.
  const active = (value: unknown): Obj | undefined => {
    const items = list(value).filter(current);
    return items.length === 1 ? items[0] : undefined;
  };
  const period = (p: Obj | undefined): PeriodFact | undefined => p && name(p)
    ? { name: name(p)!, start: String(p.start), end: String(p.end) } : undefined;
  const planets = (key: string): PlanetFact[] => list(data(key).planet_position)
    .filter(p => p.id !== 100 && name(p) && name(p.rasi)
      && typeof p.degree === 'number' && Number.isFinite(p.degree) && p.degree >= 0 && p.degree < 30
      && typeof p.position === 'number' && Number.isInteger(p.position) && p.position >= 1 && p.position <= 12)
    .map(p => ({ name: name(p)!, rasi: name(p.rasi)!, degree: p.degree as number,
      position: p.position as number, isRetrograde: p.is_retrograde === true }));
  const kundli = data('result');
  const details = object(kundli.nakshatra_details);
  const moon = object(details.chandra_rasi);
  const star = object(details.nakshatra);
  const ascendants = list(data('planetPosition').planet_position).filter(p => p.id === 100);
  const ascendant = ascendants.length === 1 ? object(ascendants[0].rasi) : {};
  const dasha = birthTimeKnown ? active(data('dashaPeriods').dasha_periods) : undefined;
  const child = dasha ? active(dasha.antardasha) : undefined;
  const bhukti = child && dasha && timestamp(child.start) >= timestamp(dasha.start) && timestamp(child.end) <= timestamp(dasha.end) ? child : undefined;
  const timelineInput = data('dashaPeriods').dasha_periods;
  const timeline = Array.isArray(timelineInput) ? timelineInput.map(value => {
    const p = object(value);
    const rawPeriod = (v: Obj) => ({name:name(v) ?? '',start:String(v.start ?? ''),end:String(v.end ?? '')});
    return {...rawPeriod(p), antardasha: Array.isArray(p.antardasha) ? p.antardasha.map(value => rawPeriod(object(value))) : []};
  }) : undefined;
  const navamsa = normalizeProviderNavamsa(raw.navamsa, birthTimeKnown);
  const yogaAssessments = normalizeProviderYogaAssessments(kundli.yoga_details, birthTimeKnown);
  const facts: ChartFacts = {
    rashi: name(moon), rashiLord: name(moon.lord), nakshatra: name(star), nakshatraLord: name(star.lord),
    ...(typeof star.pada === 'number' && Number.isInteger(star.pada) && star.pada >= 1 && star.pada <= 4 ? { pada: star.pada } : {}),
    ...(birthTimeKnown ? { lagna: name(ascendant), lagnaLord: name(ascendant.lord) } : {}),
    planets: planets('planetPosition'),
    ...(navamsa ? { navamsa } : {}),
    ...normalizeProviderContext(raw, at),
    yogas: (yogaAssessments ?? []).filter(y => y.present).map(y => ({name:y.name, description:y.description})),
    ...(yogaAssessments ? {yogaAssessments} : {}),
    ...(period(dasha) ? { currentDasha: period(dasha) } : {}),
    ...(period(bhukti) ? { currentAntardasha: period(bhukti) } : {}),
    ...(birthTimeKnown && validDashaTimeline(timeline) ? {dashaTimeline:timeline} : {}),
  };
  if (!facts.rashi || !facts.nakshatra || !isValidChartFacts(facts)) throw new Error('Incomplete or invalid provider chart');
  return facts;
}
