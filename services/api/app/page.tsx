'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowRight, BookOpen, BriefcaseBusiness, Building2, CalendarDays, Check,
  ChevronLeft, Compass, Crown, GraduationCap, Heart, Home as HomeIcon,
  Languages, LoaderCircle, MessageCircle, MoonStar, RotateCcw, ShieldCheck,
  Sparkles, Star, Sun, ThumbsDown, ThumbsUp, Users,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

type Screen = 'splash' | 'welcome' | 'consent' | 'profile' | 'interests' | 'calculating' | 'home' | 'chart' | 'chat' | 'privacy' | 'premium';
const screens = new Set<Screen>(['splash', 'welcome', 'consent', 'profile', 'interests', 'calculating', 'home', 'chart', 'chat', 'privacy', 'premium']);
type Category = 'Daily' | 'Education' | 'Career' | 'Love' | 'Breakup' | 'Relationships' | 'Marriage' | 'Family' | 'Business' | 'Property' | 'Spiritual' | 'Panchang';
type AgeBand = '13-17' | '18-20' | '21-27' | '28-35' | '36-45' | '46-59' | '60+';
type ApiState = 'idle' | 'sandbox' | 'live' | 'unavailable';
type LocationResult = { latitude: number; longitude: number; timezone: string };
type PlanetSummary = { name: string; rasi: string; degree: number; position: number; isRetrograde: boolean };
type DashaSummary = { name: string; start: string; end: string };
type PanchangSummary = { vaara?: string; tithi?: string; paksha?: string; nakshatra?: string; yoga?: string; karana?: string; sunrise?: string; sunset?: string };
type ChartSummary = {
  rashi?: string;
  rashiLord?: string;
  sunRashi?: string;
  zodiac?: string;
  nakshatra?: string;
  nakshatraLord?: string;
  pada?: number;
  deity?: string;
  ganam?: string;
  nadi?: string;
  symbol?: string;
  animalSign?: string;
  birthStone?: string;
  bestDirection?: string;
  syllables?: string;
  mangalDosha?: { hasDosha: boolean; description: string };
  yogas: Array<{ name: string; description: string }>;
  lagna?: string;
  lagnaLord?: string;
  planets: PlanetSummary[];
  transits?: PlanetSummary[];
  todayPanchang?: PanchangSummary;
  currentDasha?: DashaSummary;
  currentAntardasha?: DashaSummary;
  dashaBalance?: string;
  moduleStatus?: Record<string, string>;
};
type GroundedAnswer = { body: string; evidence: string[]; limitation?: string };
type ApiLord = { name?: string };
type ApiRasi = { name?: string; lord?: ApiLord };
type ApiNamedPeriod = { name?: string; start?: string; end?: string };
type ApiPlanet = { id?: number; name?: string; rasi?: ApiRasi; degree?: number; position?: number; is_retrograde?: boolean };
type ApiDasha = ApiNamedPeriod & { antardasha?: ApiNamedPeriod[] };
type ApiTimedName = { name?: string; paksha?: string; start?: string; end?: string };
type KundliData = {
  nakshatra_details?: {
    chandra_rasi?: ApiRasi;
    soorya_rasi?: ApiRasi;
    zodiac?: ApiRasi;
    nakshatra?: ApiRasi & { pada?: number };
    additional_info?: { deity?: string; ganam?: string; nadi?: string; symbol?: string; animal_sign?: string; birth_stone?: string; best_direction?: string; syllables?: string };
  };
  mangal_dosha?: { has_dosha?: boolean; description?: string };
  yoga_details?: Array<{ name?: string; description?: string }>;
};
type AstrologyApiPayload = {
  sandbox?: boolean;
  result?: { data?: KundliData };
  planetPosition?: { data?: { planet_position?: ApiPlanet[] } };
  dashaPeriods?: { data?: { dasha_periods?: ApiDasha[]; dasha_balance?: { description?: string } } };
  transitPosition?: { data?: { planet_position?: ApiPlanet[] } };
  panchang?: { data?: { vaara?: string; tithi?: ApiTimedName[]; nakshatra?: ApiTimedName[]; yoga?: ApiTimedName[]; karana?: ApiTimedName[]; sunrise?: string; sunset?: string } };
  moduleStatus?: Record<string, string>;
  error?: string;
};
type GuidancePayload = { error?: string; answer?: string; evidence?: string[]; limitation?: string };

declare global {
  interface Window {
    LocationSearch?: new (
      input: HTMLInputElement,
      onSelect: (data: LocationResult) => void,
      options: { clientId: string; persistKey: string },
    ) => unknown;
  }
}

const PROKERALA_PUBLIC_CLIENT_ID = process.env.NEXT_PUBLIC_PROKERALA_CLIENT_ID ?? '';
const categories: Array<{ id: Category; title: string; subtitle: string; icon: typeof Heart }> = [
  { id: 'Daily', title: 'My day', subtitle: 'A simple daily direction', icon: CalendarDays },
  { id: 'Education', title: 'Education', subtitle: 'Study and exam direction', icon: GraduationCap },
  { id: 'Career', title: 'Career', subtitle: 'Work patterns and decisions', icon: BriefcaseBusiness },
  { id: 'Love', title: 'Love', subtitle: 'Understand emotional patterns', icon: Heart },
  { id: 'Breakup', title: 'Breakup', subtitle: 'Clarity after separation', icon: Compass },
  { id: 'Relationships', title: 'Relationships', subtitle: 'Communication and connection', icon: Users },
  { id: 'Marriage', title: 'Marriage', subtitle: 'Readiness and timing themes', icon: Star },
  { id: 'Family', title: 'Family', subtitle: 'Home and family patterns', icon: HomeIcon },
  { id: 'Business', title: 'Business', subtitle: 'Growth and decision patterns', icon: Building2 },
  { id: 'Property', title: 'Property & travel', subtitle: 'Home and relocation themes', icon: Compass },
  { id: 'Spiritual', title: 'Spirituality', subtitle: 'Reflective traditional guidance', icon: MoonStar },
  { id: 'Panchang', title: 'Panchangam', subtitle: 'Today’s traditional calendar', icon: BookOpen },
];
const tamilCategoryCopy: Record<Category, { title: string; subtitle: string }> = {
  Daily: { title: 'இன்றைய வழிகாட்டல்', subtitle: 'இன்றைய நாளுக்கான எளிய திசை' },
  Education: { title: 'கல்வி மற்றும் தேர்வு', subtitle: 'படிப்பு மற்றும் முடிவு வழிகாட்டல்' },
  Career: { title: 'தொழில்', subtitle: 'வேலை முறை மற்றும் மாற்ற முடிவுகள்' },
  Love: { title: 'காதல்', subtitle: 'உணர்ச்சி முறைகளைப் புரிந்துகொள்ளுங்கள்' },
  Breakup: { title: 'பிரிவு', subtitle: 'பிரிவுக்குப் பிறகான தெளிவு' },
  Relationships: { title: 'உறவுகள்', subtitle: 'தொடர்பு மற்றும் இணைப்பு முறைகள்' },
  Marriage: { title: 'திருமணம்', subtitle: 'திருமணத் தயார்நிலை மற்றும் காலக் குறிப்புகள்' },
  Family: { title: 'குடும்பம்', subtitle: 'வீடு மற்றும் குடும்ப உறவுகள்' },
  Business: { title: 'வணிகம்', subtitle: 'வளர்ச்சி மற்றும் முடிவு முறைகள்' },
  Property: { title: 'சொத்து மற்றும் பயணம்', subtitle: 'வீடு மற்றும் இடமாற்றக் குறிப்புகள்' },
  Spiritual: { title: 'ஆன்மீகம்', subtitle: 'பாரம்பரிய சிந்தனை வழிகாட்டல்' },
  Panchang: { title: 'பஞ்சாங்கம்', subtitle: 'இன்றைய பாரம்பரிய நாள் தகவல்' },
};

const agePriorities: Record<AgeBand, Category[]> = {
  '13-17': ['Education', 'Daily', 'Family', 'Relationships'],
  '18-20': ['Daily', 'Education', 'Career', 'Relationships'],
  '21-27': ['Love', 'Career', 'Daily', 'Marriage'],
  '28-35': ['Marriage', 'Career', 'Business', 'Love', 'Family'],
  '36-45': ['Family', 'Career', 'Business', 'Property', 'Spiritual'],
  '46-59': ['Family', 'Panchang', 'Spiritual', 'Property', 'Career'],
  '60+': ['Daily', 'Panchang', 'Spiritual', 'Family', 'Property'],
};

function getAgeBand(date: string): AgeBand | null {
  if (!date) return null;
  const born = new Date(`${date}T12:00:00`);
  if (Number.isNaN(born.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - born.getFullYear();
  const beforeBirthday = today.getMonth() < born.getMonth() || (today.getMonth() === born.getMonth() && today.getDate() < born.getDate());
  if (beforeBirthday) age -= 1;
  if (age < 13) return null;
  if (age < 18) return '13-17';
  if (age <= 20) return '18-20';
  if (age <= 27) return '21-27';
  if (age <= 35) return '28-35';
  if (age <= 45) return '36-45';
  if (age <= 59) return '46-59';
  return '60+';
}

const rasiOrder = ['Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', 'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena'];
const southIndianOrder = ['Meena', 'Mesha', 'Vrishabha', 'Mithuna', 'Kumbha', '', '', 'Karka', 'Makara', '', '', 'Simha', 'Dhanu', 'Vrischika', 'Tula', 'Kanya'];

function LocalChart({ chart, tradition, tamil }: { chart: ChartSummary; tradition: string; tamil: boolean }) {
  const planetsByRasi = new Map<string, string[]>();
  for (const planet of chart.planets) {
    const key = planet.rasi.toLocaleLowerCase();
    planetsByRasi.set(key, [...(planetsByRasi.get(key) ?? []), planet.name]);
  }
  if (chart.lagna) {
    const key = chart.lagna.toLocaleLowerCase();
    planetsByRasi.set(key, [...(planetsByRasi.get(key) ?? []), tamil ? 'லக்னம்' : 'Lagna']);
  }
  const contents = (rasi: string) => planetsByRasi.get(rasi.toLocaleLowerCase()) ?? [];

  if (tradition === 'South Indian') {
    return (
      <div className="relative mt-5 grid aspect-square w-full grid-cols-4 overflow-hidden rounded-2xl border border-border bg-background/55">
        {southIndianOrder.map((rasi, index) => (
          <div key={`${rasi || 'centre'}-${index}`} className={`min-h-20 border-b border-r border-border/70 p-2 ${rasi ? 'bg-card/35' : 'bg-primary/5'}`}>
            {rasi && <><strong className="block text-[11px] text-primary">{rasi}</strong><span className="mt-1 block text-[10px] leading-4 text-muted-foreground">{contents(rasi).join(' · ') || '—'}</span></>}
          </div>
        ))}
        <div className="pointer-events-none absolute inset-1/4 grid place-items-center text-center"><span className="text-[10px] font-semibold uppercase tracking-[.18em] text-muted-foreground">{tamil ? 'தென்னிந்திய ராசி கட்டம்' : 'South Indian Rasi chart'}</span></div>
      </div>
    );
  }

  const lagnaIndex = Math.max(0, rasiOrder.findIndex((rasi) => rasi.toLocaleLowerCase() === chart.lagna?.toLocaleLowerCase()));
  const houses = Array.from({ length: 12 }, (_, index) => ({ house: index + 1, rasi: rasiOrder[(lagnaIndex + index) % 12] }));
  return (
    <div className="mt-5 grid grid-cols-3 overflow-hidden rounded-2xl border border-border bg-background/55 sm:grid-cols-4">
      {houses.map(({ house, rasi }) => <div key={house} className="min-h-24 border-b border-r border-border/70 p-3"><span className="text-[9px] uppercase tracking-[.12em] text-muted-foreground">{tamil ? 'வீடு' : 'House'} {house}</span><strong className="mt-1 block text-xs text-primary">{rasi}</strong><span className="mt-2 block text-[10px] leading-4 text-muted-foreground">{contents(rasi).join(' · ') || '—'}</span></div>)}
    </div>
  );
}

function buildGroundedAnswer(category: Category, questionIndex: number, chart: ChartSummary, tamil: boolean): GroundedAnswer {
  const rashi = chart.rashi ?? (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const star = chart.nakshatra ?? (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const pada = chart.pada ? `${chart.pada}` : '—';
  const mangal = chart.mangalDosha ? (chart.mangalDosha.hasDosha ? (tamil ? 'கண்டறியப்பட்டது' : 'detected') : (tamil ? 'கண்டறியப்படவில்லை' : 'not detected')) : (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const yogaNames = chart.yogas.slice(0, 3).map((item) => item.name).join(', ') || (tamil ? 'யோகங்கள் கிடைக்கவில்லை' : 'no yoga groups returned');
  const lagna = chart.lagna ?? (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const dasha = chart.currentDasha?.name ?? (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const antardasha = chart.currentAntardasha?.name ?? (tamil ? 'கிடைக்கவில்லை' : 'not returned');
  const planet = (name: string) => chart.planets.find((item) => item.name.toLowerCase() === name.toLowerCase());
  const venus = planet('Venus');
  const mercury = planet('Mercury');
  const baseEvidence = tamil
    ? [`சந்திர ராசி: ${rashi}`, `நட்சத்திரம்: ${star} · பாதம் ${pada}`]
    : [`Moon sign: ${rashi}`, `Nakshatra: ${star} · Pada ${pada}`];

  const answers: Partial<Record<Category, GroundedAnswer[]>> = tamil ? {
    Daily: [
      { body: `உங்கள் சந்திர ராசி ${rashi}, நட்சத்திரம் ${star}. இது உங்கள் அடிப்படை மனநிலைச் சூழலைக் காட்டுகிறது. ஆனால் இன்று மட்டும் எதில் கவனம் செலுத்த வேண்டும் என்பதைத் துல்லியமாகச் சொல்ல தினசரி கோச்சாரம் மற்றும் பஞ்சாங்கத் தகவல் தேவை.`, evidence: baseEvidence, limitation: 'இன்றைய கோச்சாரம் இன்னும் இணைக்கப்படவில்லை.' },
      { body: `உங்கள் ஜாதக அடையாளம் ${rashi} ராசி மற்றும் ${star} நட்சத்திரமாக கணக்கிடப்பட்டுள்ளது. தற்போதைய API முடிவால் இன்று தவிர்க்க வேண்டிய ஒரு குறிப்பிட்ட செயலை உறுதியாகக் கூற முடியாது; அதற்கு இன்றைய கிரகப் பெயர்ச்சி தேவை.`, evidence: baseEvidence, limitation: 'தினசரி தவிர்ப்பு ஆலோசனைக்கு கோச்சார API தேவை.' },
      { body: `முக்கிய உரையாடலுக்கான நேரத்தை இந்த அடிப்படை ஜாதகத் தகவல்கள் மட்டும் தீர்மானிக்காது. உங்கள் ${rashi} ராசி மற்றும் ${star} நட்சத்திரம் கிடைத்துள்ளது; ஆனால் இன்று சாதகமான நேரமா என்பதைப் பார்க்க கோச்சாரம், ஹோரா மற்றும் பஞ்சாங்கம் தேவை.`, evidence: baseEvidence, limitation: 'நல்ல நேரக் கணக்கீடு இன்னும் இணைக்கப்படவில்லை.' },
    ],
    Love: [
      { body: `உங்கள் சந்திர ராசி ${rashi}, நட்சத்திரம் ${star}; சுக்கிரன் ${venus?.rasi ?? 'கிடைக்கவில்லை'} ராசியில் கணக்கிடப்பட்டுள்ளது. இது உறவு வாசிப்பிற்கான நேரடி தரவு. முழுமையான உறவு முறையை விளக்க 5ஆம் மற்றும் 7ஆம் வீட்டு விளக்க விதிகள் இன்னும் தேவை.`, evidence: [...baseEvidence, `சுக்கிரன்: ${venus?.rasi ?? 'கிடைக்கவில்லை'} ${venus ? `${venus.degree.toFixed(2)}°` : ''}`], limitation: 'வீட்டு விளக்கங்கள் இன்னும் இணைக்கப்படவில்லை.' },
      { body: `உங்கள் ${rashi} சந்திர ராசி மற்றும் ${star} நட்சத்திரத்துடன், புதன் ${mercury?.rasi ?? 'கிடைக்கவில்லை'} ராசியில் உள்ளது. அமைதியான உரையாடலுக்கு பதில் சொல்லும் முன் எதிர்பார்ப்பையும் உண்மையையும் தனித்தனியாகப் பாருங்கள்.`, evidence: [...baseEvidence, `புதன்: ${mercury?.rasi ?? 'கிடைக்கவில்லை'} ${mercury ? `${mercury.degree.toFixed(2)}°` : ''}`], limitation: 'இது கிரக நிலையை காட்டுகிறது; நிபுணர் சரிபார்த்த விளக்க விதிகள் இன்னும் தேவை.' },
      { body: `உங்கள் நடப்பு மகாதசா ${dasha}, அந்தர்தசா ${antardasha}. இவை காதல் அல்லது உறவு தொடங்கும் காலத்தை ஆய்வு செய்யும் முக்கிய தகவல்கள். ஆனால் “எப்போது காதல் வரும்?” என்று ஒரு குறிப்பிட்ட தேதி அல்லது மாதத்தை பொறுப்புடன் சொல்ல, சுக்கிரன் கோச்சாரம் மற்றும் 5ஆம்/7ஆம் வீட்டு அதிபதிகளின் சரிபார்க்கப்பட்ட விளக்கம் இன்னும் தேவை. தற்போதைய இணைக்கப்பட்ட தரவால் அந்தத் தேதியை உறுதி செய்ய முடியாது.`, evidence: [...baseEvidence, `மகாதசா: ${dasha}`, `அந்தர்தசா: ${antardasha}`, `சுக்கிரன்: ${venus?.rasi ?? 'கிடைக்கவில்லை'} ${venus ? `${venus.degree.toFixed(2)}°` : ''}`], limitation: 'கோச்சாரம் மற்றும் வீட்டு விளக்கம் இல்லாமல் காதல் தொடங்கும் தேதியை உறுதியாகக் கணிக்க முடியாது.' },
    ],
    Marriage: [
      { body: `உங்கள் தனிப்பட்ட ஜாதகத்தில் செவ்வாய் தோஷ நிலை “${mangal}” என்று API காட்டுகிறது. ஆனால் திருமணப் பொருத்தம் ஒருவரின் ஜாதகத்தால் மட்டும் முடிவாகாது; இருவரின் ஜாதகத்தையும் குணமிலான் அல்லது பொருத்தம் API மூலம் ஒப்பிட வேண்டும்.`, evidence: [...baseEvidence, `செவ்வாய் தோஷம்: ${mangal}`], limitation: 'இரண்டாவது நபரின் ஜாதகம் இல்லாமல் பொருத்த முடிவு வழங்கப்படாது.' },
      { body: `உங்கள் விவரங்கள் ஏற்கனவே ${rashi} ராசி, ${star} நட்சத்திரம், பாதம் ${pada} என்று கணக்கிடப்பட்டுள்ளன. பொருத்தத்திற்கு மற்ற நபரின் பிறந்த தேதி, சரியான நேரம் மற்றும் பிறந்த இடமும் தேவை.`, evidence: [...baseEvidence, `செவ்வாய் தோஷம்: ${mangal}`], limitation: 'இருவரின் விவரங்களும் கிடைத்த பிறகே பொருத்த API இயங்கும்.' },
      { body: `இந்த அமர்வில் பொருத்த மதிப்பெண் இன்னும் கணக்கிடப்படவில்லை. மதிப்பெண் கிடைத்ததும் மொத்த எண்ணை மட்டும் அல்லாமல் ஒவ்வொரு கூட்டு/பொருத்தக் காரணம், செவ்வாய் தோஷம் மற்றும் முக்கிய முரண்பாடுகளை தனித்தனியாகப் படிக்க வேண்டும்.`, evidence: [...baseEvidence, `தற்போதைய செவ்வாய் தோஷ நிலை: ${mangal}`], limitation: 'குணமிலான் அல்லது தமிழ் பொருத்த API இன்னும் இணைக்கப்படவில்லை.' },
    ],
    Career: [
      { body: `உங்கள் ஜாதகத்தில் லக்னம் ${lagna}, ${rashi} ராசி, ${star} நட்சத்திரம் மற்றும் ${yogaNames} என்ற யோகக் குழுக்கள் கிடைத்துள்ளன. வேலைத் திறனை முழுமையாக விளக்க 10ஆம் வீட்டு சரிபார்க்கப்பட்ட விதிகள் இன்னும் தேவை.`, evidence: [...baseEvidence, `லக்னம்: ${lagna}`, `API வழங்கிய யோகங்கள்: ${yogaNames}`], limitation: '10ஆம் வீட்டு விளக்கம் இன்னும் இணைக்கப்படவில்லை.' },
      { body: `உங்கள் நடப்பு மகாதசா ${dasha}, அந்தர்தசா ${antardasha}. இது வேலை மாற்ற நேர ஆய்விற்கான முக்கிய தரவு; ஆனால் கோச்சாரம் மற்றும் 10ஆம் வீட்டு விளக்கம் இல்லாமல் மாற்றத்தை உறுதியாக பரிந்துரைக்க முடியாது.`, evidence: [...baseEvidence, `மகாதசா: ${dasha}`, `அந்தர்தசா: ${antardasha}`], limitation: 'கோச்சாரம் இல்லாமல் வேலை மாற்றத்தை உறுதி செய்யாது.' },
      { body: `கடினமான முடிவில் உடனடி அழுத்தம், நீண்டகால வளர்ச்சி மற்றும் திரும்ப மாற்றக்கூடிய வாய்ப்பு ஆகியவற்றை தனித்தனியாகப் பாருங்கள். உங்கள் ஜாதக அடையாளம் ${rashi} / ${star}; குறிப்பிட்ட தொழில் முடிவுக்கு 10ஆம் வீடு மற்றும் தசா தரவு இன்னும் தேவை.`, evidence: baseEvidence, limitation: 'இந்தப் பதில் முடிவெடுக்கும் வழிகாட்டல்; உறுதியான தொழில் கணிப்பு அல்ல.' },
    ],
  } : {
    Daily: [
      { body: `Your Moon sign is ${rashi} and your Nakshatra is ${star}. These establish your natal emotional context, but a true today-specific focus requires the current transit and Panchang modules.`, evidence: baseEvidence, limitation: 'Today’s transit is not connected yet.' },
      { body: `Your calculated identity is ${rashi} Rashi and ${star} Nakshatra. This endpoint cannot honestly identify one specific thing to avoid today without current planetary transits.`, evidence: baseEvidence, limitation: 'Daily avoidance guidance requires the transit API.' },
      { body: `Auspicious timing for an important conversation cannot be decided from the basic natal identity alone. Your ${rashi} Rashi and ${star} Nakshatra are available; Hora, Panchang and transit data are still required.`, evidence: baseEvidence, limitation: 'Auspicious-time calculations are not connected yet.' },
    ],
    Love: [
      { body: `Your Moon sign is ${rashi}, your Nakshatra is ${star}, and Venus is calculated in ${venus?.rasi ?? 'not returned'}. These are live relationship-reading inputs. A complete pattern interpretation still needs reviewed 5th- and 7th-house rules.`, evidence: [...baseEvidence, `Venus: ${venus?.rasi ?? 'not returned'} ${venus ? `${venus.degree.toFixed(2)}°` : ''}`], limitation: 'House interpretation rules are not connected yet.' },
      { body: `Your ${rashi} Moon sign and ${star} Nakshatra are available, while Mercury is calculated in ${mercury?.rasi ?? 'not returned'}. Before responding, separate what you know from what you assume.`, evidence: [...baseEvidence, `Mercury: ${mercury?.rasi ?? 'not returned'} ${mercury ? `${mercury.degree.toFixed(2)}°` : ''}`], limitation: 'This shows the planet position; reviewed interpretation rules are still required.' },
      { body: `Your current Mahadasha is ${dasha} and Antardasha is ${antardasha}. These are important inputs for studying when love or a relationship may begin. But a responsible answer to “when will I fall in love?” also requires Venus transits and reviewed 5th- and 7th-house lord interpretation. The currently connected data cannot support an exact date or month.`, evidence: [...baseEvidence, `Mahadasha: ${dasha}`, `Antardasha: ${antardasha}`, `Venus: ${venus?.rasi ?? 'not returned'} ${venus ? `${venus.degree.toFixed(2)}°` : ''}`], limitation: 'An exact relationship date cannot be predicted without transit and house interpretation.' },
    ],
    Marriage: [
      { body: `The API reports your Mangal Dosha status as “${mangal}”. Compatibility cannot be concluded from one chart; both charts must be compared through Kundli Matching or regional Porutham.`, evidence: [...baseEvidence, `Mangal Dosha: ${mangal}`], limitation: 'No compatibility verdict is produced without the second person’s chart.' },
      { body: `Your details currently calculate to ${rashi} Rashi, ${star} Nakshatra, Pada ${pada}. Matching also needs the other person’s birth date, exact time and birthplace.`, evidence: [...baseEvidence, `Mangal Dosha: ${mangal}`], limitation: 'The matching API runs only after both profiles are supplied.' },
      { body: `No matching score has been calculated in this session. When available, read the individual Kutas or Poruthams, Mangal Dosha and major conflicts—not only the total number.`, evidence: [...baseEvidence, `Current Mangal Dosha status: ${mangal}`], limitation: 'Kundli Matching and Tamil Porutham are not connected yet.' },
    ],
    Career: [
      { body: `Your chart now returns ${lagna} Lagna, ${rashi} Rashi, ${star} Nakshatra and these Yoga groups: ${yogaNames}. A responsible work-strength interpretation still needs reviewed 10th-house rules.`, evidence: [...baseEvidence, `Lagna: ${lagna}`, `Returned Yoga groups: ${yogaNames}`], limitation: '10th-house interpretation is not connected yet.' },
      { body: `Your current Mahadasha is ${dasha} and Antardasha is ${antardasha}. These are important job-timing inputs, but transits and reviewed 10th-house rules are still required before recommending a change.`, evidence: [...baseEvidence, `Mahadasha: ${dasha}`, `Antardasha: ${antardasha}`], limitation: 'This does not guarantee a job-change outcome without transit analysis.' },
      { body: `For a difficult decision, separate immediate pressure, durable growth and reversibility. Your chart identity is ${rashi} / ${star}; a specific career judgement still requires the 10th house and Dasha data.`, evidence: baseEvidence, limitation: 'This is decision support, not a guaranteed career prediction.' },
    ],
  };

  return answers[category]?.[questionIndex] ?? answers[category]?.[0] ?? {
    body: tamil
      ? `${tamilCategoryCopy[category].title} பற்றிய உங்கள் கேள்விக்கு, கணக்கிடப்பட்ட ${rashi} ராசி, ${star} நட்சத்திரம் மற்றும் ${dasha} மகாதசாவை அடிப்படையாகக் கொண்டு வழிகாட்டல் தயாரிக்கப்படுகிறது. கிடைக்காத தகவலை ஊகித்து பதில் வழங்கப்படாது.`
      : `Guidance for ${category} will use the calculated ${rashi} Rashi, ${star} Nakshatra and ${dasha} Mahadasha without inventing missing facts.`,
    evidence: [...baseEvidence, tamil ? `நடப்பு மகாதசா: ${dasha}` : `Current Mahadasha: ${dasha}`],
    limitation: tamil ? 'இது பாரம்பரிய சிந்தனை வழிகாட்டல்; உறுதியான எதிர்காலக் கணிப்பு அல்ல.' : 'Traditional reflective guidance, not a guaranteed prediction.',
  };
}

function inferQuestionIntent(category: Category, question: string): number {
  const text = question.toLocaleLowerCase();
  const includesAny = (terms: string[]) => terms.some((term) => text.includes(term));
  if (category === 'Daily') {
    if (includesAny(['avoid', 'தவிர்', 'வேண்டாம்', 'கூடாது'])) return 1;
    if (includesAny(['good time', 'good day', 'conversation', 'meeting', 'auspicious', 'நல்ல நேர', 'நல்ல நாள', 'உரையாட', 'மீட்டிங்'])) return 2;
  }
  if (category === 'Love') {
    if (includesAny(['communicat', 'speak', 'talk', 'calm', 'message', 'பேச', 'உரையாட', 'அமைதி', 'மெசேஜ்'])) return 1;
    if (includesAny(['when', 'timing', 'reconnect', 'again', 'return', 'ex ', 'breakup', 'closure', 'eppo', 'epo', 'love var', 'kadhal var', ' காதல் எப்போது', 'எப்போது', 'காலம்', 'மீண்டும்', 'திரும்ப', 'பிரிவு', 'முன்னாள்'])) return 2;
  }
  if (category === 'Marriage') {
    if (includesAny(['detail', 'need', 'required', 'birth', 'date', 'time', 'விவர', 'தேவை', 'பிறந்த', 'நேரம்'])) return 1;
    if (includesAny(['score', 'point', 'kuta', 'porutham', 'match result', 'மதிப்பெண்', 'புள்ளி', 'பொருத்த முடிவு'])) return 2;
  }
  if (category === 'Career') {
    if (includesAny(['change', 'switch', 'new job', 'when', 'timing', 'period', 'மாற்ற', 'புதிய வேலை', 'எப்போது', 'காலம்'])) return 1;
    if (includesAny(['decision', 'choose', 'option', 'confus', 'difficult', 'முடிவு', 'தேர்வு', 'குழப்ப', 'கடின'])) return 2;
  }
  return 0;
}

export default function Home() {
  const [screen, setScreen] = useState<Screen>('splash');
  const language = 'தமிழ்';
  const [name, setName] = useState('');
  const [birthDate, setBirthDate] = useState('');
  const [birthTime, setBirthTime] = useState('');
  const [birthplace, setBirthplace] = useState('');
  const [birthLocation, setBirthLocation] = useState<LocationResult | null>(null);
  const tradition = 'South Indian';
  const [unknownTime, setUnknownTime] = useState(false);
  const [ageConfirmed, setAgeConfirmed] = useState(false);
  const [consent, setConsent] = useState(false);
  const [questionResearchConsent, setQuestionResearchConsent] = useState(false);
  const [selectedInterests, setSelectedInterests] = useState<Category[]>([]);
  const [category, setCategory] = useState<Category>('Daily');
  const [selectedQuestion, setSelectedQuestion] = useState('');
  const [questionDraft, setQuestionDraft] = useState('');
  const [asked, setAsked] = useState<string[]>([]);
  const [feedback, setFeedback] = useState<'up' | 'down' | null>(null);
  const [apiState, setApiState] = useState<ApiState>('idle');
  const [profileError, setProfileError] = useState('');
  const [sandboxModules, setSandboxModules] = useState<string[]>([]);
  const [chartSummary, setChartSummary] = useState<ChartSummary>({ yogas: [], planets: [] });
  const [liveAnswer, setLiveAnswer] = useState<GroundedAnswer | null>(null);
  const [answerState, setAnswerState] = useState<'idle' | 'loading' | 'error'>('idle');
  const locationInputRef = useRef<HTMLInputElement>(null);
  const locationWidgetReady = useRef(false);
  const screenRef = useRef<Screen>('splash');
  const profileCompletedRef = useRef(false);
  const calculationRunRef = useRef(0);
  const ageBand = getAgeBand(birthDate);
  const canContinue = Boolean(ageConfirmed && consent && birthDate && ageBand && birthplace && birthLocation && (birthTime || unknownTime));
  const canGenerate = canContinue && selectedInterests.length > 0;
  const isTamil = language === 'தமிழ்';
  const t = (english: string, tamil: string) => isTamil ? tamil : english;
  const displayName = name.trim() || t('there', 'நண்பரே');
  const questionLimit = 3;
  const remaining = Math.max(0, questionLimit - asked.length);
  const fallbackAnswer = useMemo(
    () => buildGroundedAnswer(category, inferQuestionIntent(category, selectedQuestion), chartSummary, isTamil),
    [category, selectedQuestion, chartSummary, isTamil],
  );
  const activeAnswer = liveAnswer ?? fallbackAnswer;
  const prioritisedCategories = useMemo(() => {
    const priority = ageBand ? agePriorities[ageBand] : [];
    const preferred = [...selectedInterests, ...priority];
    const rank = new Map(preferred.map((item, index) => [item, index]));
    return [...categories].sort((a, b) => (rank.get(a.id) ?? 99) - (rank.get(b.id) ?? 99));
  }, [ageBand, selectedInterests]);

  function goToScreen(next: Screen, mode: 'push' | 'replace' = 'push') {
    screenRef.current = next;
    setScreen(next);
    const baseUrl = `${window.location.pathname}${window.location.search}`;
    const url = next === 'welcome' ? baseUrl : `${baseUrl}#${next}`;
    const state = { ...window.history.state, nirayanaScreen: next };
    if (mode === 'replace') window.history.replaceState(state, '', url);
    else window.history.pushState(state, '', url);
  }

  function goBack(fallback: Screen) {
    const current = window.history.state as { nirayanaScreen?: unknown } | null;
    if (current?.nirayanaScreen === screenRef.current && window.history.length > 1) {
      window.history.back();
      return;
    }
    goToScreen(fallback, 'replace');
  }

  useEffect(() => {
    const baseUrl = `${window.location.pathname}${window.location.search}`;
    window.history.replaceState(
      { ...window.history.state, nirayanaScreen: 'splash' },
      '',
      baseUrl,
    );

    const splashTimer = window.setTimeout(() => {
      if (screenRef.current === 'splash') goToScreen('welcome', 'replace');
    }, 1600);

    const onPopState = (event: PopStateEvent) => {
      const candidate = (event.state as { nirayanaScreen?: unknown } | null)?.nirayanaScreen;
      let next: Screen = typeof candidate === 'string' && screens.has(candidate as Screen)
        ? candidate as Screen
        : 'welcome';
      if (['home', 'chart', 'chat'].includes(next) && !profileCompletedRef.current) next = 'welcome';
      if (screenRef.current === 'calculating' && next !== 'calculating') calculationRunRef.current += 1;
      screenRef.current = next;
      setScreen(next);
      if (next !== candidate) {
        const url = next === 'welcome' ? baseUrl : `${baseUrl}#${next}`;
        window.history.replaceState({ ...event.state, nirayanaScreen: next }, '', url);
      }
    };

    window.addEventListener('popstate', onPopState);
    return () => {
      window.clearTimeout(splashTimer);
      window.removeEventListener('popstate', onPopState);
    };
  }, []);

  useEffect(() => {
    screenRef.current = screen;
    window.scrollTo({ top: 0, left: 0, behavior: 'auto' });
  }, [screen]);

  useEffect(() => {
    if (screen !== 'profile') {
      locationWidgetReady.current = false;
      return;
    }
    if (!PROKERALA_PUBLIC_CLIENT_ID || !locationInputRef.current || locationWidgetReady.current) return;

    const initialise = () => {
      if (!window.LocationSearch || !locationInputRef.current || locationWidgetReady.current) return;
      locationWidgetReady.current = true;
      new window.LocationSearch(
        locationInputRef.current,
        (data) => {
          setBirthplace(locationInputRef.current?.value ?? '');
          setBirthLocation({
            latitude: Number(data.latitude),
            longitude: Number(data.longitude),
            timezone: data.timezone,
          });
        },
        { clientId: PROKERALA_PUBLIC_CLIENT_ID, persistKey: '' },
      );
    };

    const existing = document.querySelector<HTMLScriptElement>('script[data-prokerala-location]');
    if (existing) {
      if (window.LocationSearch) initialise();
      else existing.addEventListener('load', initialise, { once: true });
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://client-api.prokerala.com/static/js/location.min.js';
    script.async = true;
    script.dataset.prokeralaLocation = 'true';
    script.addEventListener('load', initialise, { once: true });
    document.head.appendChild(script);
  }, [screen]);

  function recordEvent(payload: {
    eventType: string;
    category?: Category;
    helpful?: boolean;
    language?: string;
    tradition?: string;
    inputMode?: string;
  }) {
    const acquisitionSource = new URLSearchParams(window.location.search).get('utm_source') ?? 'direct';
    void fetch('/api/pilot/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...payload, ageBand, acquisitionSource }),
    }).catch(() => undefined);
  }

  async function generateProfile() {
    if (!canGenerate || !birthLocation) return;
    const runId = calculationRunRef.current + 1;
    calculationRunRef.current = runId;
    setAsked([]);
    goToScreen('calculating');
    setApiState('idle');
    setProfileError('');
    const minimumAnimation = new Promise((resolve) => window.setTimeout(resolve, 2300));
    const calculation = fetch('/api/astrology/kundli', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        datetime: `${birthDate}T${unknownTime ? '12:00' : birthTime}:00+05:30`,
        latitude: birthLocation.latitude,
        longitude: birthLocation.longitude,
        language: 'ta',
        currentDatetime: new Date().toISOString(),
      }),
    })
      .then(async (response) => {
        const payload = await response.json() as AstrologyApiPayload;
        if (!response.ok) throw new Error(payload?.error || 'ஜாதகக் கணக்கீடு தற்காலிகமாக கிடைக்கவில்லை.');
        const modules = Object.keys(payload?.result?.data ?? {});
        setSandboxModules(modules);
        const data = payload?.result?.data ?? {};
        const details = data?.nakshatra_details;
        const mangal = data?.mangal_dosha;
        const planetItems = Array.isArray(payload?.planetPosition?.data?.planet_position) ? payload.planetPosition.data.planet_position : [];
        const ascendant = planetItems.find((item: { id?: number }) => item.id === 100);
        const dashaItems = Array.isArray(payload?.dashaPeriods?.data?.dasha_periods) ? payload.dashaPeriods.data.dasha_periods : [];
        const now = Date.now();
        const containsNow = (item: { start?: string; end?: string }) => {
          const start = item.start ? new Date(item.start).getTime() : Number.NaN;
          const end = item.end ? new Date(item.end).getTime() : Number.NaN;
          return Number.isFinite(start) && Number.isFinite(end) && start <= now && now < end;
        };
        const currentDashaRaw = dashaItems.find(containsNow);
        const currentAntardashaRaw = currentDashaRaw?.antardasha?.find(containsNow);
        const normalisePeriod = (item?: ApiNamedPeriod): DashaSummary | undefined => item?.name && item.start && item.end
          ? { name: item.name, start: item.start, end: item.end }
          : undefined;
        const transitItems = Array.isArray(payload?.transitPosition?.data?.planet_position) ? payload.transitPosition.data.planet_position : [];
        const panchang = payload?.panchang?.data;
        const currentItem = (items: unknown) => Array.isArray(items) ? (items.find(containsNow) ?? items[0]) : undefined;
        const currentTithi = currentItem(panchang?.tithi);
        const currentDayNakshatra = currentItem(panchang?.nakshatra);
        const currentYoga = currentItem(panchang?.yoga);
        const currentKarana = currentItem(panchang?.karana);
        setChartSummary({
          rashi: details?.chandra_rasi?.name,
          rashiLord: details?.chandra_rasi?.lord?.name,
          sunRashi: details?.soorya_rasi?.name,
          zodiac: details?.zodiac?.name,
          nakshatra: details?.nakshatra?.name,
          nakshatraLord: details?.nakshatra?.lord?.name,
          pada: details?.nakshatra?.pada,
          deity: details?.additional_info?.deity,
          ganam: details?.additional_info?.ganam,
          nadi: details?.additional_info?.nadi,
          symbol: details?.additional_info?.symbol,
          animalSign: details?.additional_info?.animal_sign,
          birthStone: details?.additional_info?.birth_stone,
          bestDirection: details?.additional_info?.best_direction,
          syllables: details?.additional_info?.syllables,
          mangalDosha: typeof mangal?.has_dosha === 'boolean' ? { hasDosha: mangal.has_dosha, description: mangal.description ?? '' } : undefined,
          yogas: Array.isArray(data?.yoga_details) ? data.yoga_details.map((item: { name?: string; description?: string }) => ({ name: item.name ?? 'Yoga', description: item.description ?? 'Detected in this Kundli calculation.' })) : [],
          lagna: unknownTime ? undefined : ascendant?.rasi?.name,
          lagnaLord: unknownTime ? undefined : ascendant?.rasi?.lord?.name,
          planets: planetItems.filter((item: { id?: number }) => item.id !== 100).map((item: { name?: string; rasi?: { name?: string }; degree?: number; position?: number; is_retrograde?: boolean }) => ({
            name: item.name ?? 'Planet',
            rasi: item.rasi?.name ?? 'Not returned',
            degree: Number(item.degree ?? 0),
            position: Number(item.position ?? 0),
            isRetrograde: Boolean(item.is_retrograde),
          })),
          transits: transitItems.filter((item: { id?: number }) => item.id !== 100).map((item: { name?: string; rasi?: { name?: string }; degree?: number; position?: number; is_retrograde?: boolean }) => ({
            name: item.name ?? 'Planet',
            rasi: item.rasi?.name ?? 'Not returned',
            degree: Number(item.degree ?? 0),
            position: Number(item.position ?? 0),
            isRetrograde: Boolean(item.is_retrograde),
          })),
          todayPanchang: panchang ? {
            vaara: panchang.vaara,
            tithi: currentTithi?.name,
            paksha: currentTithi?.paksha,
            nakshatra: currentDayNakshatra?.name,
            yoga: currentYoga?.name,
            karana: currentKarana?.name,
            sunrise: panchang.sunrise,
            sunset: panchang.sunset,
          } : undefined,
          currentDasha: unknownTime ? undefined : normalisePeriod(currentDashaRaw),
          currentAntardasha: unknownTime ? undefined : normalisePeriod(currentAntardashaRaw),
          dashaBalance: unknownTime ? undefined : payload?.dashaPeriods?.data?.dasha_balance?.description,
          moduleStatus: payload?.moduleStatus,
        });
        setApiState(payload?.sandbox ? 'sandbox' : 'live');
        recordEvent({ eventType: 'profile_completed', language, tradition });
        return true;
      })
      .catch((error: unknown) => {
        setApiState('unavailable');
        setProfileError(error instanceof Error ? error.message : 'ஜாதகக் கணக்கீடு தற்காலிகமாக கிடைக்கவில்லை.');
        return false;
      });
    const [, calculationSucceeded] = await Promise.all([minimumAnimation, calculation]);
    if (calculationRunRef.current !== runId || screenRef.current !== 'calculating') return;
    if (!calculationSucceeded) {
      goToScreen('interests', 'replace');
      return;
    }
    profileCompletedRef.current = true;
    goToScreen('home', 'replace');
  }
  function toggleInterest(next: Category) {
    setSelectedInterests((current) => current.includes(next)
      ? current.filter((item) => item !== next)
      : current.length < 5 ? [...current, next] : current);
  }
  function openCategory(next: Category) {
    recordEvent({ eventType: 'category_opened', category: next, language, tradition });
    setCategory(next); setSelectedQuestion(''); setQuestionDraft(''); setLiveAnswer(null); setAnswerState('idle'); setFeedback(null); goToScreen('chat');
  }
  async function askQuestion(question: string) {
    const cleaned = question.trim().replace(/\s+/g, ' ').slice(0, 240);
    if (!cleaned || asked.length >= questionLimit || answerState === 'loading') return;
    recordEvent({ eventType: 'question_asked', category, language, tradition, inputMode: /[\u0B80-\u0BFF]/.test(cleaned) ? 'tamil' : 'tanglish' });
    setSelectedQuestion(cleaned); setQuestionDraft(''); setLiveAnswer(null); setAnswerState('loading'); setFeedback(null);
    const { moduleStatus: _moduleStatus, ...guideChart } = chartSummary;
    try {
      const response = await fetch('/api/guidance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category,
          question: cleaned,
          language: 'ta',
          birthTimeKnown: !unknownTime,
          chart: guideChart,
          researchConsent: questionResearchConsent,
          ageBand,
        }),
      });
      const payload = await response.json() as GuidancePayload;
      if (!response.ok) throw new Error(payload?.error || 'Guidance unavailable');
      setLiveAnswer({ body: payload.answer ?? fallbackAnswer.body, evidence: Array.isArray(payload.evidence) ? payload.evidence : [], limitation: payload.limitation });
      setAsked((current) => [...current, cleaned]);
      setAnswerState('idle');
    } catch {
      setLiveAnswer(fallbackAnswer);
      setAsked((current) => [...current, cleaned]);
      setAnswerState('error');
    }
  }
  function answerFeedback(helpful: boolean) {
    setFeedback(helpful ? 'up' : 'down');
    recordEvent({ eventType: 'answer_feedback', category, helpful, language, tradition });
  }
  function resetPilot() {
    calculationRunRef.current += 1;
    profileCompletedRef.current = false;
    setAsked([]); setSelectedQuestion(''); setQuestionDraft(''); setLiveAnswer(null); setAnswerState('idle'); setFeedback(null);
    setName(''); setBirthDate(''); setBirthTime(''); setBirthplace(''); setBirthLocation(null); setUnknownTime(false); setAgeConfirmed(false); setConsent(false); setQuestionResearchConsent(false); setSelectedInterests([]);
    setApiState('idle'); setProfileError(''); setSandboxModules([]); setChartSummary({ yogas: [], planets: [] }); locationWidgetReady.current = false;
    goToScreen('welcome', 'replace');
  }

  async function deleteMyPilotData() {
    await fetch('/api/pilot/events', { method: 'DELETE' }).catch(() => undefined);
    resetPilot();
  }

  if (screen === 'splash') {
    return (
      <main className="grid min-h-screen place-items-center overflow-hidden bg-background px-6 text-foreground">
        <div className="text-center">
          <div className="orbit mx-auto" aria-hidden="true"><div className="orbit-ring orbit-ring-one" /><div className="orbit-ring orbit-ring-two" /><div className="orbit-core"><MoonStar /></div></div>
          <h1 className="mt-8 text-4xl font-semibold tracking-[.28em] text-primary sm:text-5xl">Jyotara</h1>
          <p className="mt-3 text-sm tracking-[.12em] text-muted-foreground">YOUR CHART. YOUR TIME.</p>
          <p className="mt-8 text-sm text-muted-foreground">தமிழ் வேத ஜோதிட வழிகாட்டல்</p>
        </div>
      </main>
    );
  }

  return (
    <main className={`min-h-screen bg-background text-foreground ${ageBand === '60+' ? 'text-[17px]' : ''}`}>
      <div className="mx-auto min-h-screen w-full max-w-[1180px] px-4 py-4 sm:px-6 lg:px-8 lg:py-8">
        <header className="flex items-center justify-between rounded-[24px] border border-white/8 bg-card/70 px-4 py-3 shadow-2xl shadow-black/10 backdrop-blur-xl sm:px-6">
          <button className="flex items-center gap-3" onClick={() => goToScreen('welcome')} aria-label="Go to Jyotara welcome screen">
            <span className="grid size-11 place-items-center rounded-2xl bg-primary text-primary-foreground shadow-lg shadow-primary/20"><MoonStar className="size-6" /></span>
            <span className="text-left"><strong className="block text-[15px] tracking-[0.2em]">Jyotara</strong><span className="text-xs text-muted-foreground">{t('Your Personal Vedic Astrology', 'உங்கள் தனிப்பட்ட வேத ஜோதிடம்')}</span></span>
          </button>
          <div className="flex items-center gap-2">
            <span className="hidden rounded-full border border-border bg-secondary px-3 py-1.5 text-xs text-secondary-foreground sm:inline-flex">{t('Free pilot', 'இலவச சோதனை')} · {remaining}/{questionLimit} {t('questions', 'கேள்விகள்')}</span>
            {screen !== 'welcome' && <Button variant="ghost" size="icon" onClick={resetPilot} aria-label="Restart pilot"><RotateCcw /></Button>}
          </div>
        </header>

        {screen === 'welcome' && (
          <section className="grid min-h-[calc(100vh-120px)] items-center gap-10 py-10 lg:grid-cols-[1.08fr_.92fr] lg:py-16">
            <div className="max-w-2xl">
              <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-primary/25 bg-primary/10 px-3 py-2 text-sm text-primary"><Sparkles className="size-4" /> பாரம்பரிய வேத ஜோதிட வழிகாட்டல்</div>
              <h1 className="text-balance text-5xl font-semibold leading-[.98] tracking-[-.055em] sm:text-6xl lg:text-7xl"><span className="text-primary">Jyotara</span><br /><span className="text-3xl sm:text-5xl">உங்கள் ஜாதகம். உங்கள் நேரம்.</span></h1>
              <p className="mt-6 max-w-xl text-pretty text-lg leading-8 text-muted-foreground">உங்கள் பிறந்த விவரங்களின் அடிப்படையில் ராசி, நட்சத்திரம், லக்னம், தசா–புக்தி, பஞ்சாங்கம் மற்றும் வாழ்க்கை வழிகாட்டலை ஒரே இடத்தில் தமிழில் அறியுங்கள்.</p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Button className="h-12 rounded-full px-6 text-base" onClick={() => goToScreen('consent')}>என் இலவச ஜாதகத்தை உருவாக்கு <ArrowRight className="ml-1" /></Button>
                <span className="inline-flex items-center gap-2 px-2 text-sm text-muted-foreground"><ShieldCheck className="size-4 text-emerald-400" /> OTP இல்லை · கட்டணம் இல்லை</span>
              </div>
            </div>
            <div className="relative mx-auto w-full max-w-[520px]">
              <div className="absolute -inset-5 rounded-[44px] bg-primary/12 blur-3xl" />
              <div className="relative overflow-hidden rounded-[36px] border border-white/10 bg-[linear-gradient(145deg,rgba(122,79,196,.36),rgba(25,17,40,.95)_56%)] p-6 shadow-[0_40px_120px_rgba(0,0,0,.38)] sm:p-8">
                <div className="orbit mb-8" aria-hidden="true"><div className="orbit-ring orbit-ring-one" /><div className="orbit-ring orbit-ring-two" /><div className="orbit-core"><MoonStar /></div>{[0,1,2,3,4,5].map((dot) => <span key={dot} className={`orbit-dot orbit-dot-${dot + 1}`} />)}</div>
                <div className="grid grid-cols-2 gap-3">{['ராசி','நட்சத்திரம்','லக்னம்','தசா'].map((item,index) => <div key={item} className="rounded-2xl border border-white/10 bg-white/6 p-4"><span className="text-[10px] uppercase tracking-[.18em] text-white/45">0{index+1}</span><strong className="mt-2 block text-sm text-white">{item}</strong></div>)}</div>
              </div>
            </div>
          </section>
        )}

        {screen === 'consent' && (
          <section className="mx-auto max-w-3xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('welcome')}><ChevronLeft className="size-4" /> பின்னால்</button>
            <div className="rounded-[32px] border border-border bg-card p-5 shadow-2xl shadow-black/15 sm:p-8">
              <span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">படி 1 / 3</span>
              <h2 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">தொடங்குவதற்கு முன்</h2>
              <p className="mt-3 leading-7 text-muted-foreground">Jyotara கணக்கிடப்பட்ட ஜாதகத் தகவல்களை எளிய தமிழில் விளக்கும் தானியங்கி பாரம்பரிய வழிகாட்டல். இது மனித ஜோதிடர் ஆலோசனை அல்ல.</p>
              <div className="mt-7 space-y-4">
                <div className="flex items-start gap-3 rounded-2xl border border-border bg-secondary/55 p-4 text-sm leading-6"><Checkbox className="mt-1" checked={ageConfirmed} onCheckedChange={(value) => setAgeConfirmed(Boolean(value))} aria-label="எனக்கு 13 வயது அல்லது அதற்கு மேல்" /><span><strong className="block text-foreground">எனக்கு 13 வயது அல்லது அதற்கு மேல்.</strong><span className="text-muted-foreground">இந்தச் சேவை 13 வயது மற்றும் அதற்கு மேற்பட்டவர்களுக்கு.</span></span></div>
                <div className="flex items-start gap-3 rounded-2xl border border-border bg-secondary/55 p-4 text-sm leading-6"><Checkbox className="mt-1" checked={consent} onCheckedChange={(value) => setConsent(Boolean(value))} aria-label="பிறந்த விவரங்களைப் பயன்படுத்த சம்மதிக்கிறேன்" /><span><strong className="block text-foreground">ஜாதகத்தை உருவாக்க என் பிறந்த விவரங்களைப் பயன்படுத்த சம்மதிக்கிறேன்.</strong><span className="text-muted-foreground">இந்த இணையச் சோதனையில் பிறந்த விவரங்கள் நிரந்தரமாக சேமிக்கப்படாது. மருத்துவ, சட்ட அல்லது நிதி முடிவுகளுக்கு இதை மட்டும் நம்ப வேண்டாம்.</span></span></div>
              </div>
              <div className="mt-5 flex flex-wrap gap-4 text-sm text-primary"><button onClick={() => goToScreen('privacy')}>தனியுரிமை மற்றும் தரவு நீக்கம்</button><button onClick={() => goToScreen('premium')}>இலவசம் மற்றும் Plus திட்டம்</button></div>
              <Button disabled={!ageConfirmed || !consent} onClick={() => goToScreen('profile')} className="mt-7 h-13 w-full rounded-2xl text-base">பிறந்த விவரங்களைச் சேர்க்க <ArrowRight className="ml-1" /></Button>
            </div>
          </section>
        )}

        {screen === 'profile' && (
          <section className="mx-auto max-w-3xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('consent')}><ChevronLeft className="size-4" /> பின்னால்</button>
            <div className="rounded-[32px] border border-border bg-card p-5 shadow-2xl shadow-black/15 sm:p-8">
              <div className="mb-8 flex items-start justify-between gap-5"><div><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">படி 2 / 3</span><h2 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">உங்கள் பிறந்த விவரங்கள்</h2><p className="mt-2 text-muted-foreground">சரியான பிறந்த நேரம் லக்னம் மற்றும் வீட்டு கணக்கீடுகளின் துல்லியத்தை மேம்படுத்தும்.</p></div><div className="hidden size-14 place-items-center rounded-2xl bg-primary/12 text-primary sm:grid"><MoonStar /></div></div>
              <div className="grid gap-5 sm:grid-cols-2">
                <div className="space-y-2 sm:col-span-2"><Label htmlFor="name">{t('Name or nickname', 'பெயர் அல்லது அழைப்புப் பெயர்')} <span className="text-muted-foreground">{t('(optional)', '(விருப்பம்)')}</span></Label><Input id="name" value={name} onChange={(e) => setName(e.target.value)} placeholder={t('How should we address you?', 'உங்களை எப்படி அழைக்க வேண்டும்?')} className="h-12 rounded-xl" /></div>
                <div className="space-y-2"><Label htmlFor="birth-date">{t('Date of birth', 'பிறந்த தேதி')}</Label><Input id="birth-date" type="date" value={birthDate} onChange={(e) => setBirthDate(e.target.value)} onInput={(e) => setBirthDate(e.currentTarget.value)} className="h-12 rounded-xl" /></div>
                <div className="space-y-2"><Label htmlFor="birth-time">{t('Exact birth time', 'சரியான பிறந்த நேரம்')}</Label><Input id="birth-time" type="time" value={birthTime} onChange={(e) => setBirthTime(e.target.value)} onInput={(e) => setBirthTime(e.currentTarget.value)} disabled={unknownTime} className="h-12 rounded-xl" /><label className="flex cursor-pointer items-center gap-2 text-sm text-muted-foreground"><Checkbox checked={unknownTime} onCheckedChange={(v) => setUnknownTime(Boolean(v))} /> {t('I don’t know my exact time', 'எனக்கு சரியான நேரம் தெரியாது')}</label></div>
                <div className="space-y-2 sm:col-span-2"><Label htmlFor="birthplace">{t('Birthplace', 'பிறந்த இடம்')}</Label><Input ref={locationInputRef} id="birthplace" value={birthplace} onChange={(e) => { setBirthplace(e.target.value); setBirthLocation(null); }} placeholder={t('Type a city, then choose from the suggestions', 'நகரத்தின் பெயரை உள்ளிட்டு பரிந்துரையில் தேர்ந்தெடுக்கவும்')} autoComplete="off" className="prokerala-location-input h-12 rounded-xl" /><p className={`text-xs ${birthLocation ? 'text-emerald-400' : 'text-muted-foreground'}`}>{birthLocation ? t('Location selected — coordinates and timezone are ready.', 'இடம் தேர்ந்தெடுக்கப்பட்டது — கணக்கீட்டிற்கு தயாராக உள்ளது.') : t('Select the correct Indian birthplace from the suggestion list.', 'பரிந்துரை பட்டியலில் சரியான இந்தியப் பிறந்த இடத்தைத் தேர்ந்தெடுக்கவும்.')}</p></div>
              </div>
              {birthDate && !ageBand && <div className="mt-5 rounded-2xl border border-rose-400/25 bg-rose-400/8 p-4 text-sm text-rose-100">இந்தச் சேவையைப் பயன்படுத்த 13 வயது அல்லது அதற்கு மேல் இருக்க வேண்டும். சரியான பிறந்த தேதியைச் சரிபார்க்கவும்.</div>}
              {ageBand && <div className="mt-5 rounded-2xl border border-primary/20 bg-primary/8 p-4 text-sm text-muted-foreground">வயது குழு: <strong className="text-foreground">{ageBand}</strong>. இது அடுத்த திரையில் பரிந்துரைகளின் வரிசையை மட்டும் மாற்றும்; எந்தப் பகுதியும் மறைக்கப்படாது.</div>}
              <Button disabled={!canContinue} onClick={() => goToScreen('interests')} className="mt-6 h-13 w-full rounded-2xl text-base">ஆர்வங்களைத் தேர்ந்தெடுக்க <ArrowRight className="ml-1" /></Button>
            </div>
          </section>
        )}

        {screen === 'interests' && (
          <section className="mx-auto max-w-4xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('profile')}><ChevronLeft className="size-4" /> பிறந்த விவரங்களுக்குத் திரும்பவும்</button>
            <div className="rounded-[32px] border border-border bg-card p-5 shadow-2xl shadow-black/15 sm:p-8">
              <span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">படி 3 / 3</span>
              <h2 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">எதைப் பற்றி வழிகாட்டல் வேண்டும்?</h2>
              <p className="mt-3 leading-7 text-muted-foreground">ஒன்று முதல் ஐந்து பகுதிகளைத் தேர்ந்தெடுக்கவும். உங்கள் வயது குழுவிற்கு ஏற்ற பகுதிகள் முதலில் காட்டப்பட்டுள்ளன; எல்லாப் பகுதிகளையும் பின்னர் பயன்படுத்தலாம்.</p>
              <div className="mt-7 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                {prioritisedCategories.map((item) => {
                  const Icon = item.icon;
                  const selected = selectedInterests.includes(item.id);
                  return <button key={item.id} type="button" onClick={() => toggleInterest(item.id)} className={`rounded-[22px] border p-4 text-left transition ${selected ? 'border-primary bg-primary/14 shadow-lg shadow-primary/8' : 'border-border bg-background/45 hover:border-primary/40'}`}><div className="flex items-center gap-3"><span className={`grid size-10 place-items-center rounded-xl ${selected ? 'bg-primary text-primary-foreground' : 'bg-secondary text-primary'}`}><Icon className="size-5" /></span><div><strong className="block">{tamilCategoryCopy[item.id].title}</strong><span className="mt-1 block text-xs text-muted-foreground">{tamilCategoryCopy[item.id].subtitle}</span></div>{selected && <Check className="ml-auto size-5 text-primary" />}</div></button>;
                })}
              </div>
              <div className="mt-5 flex items-center justify-between text-sm text-muted-foreground"><span>அதிகபட்சம் 5 பகுதிகள்</span><strong className="text-foreground">{selectedInterests.length} / 5</strong></div>
              {profileError && <div role="alert" className="mt-5 rounded-2xl border border-rose-400/25 bg-rose-400/8 p-4 text-sm leading-6 text-rose-100">{profileError}</div>}
              <Button disabled={!canGenerate} onClick={() => void generateProfile()} className="mt-6 h-13 w-full rounded-2xl text-base">என் ஜாதகத்தை கணக்கிடு <Sparkles className="ml-1" /></Button>
            </div>
          </section>
        )}

        {screen === 'calculating' && (
          <section className="grid min-h-[calc(100vh-120px)] place-items-center py-12"><div className="w-full max-w-xl text-center"><div className="orbit mx-auto" aria-hidden="true"><div className="orbit-ring orbit-ring-one" /><div className="orbit-ring orbit-ring-two" /><div className="orbit-core"><LoaderCircle className="animate-spin" /></div></div><h2 className="mt-8 text-3xl font-semibold tracking-tight">உங்கள் வேத ஜோதிட விவரம் தயாராகிறது</h2><p className="mt-2 text-sm text-muted-foreground">கீழே காட்டப்படும் ஒவ்வொரு படியும் உண்மையான கணக்கீட்டின் ஒரு பகுதி.</p><div className="mx-auto mt-6 max-w-md space-y-3 text-left">{['பிறந்த நேரம் மற்றும் இடத்தைச் சரிபார்க்கிறது','கிரக நிலைகளை கணக்கிடுகிறது','ராசி மற்றும் நட்சத்திரத்தை கண்டறிகிறது','லக்னம் மற்றும் தசா–புக்தியை கணக்கிடுகிறது','தமிழ் வழிகாட்டலைத் தயாரிக்கிறது'].map((item,index) => <div key={item} className="flex items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3"><span className="grid size-7 place-items-center rounded-full bg-primary/14 text-primary"><Check className="size-4" /></span><span className="text-sm">{item}</span><span className="ml-auto text-xs text-muted-foreground">0{index+1}</span></div>)}</div></div></section>
        )}

        {screen === 'home' && (
          <section className="py-8 sm:py-12">
            <div className="grid gap-6 lg:grid-cols-[1.05fr_.95fr]">
            <div className="rounded-[32px] border border-primary/25 bg-[linear-gradient(145deg,rgba(123,77,196,.42),rgba(30,20,48,.9))] p-6 text-white shadow-2xl shadow-primary/10 sm:p-8"><div className="flex items-center justify-between gap-4"><span className="text-xs font-semibold uppercase tracking-[.18em] text-white/60">{t('Welcome', 'வணக்கம்')}, {displayName}</span><span className={`rounded-full border px-3 py-1 text-xs ${apiState === 'live' ? 'border-emerald-300/30 bg-emerald-300/10 text-emerald-100' : 'border-amber-300/30 bg-amber-300/10 text-amber-100'}`}>{apiState === 'live' ? t('Live chart calculated', 'நேரடி ஜாதகம் கணக்கிடப்பட்டது') : apiState === 'sandbox' ? t('Test API connected', 'சோதனை API இணைந்துள்ளது') : t('API unavailable', 'API கிடைக்கவில்லை')}</span></div><h2 className="mt-5 text-4xl font-semibold tracking-tight">{apiState === 'live' ? t('Your Vedic profile is ready.', 'உங்கள் வேத ஜோதிட விவரம் தயாராகிவிட்டது.') : t('Your Vedic profile is ready to test.', 'உங்கள் ஜோதிட விவரம் சோதனைக்கு தயாராக உள்ளது.')}</h2><p className="mt-4 max-w-xl leading-7 text-white/68">{apiState === 'live' ? (unknownTime ? t('Your chart snapshot uses noon as a temporary birth time. Rashi and Nakshatra are shown as provisional; Lagna, houses and timing need your exact birth time.', 'தற்காலிக பிறந்த நேரமாக நண்பகல் பயன்படுத்தப்பட்டுள்ளது. ராசி மற்றும் நட்சத்திரம் தற்காலிகமாகக் காட்டப்படுகின்றன; லக்னம், வீடுகள் மற்றும் காலநிலை விளக்கத்திற்கு சரியான பிறந்த நேரம் தேவை.') : t('Your chart snapshot below was calculated from the exact date, time and birthplace you selected.', 'நீங்கள் தேர்ந்தெடுத்த பிறந்த தேதி, நேரம் மற்றும் இடத்தை வைத்து கீழே உள்ள ஜாதகச் சுருக்கம் கணக்கிடப்பட்டது.')) : apiState === 'sandbox' ? t(`The secure sandbox returned ${sandboxModules.length} calculation modules. Sandbox values are mock data and are not shown as your personal chart.`, `பாதுகாப்பான சோதனை API ${sandboxModules.length} கணக்கீட்டு பகுதிகளை வழங்கியது. சோதனைத் தகவல்கள் உங்கள் தனிப்பட்ட ஜாதகமாக காட்டப்படாது.`) : t('The interface is working, but the chart calculation could not be reached. No personal result has been shown.', 'திரை செயல்படுகிறது; ஆனால் ஜாதக கணக்கீட்டை அணுக முடியவில்லை. தனிப்பட்ட முடிவு எதுவும் காட்டப்படவில்லை.')}</p><div className="mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4">{[{label:t('Rashi','ராசி'),value:chartSummary.rashi},{label:t('Nakshatra','நட்சத்திரம்'),value:chartSummary.nakshatra ? `${chartSummary.nakshatra}${chartSummary.pada ? ` · ${t('Pada','பாதம்')} ${chartSummary.pada}` : ''}` : undefined},{label:t('Lagna','லக்னம்'),value:unknownTime ? t('Exact time needed','சரியான நேரம் தேவை') : chartSummary.lagna},{label:t('Current Dasha','நடப்பு தசா'),value:chartSummary.currentDasha?.name}].map((item) => <div key={item.label} className="rounded-2xl border border-white/10 bg-white/7 p-4"><span className="text-xs text-white/45">{item.label}</span><strong className="mt-2 block text-sm">{apiState === 'live' ? (item.value ?? t('Not returned','தகவல் கிடைக்கவில்லை')) : t('Pending live data','நேரடி தகவல் நிலுவையில் உள்ளது')}</strong></div>)}</div>{apiState === 'live' && <Button variant="secondary" onClick={() => goToScreen('chart')} className="mt-6 h-11 rounded-full px-5">{t('View my complete chart','என் முழு ஜாதகத்தைப் பார்க்க')} <ArrowRight className="ml-1" /></Button>}</div>
              <div className="rounded-[32px] border border-border bg-card p-6 sm:p-8"><div className="flex items-center gap-3"><span className="grid size-11 place-items-center rounded-2xl bg-secondary text-primary"><Languages /></span><div><span className="text-xs text-muted-foreground">உங்கள் அமைப்பு</span><strong className="block">தமிழ் · தென்னிந்திய ஜாதக வடிவம்</strong></div></div><div className="mt-6 space-y-3 text-sm"><div className="flex justify-between border-b border-border pb-3"><span className="text-muted-foreground">வயது குழு</span><strong>{ageBand}</strong></div><div className="flex justify-between border-b border-border pb-3"><span className="text-muted-foreground">பிறந்த தேதி</span><strong>{birthDate}</strong></div><div className="flex justify-between border-b border-border pb-3"><span className="text-muted-foreground">பிறந்த நேரம்</span><strong>{unknownTime ? 'தெரியவில்லை' : birthTime}</strong></div><div className="flex justify-between gap-4"><span className="text-muted-foreground">பிறந்த இடம்</span><strong className="text-right">{birthplace}</strong></div></div><div className="mt-5 flex flex-wrap gap-2">{selectedInterests.map((item) => <span key={item} className="rounded-full bg-primary/10 px-3 py-1.5 text-xs text-primary">{tamilCategoryCopy[item].title}</span>)}</div></div>
            </div>
            {chartSummary.todayPanchang && <div className="mt-6 rounded-[28px] border border-amber-300/20 bg-[linear-gradient(135deg,rgba(245,178,72,.12),rgba(123,77,196,.10))] p-5 sm:p-6"><div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center"><div><span className="text-xs font-semibold uppercase tracking-[.16em] text-amber-300">{t('Today’s Panchang','இன்றைய பஞ்சாங்கம்')}</span><h3 className="mt-2 text-2xl font-semibold">{chartSummary.todayPanchang.vaara ?? t('Today','இன்று')} · {chartSummary.todayPanchang.tithi ?? t('Tithi unavailable','திதி கிடைக்கவில்லை')}</h3></div><div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">{[{label:t('Nakshatra','நட்சத்திரம்'),value:chartSummary.todayPanchang.nakshatra},{label:t('Yoga','யோகம்'),value:chartSummary.todayPanchang.yoga},{label:t('Karana','கரணம்'),value:chartSummary.todayPanchang.karana}].map((item) => <div key={item.label} className="rounded-2xl border border-white/8 bg-black/10 px-4 py-3"><span className="block text-xs text-muted-foreground">{item.label}</span><strong className="mt-1 block">{item.value ?? '—'}</strong></div>)}</div></div></div>}
            <div className="mt-10 flex items-end justify-between gap-5"><div><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Explore','ஆராயுங்கள்')}</span><h2 className="mt-1 text-3xl font-semibold tracking-tight">{t('What would you like guidance about?','எதைப் பற்றி வழிகாட்டல் வேண்டும்?')}</h2></div><span className="hidden text-sm text-muted-foreground sm:block">{t('Choose one','ஒன்றைத் தேர்ந்தெடுக்கவும்')} · {remaining} {t('questions remaining','கேள்விகள் மீதம்')}</span></div>
            <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{prioritisedCategories.map((item, index) => { const Icon=item.icon; const copy=tamilCategoryCopy[item.id]; const recommended=selectedInterests.includes(item.id) || index < 4; return <button key={item.id} onClick={() => openCategory(item.id)} className="group rounded-[24px] border border-border bg-card p-5 text-left transition hover:-translate-y-1 hover:border-primary/45 hover:shadow-xl hover:shadow-primary/8">{recommended && <span className="mb-4 inline-flex rounded-full bg-primary/10 px-2.5 py-1 text-[10px] font-semibold text-primary">உங்களுக்குப் பரிந்துரை</span>}<span className="grid size-11 place-items-center rounded-2xl bg-primary/10 text-primary transition group-hover:bg-primary group-hover:text-primary-foreground"><Icon /></span><strong className="mt-5 block text-lg">{copy.title}</strong><span className="mt-1 block text-sm leading-6 text-muted-foreground">{copy.subtitle}</span><ArrowRight className="mt-5 size-4 text-muted-foreground transition group-hover:translate-x-1 group-hover:text-primary" /></button>; })}</div>
            <div className="mt-8 grid gap-4 rounded-[28px] border border-border bg-card p-5 sm:grid-cols-[1fr_.9fr] sm:p-6"><div><span className="text-xs font-semibold uppercase tracking-[.16em] text-emerald-400">இந்த இலவச இணையச் சோதனையில்</span><ul className="mt-3 space-y-2 text-sm text-muted-foreground"><li>• ராசி, நட்சத்திரம்/பாதம், லக்னம் மற்றும் கிரக நிலைகள்</li><li>• தென்னிந்திய ராசி கட்டம், தசா, கோச்சாரம் மற்றும் பஞ்சாங்கம்</li><li>• மாதிரியாக மூன்று தனிப்பட்ட கேள்விகள்</li><li>• வயது மற்றும் ஆர்வத்தின் அடிப்படையில் பரிந்துரைகள்</li></ul></div><div className="rounded-2xl border border-primary/20 bg-primary/8 p-4"><div className="flex items-center gap-2 text-primary"><Crown className="size-5" /><strong>Jyotara Plus</strong></div><p className="mt-2 text-2xl font-semibold">₹199 <span className="text-sm font-normal text-muted-foreground">/ மாதம்</span></p><p className="mt-2 text-sm leading-6 text-muted-foreground">Android வெளியீட்டில் 30 கேள்விகள், விரிவான ஜாதகம், மாத அறிக்கை, வரலாறு மற்றும் நினைவூட்டல்கள்.</p><Button variant="outline" onClick={() => goToScreen('premium')} className="mt-4 rounded-full">முழு விவரம்</Button></div></div>
          </section>
        )}

        {screen === 'chart' && (
          <section className="mx-auto max-w-5xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('home')}><ChevronLeft className="size-4" /> {t('Back to home','முகப்பிற்குத் திரும்பவும்')}</button>
            <div className="mb-7 flex flex-col justify-between gap-4 sm:flex-row sm:items-end"><div><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Live Vedic calculation','நேரடி வேத ஜோதிடக் கணக்கீடு')}</span><h2 className="mt-2 text-4xl font-semibold tracking-tight sm:text-5xl">{t('My Complete Chart','என் முழு ஜாதகம்')}</h2><p className="mt-3 max-w-2xl leading-7 text-muted-foreground">{t('Your identity, Lagna, planet positions, Rasi chart, Dasha, Mangal Dosha and Yogas returned by the connected Production API.','நேரடி API வழங்கிய உங்கள் அடையாளம், லக்னம், கிரக நிலைகள், ராசி கட்டம், தசா, செவ்வாய் தோஷம் மற்றும் யோக விவரங்கள்.')}</p></div><span className="inline-flex w-fit items-center gap-2 rounded-full border border-emerald-400/25 bg-emerald-400/8 px-3 py-2 text-xs text-emerald-300"><ShieldCheck className="size-4" /> {t('Calculated from selected birthplace','தேர்ந்தெடுத்த பிறந்த இடத்திலிருந்து கணக்கிடப்பட்டது')}</span></div>

            <div className="grid gap-5 lg:grid-cols-[1.2fr_.8fr]">
              <div className="overflow-hidden rounded-[32px] border border-primary/25 bg-[linear-gradient(145deg,rgba(123,77,196,.42),rgba(30,20,48,.92))] p-6 text-white shadow-2xl shadow-primary/10 sm:p-8">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="rounded-[24px] border border-white/10 bg-white/7 p-5"><span className="grid size-11 place-items-center rounded-2xl bg-white/10 text-amber-300"><MoonStar /></span><span className="mt-5 block text-xs uppercase tracking-[.16em] text-white/45">{t('Chandra Rashi · Moon sign','சந்திர ராசி')}</span><strong className="mt-2 block text-3xl">{chartSummary.rashi ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</strong><span className="mt-2 block text-sm text-white/55">{t('Lord','அதிபதி')}: {chartSummary.rashiLord ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</span></div>
                  <div className="rounded-[24px] border border-white/10 bg-white/7 p-5"><span className="grid size-11 place-items-center rounded-2xl bg-white/10 text-amber-300"><Star /></span><span className="mt-5 block text-xs uppercase tracking-[.16em] text-white/45">{t('Birth star','பிறந்த நட்சத்திரம்')}</span><strong className="mt-2 block text-3xl">{chartSummary.nakshatra ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</strong><span className="mt-2 block text-sm text-white/55">{t('Pada','பாதம்')} {chartSummary.pada ?? '—'} · {t('Lord','அதிபதி')} {chartSummary.nakshatraLord ?? '—'}</span></div>
                </div>
                <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">{[{label:t('Soorya Rashi','சூரிய ராசி'),value:chartSummary.sunRashi},{label:t('Western sign','மேற்கத்திய ராசி'),value:chartSummary.zodiac},{label:t('Ganam','கணம்'),value:chartSummary.ganam},{label:t('Nadi','நாடி'),value:chartSummary.nadi}].map((item) => <div key={item.label} className="rounded-2xl border border-white/10 bg-black/10 p-4"><span className="text-[10px] uppercase tracking-[.14em] text-white/40">{item.label}</span><strong className="mt-2 block text-sm">{item.value ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</strong></div>)}</div>
              </div>

              <div className={`rounded-[32px] border p-6 sm:p-8 ${chartSummary.mangalDosha?.hasDosha ? 'border-amber-400/25 bg-amber-400/8' : 'border-emerald-400/25 bg-emerald-400/8'}`}><span className="text-xs font-semibold uppercase tracking-[.18em] text-muted-foreground">{t('Mangal Dosha','செவ்வாய் தோஷம்')}</span><h3 className="mt-3 text-3xl font-semibold">{chartSummary.mangalDosha ? (chartSummary.mangalDosha.hasDosha ? t('Detected','கண்டறியப்பட்டது') : t('Not detected','கண்டறியப்படவில்லை')) : t('Not returned','தகவல் கிடைக்கவில்லை')}</h3><p className="mt-4 leading-7 text-muted-foreground">{isTamil ? (chartSummary.mangalDosha?.hasDosha ? 'API கணக்கீட்டின்படி செவ்வாய் தோஷம் கண்டறியப்பட்டுள்ளது. விரிவான தமிழ் விளக்கம் அடுத்த கட்டத்தில் இணைக்கப்படும்.' : 'API கணக்கீட்டின்படி செவ்வாய் தோஷம் கண்டறியப்படவில்லை.') : (chartSummary.mangalDosha?.description ?? 'No Mangal Dosha description was returned for this calculation.')}</p><div className="mt-6 rounded-2xl border border-border/70 bg-background/45 p-4 text-xs leading-5 text-muted-foreground">{t('This is a traditional Kundli calculation. It should not be treated as a guarantee or used alone for a major life decision.','இது பாரம்பரிய ஜாதகக் கணக்கீடு. இதை உறுதியான கணிப்பாகவோ, முக்கிய வாழ்க்கை முடிவிற்கு ஒரே ஆதாரமாகவோ பயன்படுத்த வேண்டாம்.')}</div></div>
            </div>

            {unknownTime && <div className="mt-5 rounded-2xl border border-amber-400/25 bg-amber-400/8 p-4 text-sm leading-6 text-amber-100">{t('Birth time was marked unknown, so noon was used as a fallback. Lagna, houses and timing-sensitive results may change when the exact time is added.','பிறந்த நேரம் தெரியவில்லை என்று தேர்வு செய்யப்பட்டதால் நண்பகல் நேரம் பயன்படுத்தப்பட்டது. சரியான நேரத்தைச் சேர்த்தால் லக்னம், வீடுகள் மற்றும் காலநிலை முடிவுகள் மாறலாம்.')}</div>}

            <div className="mt-6 grid gap-5 lg:grid-cols-2">
              <div className="rounded-[32px] border border-border bg-card p-6 sm:p-8"><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Rasi birth chart','ராசி கட்டம்')}</span><h3 className="mt-2 text-3xl font-semibold">{chartSummary.lagna ?? t('Lagna not returned','லக்னம் கிடைக்கவில்லை')} {t('Lagna','லக்னம்')}</h3><p className="mt-2 text-sm text-muted-foreground">{t('Lagna lord','லக்ன அதிபதி')}: {chartSummary.lagnaLord ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</p><LocalChart chart={chartSummary} tradition={tradition} tamil={isTamil} /><p className="mt-3 text-xs leading-5 text-muted-foreground">{t('Rendered securely from the calculated Lagna and planet positions, without spending an extra API request.','கணக்கிடப்பட்ட லக்னம் மற்றும் கிரக நிலைகளிலிருந்து கூடுதல் API கோரிக்கை இல்லாமல் பாதுகாப்பாக உருவாக்கப்பட்டது.')}</p></div>
              <div className="rounded-[32px] border border-border bg-card p-6 sm:p-8"><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Current Vimshottari period','நடப்பு விம்சோத்தரி காலம்')}</span><h3 className="mt-2 text-3xl font-semibold">{chartSummary.currentDasha?.name ?? t('Dasha not returned','தசா கிடைக்கவில்லை')}</h3><div className="mt-6 space-y-4"><div className="rounded-2xl border border-border bg-background/45 p-4"><span className="text-xs text-muted-foreground">{t('Mahadasha','மகாதசா')}</span><strong className="mt-1 block">{chartSummary.currentDasha?.name ?? '—'}</strong>{chartSummary.currentDasha && <span className="mt-2 block text-xs text-muted-foreground">{new Date(chartSummary.currentDasha.start).toLocaleDateString()} – {new Date(chartSummary.currentDasha.end).toLocaleDateString()}</span>}</div><div className="rounded-2xl border border-border bg-background/45 p-4"><span className="text-xs text-muted-foreground">{t('Antardasha','அந்தர்தசா')}</span><strong className="mt-1 block">{chartSummary.currentAntardasha?.name ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</strong>{chartSummary.currentAntardasha && <span className="mt-2 block text-xs text-muted-foreground">{new Date(chartSummary.currentAntardasha.start).toLocaleDateString()} – {new Date(chartSummary.currentAntardasha.end).toLocaleDateString()}</span>}</div>{chartSummary.dashaBalance && <div className="rounded-2xl border border-border bg-background/45 p-4 text-sm leading-6 text-muted-foreground"><strong className="mb-1 block text-foreground">{t('Balance at birth','பிறப்பின் போது மீதமுள்ள தசை')}</strong>{chartSummary.dashaBalance}</div>}</div><p className="mt-5 text-xs leading-5 text-muted-foreground">{t('Dasha is one timing input. A complete timing reading also needs current transits and reviewed interpretation rules.','தசா என்பது காலநிலை ஆய்வின் ஒரு பகுதி. முழுமையான காலநிலை வாசிப்பிற்கு நடப்பு கோச்சாரம் மற்றும் சரிபார்க்கப்பட்ட விளக்க விதிகளும் தேவை.')}</p></div>
            </div>

            <div className="mt-6 rounded-[32px] border border-border bg-card p-6 sm:p-8"><div className="flex items-end justify-between gap-4"><div><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Live calculation','நேரடி கணக்கீடு')}</span><h3 className="mt-2 text-3xl font-semibold">{t('Planet positions','கிரக நிலைகள்')}</h3></div><span className="text-sm text-muted-foreground">{chartSummary.planets.length} {t('returned','கிடைத்தது')}</span></div>{chartSummary.planets.length ? <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{chartSummary.planets.map((planet) => <div key={planet.name} className="rounded-2xl border border-border bg-background/45 p-4"><div className="flex items-center justify-between gap-3"><strong>{planet.name}</strong>{planet.isRetrograde && <span className="rounded-full bg-amber-400/10 px-2 py-1 text-[10px] font-semibold uppercase text-amber-300">{t('Retrograde','வக்ரம்')}</span>}</div><span className="mt-2 block text-sm text-muted-foreground">{planet.rasi} · {planet.degree.toFixed(2)}°</span></div>)}</div> : <p className="mt-5 text-muted-foreground">{t('Planet positions were not returned by the API.','கிரக நிலைகள் API-யில் கிடைக்கவில்லை.')}</p>}</div>

            <div className="mt-6 rounded-[32px] border border-border bg-card p-6 sm:p-8"><div className="flex items-center justify-between gap-4"><div><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{t('Detected groups','கண்டறியப்பட்ட வகைகள்')}</span><h3 className="mt-2 text-3xl font-semibold">{t('Yoga details','யோக விவரங்கள்')}</h3></div><span className="rounded-full bg-secondary px-3 py-1.5 text-xs text-muted-foreground">{chartSummary.yogas.length} {t('returned','கிடைத்தது')}</span></div>{chartSummary.yogas.length ? <div className="mt-6 grid gap-4 sm:grid-cols-2">{chartSummary.yogas.map((yoga, index) => <article key={`${yoga.name}-${index}`} className="rounded-[22px] border border-border bg-background/45 p-5"><div className="flex items-start gap-3"><span className="grid size-9 shrink-0 place-items-center rounded-xl bg-primary/12 text-primary"><Sparkles className="size-4" /></span><div><h4 className="font-semibold">{yoga.name}</h4><p className="mt-2 text-sm leading-6 text-muted-foreground">{isTamil ? 'இந்த யோகம் API ஜாதகக் கணக்கீட்டில் கண்டறியப்பட்டது. விரிவான தமிழ் விளக்கம் அடுத்த கட்டத்தில் இணைக்கப்படும்.' : yoga.description}</p></div></div></article>)}</div> : <p className="mt-5 text-muted-foreground">{t('No Yoga groups were returned for this calculation.','இந்தக் கணக்கீட்டில் யோக விவரங்கள் எதுவும் கிடைக்கவில்லை.')}</p>}</div>

            <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{[{label:t('Deity','தெய்வம்'),value:chartSummary.deity},{label:t('Symbol','சின்னம்'),value:chartSummary.symbol},{label:t('Animal sign','விலங்கு குறியீடு'),value:chartSummary.animalSign},{label:t('Birth stone','பிறப்பு கல்'),value:chartSummary.birthStone},{label:t('Best direction','சிறந்த திசை'),value:chartSummary.bestDirection},{label:t('Name syllables','பெயர் எழுத்துகள்'),value:chartSummary.syllables}].map((item) => <div key={item.label} className="rounded-[22px] border border-border bg-card p-5"><span className="text-xs uppercase tracking-[.14em] text-muted-foreground">{item.label}</span><strong className="mt-2 block text-sm leading-6">{item.value ?? t('Not returned','தகவல் கிடைக்கவில்லை')}</strong></div>)}</div>

            <div className="mt-6 flex items-start gap-3 rounded-2xl border border-primary/20 bg-primary/8 p-5 text-sm leading-6 text-muted-foreground"><Sun className="mt-0.5 size-5 shrink-0 text-primary" /><p><strong className="text-foreground">{t('Connected now:','இப்போது இணைக்கப்பட்டுள்ளது:')}</strong> {t('Lagna, Rasi chart, natal planets, current transits, Panchang and Dasha are calculated live. Complete house and divisional-chart interpretation remains a later module.','லக்னம், ராசி கட்டம், பிறப்பு கிரக நிலைகள், நடப்பு கோச்சாரம், பஞ்சாங்கம் மற்றும் தசா நேரடியாக கணக்கிடப்படுகின்றன. முழுமையான வீடு மற்றும் வர்க்கக் கட்ட விளக்கம் அடுத்த கட்டமாகும்.')}</p></div>
          </section>
        )}

        {screen === 'privacy' && (
          <section className="mx-auto max-w-4xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('welcome')}><ChevronLeft className="size-4" /> பின்னால்</button>
            <div className="rounded-[32px] border border-border bg-card p-5 shadow-2xl shadow-black/15 sm:p-8">
              <span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">தனியுரிமை</span>
              <h2 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">உங்கள் தகவல் எப்படிப் பயன்படுத்தப்படுகிறது?</h2>
              <div className="mt-7 grid gap-4 sm:grid-cols-2">
                {[['ஜாதகக் கணக்கீடு','பிறந்த தேதி, நேரம் மற்றும் இடம் Prokerala சேவைக்கு பாதுகாப்பான server வழியாக அனுப்பப்படும். ரகசிய API keys உலாவியில் இருக்காது.'],['இந்த இணையச் சோதனை','பெயர் மற்றும் பிறந்த விவரங்கள் நிரந்தரமாக எங்கள் ஆய்வு தரவுத்தளத்தில் சேமிக்கப்படாது.'],['விருப்பமான கேள்வி ஆய்வு','நீங்கள் தனியாக சம்மதித்தால் மட்டும், தொடர்பு விவரங்கள் நீக்கப்பட்ட கேள்வி 90 நாட்கள் வரை ஆய்விற்காக சேமிக்கப்படும்.'],['பாதுகாப்பு','மருத்துவம், சட்டம், முதலீடு, கர்ப்பம், மரணம் போன்ற முக்கிய முடிவுகளுக்கு ஜாதகக் கணிப்பு வழங்கப்படாது.']].map(([title,body]) => <article key={title} className="rounded-2xl border border-border bg-background/45 p-5"><strong>{title}</strong><p className="mt-2 text-sm leading-6 text-muted-foreground">{body}</p></article>)}
              </div>
              <div className="mt-6 rounded-2xl border border-rose-400/20 bg-rose-400/7 p-5"><strong>இந்த உலாவியின் சோதனைத் தரவை நீக்க</strong><p className="mt-2 text-sm leading-6 text-muted-foreground">இந்த session-இல் சேமிக்கப்பட்ட event மற்றும் சம்மதிக்கப்பட்ட கேள்வி ஆய்வுத் தரவு நீக்கப்படும்; மீண்டும் பெற முடியாது.</p><Button variant="outline" onClick={() => void deleteMyPilotData()} className="mt-4 rounded-full border-rose-300/30 text-rose-100">என் சோதனைத் தரவை நீக்கு</Button></div>
            </div>
          </section>
        )}

        {screen === 'premium' && (
          <section className="mx-auto max-w-5xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack(profileCompletedRef.current ? 'home' : 'welcome')}><ChevronLeft className="size-4" /> பின்னால்</button>
            <div className="text-center"><span className="text-xs font-semibold uppercase tracking-[.18em] text-primary">Android வெளியீட்டுத் திட்டம்</span><h2 className="mt-2 text-4xl font-semibold tracking-tight">இலவசமாக தொடங்குங்கள். தேவைப்பட்டால் ஆழமாகச் செல்லுங்கள்.</h2><p className="mx-auto mt-4 max-w-2xl leading-7 text-muted-foreground">இந்த இணையச் சோதனையில் பணம் வசூலிக்கப்படாது. கீழே உள்ள Plus திட்டம் Android app வெளியீட்டிற்கான தெளிவான முன்னோட்டம்.</p></div>
            <div className="mt-8 grid gap-5 md:grid-cols-2">
              <article className="rounded-[30px] border border-border bg-card p-6 sm:p-8"><span className="text-sm text-muted-foreground">இலவசம்</span><h3 className="mt-2 text-3xl font-semibold">₹0</h3><ul className="mt-6 space-y-3 text-sm text-muted-foreground"><li>✓ ஒரு தனிப்பட்ட பிறப்பு ஜாதகம்</li><li>✓ ராசி, நட்சத்திரம், லக்னம், தசா சுருக்கம்</li><li>✓ தென்னிந்திய ராசி கட்டம்</li><li>✓ இன்றைய பஞ்சாங்கம்</li><li>✓ மாதம் 3 தனிப்பட்ட கேள்விகள்</li></ul></article>
              <article className="relative overflow-hidden rounded-[30px] border border-primary/40 bg-[linear-gradient(145deg,rgba(123,77,196,.34),rgba(25,17,40,.96))] p-6 shadow-2xl shadow-primary/10 sm:p-8"><span className="absolute right-5 top-5 rounded-full bg-primary px-3 py-1 text-xs font-semibold text-primary-foreground">பரிந்துரை</span><div className="flex items-center gap-2 text-primary"><Crown className="size-5" /><span className="text-sm">Jyotara Plus</span></div><h3 className="mt-2 text-3xl font-semibold">₹199 <span className="text-sm font-normal text-muted-foreground">/ மாதம்</span></h3><ul className="mt-6 space-y-3 text-sm text-muted-foreground"><li>✓ மாதம் 30 தனிப்பட்ட கேள்விகள்</li><li>✓ விரிவான ஜாதகம் மற்றும் தசா–புக்தி விளக்கம்</li><li>✓ நடப்பு கோச்சார வழிகாட்டல்</li><li>✓ மாதாந்திர தமிழ் அறிக்கை</li><li>✓ கேள்வி வரலாறு மற்றும் நினைவூட்டல்கள்</li></ul><div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4 text-xs leading-5 text-muted-foreground">Google Play மூலம் வாங்குதல், auto-renewal, cancellation மற்றும் restore purchase வசதிகள் Android வெளியீட்டில் இணைக்கப்படும்.</div></article>
            </div>
          </section>
        )}

        {screen === 'chat' && (
          <section className="mx-auto max-w-4xl py-8 sm:py-12">
            <button className="mb-5 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground" onClick={() => goBack('home')}><ChevronLeft className="size-4" /> {t('Back to categories','வகைகளுக்குத் திரும்பவும்')}</button>
            <div className="overflow-hidden rounded-[32px] border border-border bg-card shadow-2xl shadow-black/15"><div className="flex items-center gap-4 border-b border-border p-5 sm:p-6"><span className="grid size-12 place-items-center rounded-2xl bg-primary text-primary-foreground"><MessageCircle /></span><div><span className="text-xs text-muted-foreground">{t('Personalised guidance','தனிப்பட்ட வழிகாட்டல்')}</span><h2 className="text-xl font-semibold">{isTamil ? tamilCategoryCopy[category].title : category}</h2></div><span className="ml-auto rounded-full bg-secondary px-3 py-1.5 text-xs text-muted-foreground">{remaining} {t('left','மீதம்')}</span></div>
              <div className="min-h-[460px] p-5 sm:p-7"><div className="max-w-[86%] rounded-[22px] rounded-tl-md bg-secondary p-4 leading-7">உங்கள் கேள்வியை தமிழில் அல்லது Tanglish-ல் எழுதுங்கள். கணக்கிடப்பட்ட ஜாதகம், நடப்பு கிரக நிலைகள் மற்றும் பஞ்சாங்கத்தின் ஆதரவுள்ள தகவல்கள் மட்டும் பதிலில் பயன்படுத்தப்படும்.</div><div className="mt-5 flex items-start gap-3 rounded-2xl border border-primary/20 bg-primary/8 p-4 text-sm leading-6"><Checkbox className="mt-1" checked={questionResearchConsent} onCheckedChange={(value) => setQuestionResearchConsent(Boolean(value))} aria-label="கேள்வியை ஆய்விற்காக சேமிக்க சம்மதிக்கிறேன்" /><span><strong className="block">விருப்பமான ஆய்வு சம்மதம்</strong>நான் எழுதும் கேள்வியை தொடர்பு விவரங்கள் நீக்கப்பட்ட நிலையில் 90 நாட்கள் வரை Jyotara தயாரிப்பு ஆய்விற்காக சேமிக்கலாம். இதை ஏற்காவிட்டாலும் கேள்வி கேட்கலாம்.</span></div><form className="mt-4 flex items-end gap-3 rounded-[24px] border border-border bg-background p-2 focus-within:border-primary/60" onSubmit={(event) => { event.preventDefault(); void askQuestion(questionDraft); }}><Input value={questionDraft} onChange={(event) => setQuestionDraft(event.target.value)} disabled={remaining === 0 || answerState === 'loading'} maxLength={240} placeholder="உங்கள் கேள்வியை எழுதுங்கள்… / Ungal kelviyai ezhuthunga…" aria-label="உங்கள் ஜோதிடக் கேள்வி" className="h-12 border-0 bg-transparent shadow-none focus-visible:ring-0" /><Button type="submit" size="icon" disabled={!questionDraft.trim() || remaining === 0 || answerState === 'loading'} className="size-12 shrink-0 rounded-2xl" aria-label="கேள்வியை அனுப்பவும்">{answerState === 'loading' ? <LoaderCircle className="animate-spin" /> : <ArrowRight />}</Button></form><div className="mt-2 flex justify-between px-2 text-xs text-muted-foreground"><span>{questionResearchConsent ? 'பெயரில்லா கேள்வி ஆய்வு அனுமதிக்கப்பட்டது' : 'உங்கள் கேள்வியின் உரை ஆய்விற்காக சேமிக்கப்படாது'}</span><span>{questionDraft.length}/240</span></div>
                {selectedQuestion && <div className="mt-7 space-y-4"><div className="ml-auto max-w-[80%] rounded-[22px] rounded-tr-md bg-primary px-4 py-3 text-sm leading-6 text-primary-foreground">{selectedQuestion}</div>{answerState === 'loading' ? <div className="flex max-w-[90%] items-center gap-3 rounded-[22px] rounded-tl-md border border-primary/20 bg-primary/8 p-5 text-sm text-muted-foreground"><LoaderCircle className="size-5 animate-spin text-primary" /> {t('Reading the relevant chart factors…','தொடர்புடைய ஜாதக காரணிகளைப் பார்க்கிறது…')}</div> : <div className="max-w-[90%] rounded-[22px] rounded-tl-md border border-primary/20 bg-primary/8 p-5"><div className="mb-3 flex items-center gap-2 text-xs font-semibold uppercase tracking-[.14em] text-primary"><Sparkles className="size-4" /> {t('Chart-based answer','ஜாதக அடிப்படையிலான பதில்')}</div><p className="whitespace-pre-line leading-7">{activeAnswer.body}</p>{answerState === 'error' && <p className="mt-3 text-xs text-amber-200">{t('The personalised service was temporarily unavailable, so a safe chart-based answer is shown.','தனிப்பயன் சேவை தற்காலிகமாக கிடைக்காததால் பாதுகாப்பான ஜாதக அடிப்படையிலான பதில் காட்டப்படுகிறது.')}</p>}<div className="mt-5 rounded-2xl border border-border bg-background/50 p-4 text-sm text-muted-foreground"><strong className="mb-2 block text-foreground">{t('Chart facts used','பயன்படுத்தப்பட்ட ஜாதகத் தகவல்கள்')}</strong>{activeAnswer.evidence.length ? <ul className="space-y-1">{activeAnswer.evidence.map((fact) => <li key={fact}>• {fact}</li>)}</ul> : <span>{t('No chart fact can responsibly support this question.','இந்த கேள்வியை பொறுப்புடன் ஆதரிக்கும் ஜாதகத் தகவல் இல்லை.')}</span>}{activeAnswer.limitation && <div className="mt-3 border-t border-border pt-3"><strong className="text-foreground">{t('Current limit:','தற்போதைய வரம்பு:')}</strong> {activeAnswer.limitation}</div>}</div><div className="mt-5 flex items-center gap-2"><span className="mr-2 text-xs text-muted-foreground">{t('Was this useful?','இது பயனுள்ளதாக இருந்ததா?')}</span><Button variant={feedback==='up'?'default':'outline'} size="icon" onClick={() => answerFeedback(true)} aria-label="Helpful"><ThumbsUp /></Button><Button variant={feedback==='down'?'default':'outline'} size="icon" onClick={() => answerFeedback(false)} aria-label="Not helpful"><ThumbsDown /></Button></div></div>}</div>}
                {remaining===0 && <div className="mt-6 rounded-2xl border border-amber-400/25 bg-amber-400/8 p-4 text-sm text-amber-100">{t('You have completed the three-question pilot. Thank you—your feedback helps us decide what to build next.','மூன்று கேள்விகளுக்கான இலவச சோதனையை முடித்துவிட்டீர்கள். நன்றி—உங்கள் கருத்து அடுத்ததாக எதை உருவாக்க வேண்டும் என்பதை முடிவு செய்ய உதவும்.')}</div>}
              </div>
            </div>
          </section>
        )}
        <footer className="mt-8 flex flex-col items-center justify-between gap-3 border-t border-border py-6 text-xs text-muted-foreground sm:flex-row"><span>© Jyotara · பாரம்பரிய வேத ஜோதிட வழிகாட்டல்</span><div className="flex gap-4"><button onClick={() => goToScreen('privacy')} className="hover:text-foreground">தனியுரிமை</button><button onClick={() => goToScreen('premium')} className="hover:text-foreground">திட்டங்கள்</button></div></footer>
      </div>
    </main>
  );
}
