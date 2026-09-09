import { prokeralaToken } from '../lib/prokerala-client';

export const signs = ['aries','taurus','gemini','cancer','leo','virgo','libra','scorpio','sagittarius','capricorn','aquarius','pisces'];
const cache = new Map<string, { expires: number; value: unknown }>();
const pending = new Map<string, Promise<unknown>>();
async function provider(path: string, params: Record<string,string>) {
  const token = await prokeralaToken({PROKERALA_CLIENT_ID:process.env.PROKERALA_CLIENT_ID, PROKERALA_CLIENT_SECRET:process.env.PROKERALA_CLIENT_SECRET});
  const url = new URL(`https://api.prokerala.com/v2${path}`);
  Object.entries(params).forEach(([k,v]) => url.searchParams.set(k,v));
  const response = await fetch(url, {headers:{Authorization:`Bearer ${token}`}, signal:AbortSignal.timeout(15000), redirect:'error'});
  if (!response.ok) throw Error('Provider unavailable');
  const body: any = await response.json();
  if (body.status !== 'ok' || !body.data) throw Error('Invalid provider response');
  return body.data;
}
export function validDay(date: unknown, now = Date.now()) {
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const today = new Date(now+19800000).toISOString().slice(0,10);
  const delta = (Date.parse(date)-Date.parse(today))/86400000;
  return [-1,0,1].includes(delta);
}
export async function daily(request: Request) {
  try {
    const {sign,date} = await request.json() as any;
    if (!signs.includes(sign) || !validDay(date)) return Response.json({error:'Choose a sign and yesterday, today or tomorrow.'},{status:400});
    const key = `${date}:${sign}`;
    if (cache.get(key)?.expires! > Date.now()) return Response.json(cache.get(key)!.value);
    let promise = pending.get(key);
    if (!promise) {
      promise = (async () => {
        const data = await provider('/horoscope/daily/advanced',{datetime:`${date}T12:00:00+05:30`,sign,type:'general,love,career'});
        const row = data.daily_predictions?.find((r: any) => r.sign?.name?.toLowerCase() === sign);
        if (!row || !Array.isArray(row.predictions)) throw Error('Missing prediction');
        const sections = ['General','Love','Career'].map(title => {
          const text = row.predictions.find((r: any) => r.type?.toLowerCase() === title.toLowerCase())?.prediction;
          if (typeof text !== 'string' || !text.trim() || text.length > 10000) throw Error('Missing section');
          return {title,text};
        });
        const value = {date,sign,source:'Prokerala',basis:'General zodiac reading; not a personal birth-chart forecast.',sections};
        if (cache.size >= 72) cache.delete(cache.keys().next().value!);
        cache.set(key,{expires:Date.now()+3600000,value});
        return value;
      })();
      pending.set(key,promise);
    }
    try { return Response.json(await promise); } finally { pending.delete(key); }
  } catch { return Response.json({error:'The daily reading is unavailable right now. Please try again later.'},{status:503}); }
}
export function validBirth(value: any) {
  if (!value || typeof value.datetime !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:00\+05:30$/.test(value.datetime) || !Number.isFinite(Date.parse(value.datetime))) return false;
  const age = (Date.now()-Date.parse(value.datetime))/86400000/365.2425;
  return age >= 18 && age < 130 && value.exactTime === true && Number.isFinite(value.latitude) && Number.isFinite(value.longitude) && value.latitude >= 6 && value.latitude <= 38 && value.longitude >= 68 && value.longitude <= 98;
}
export async function matching(request: Request) {
  try {
    const {boy,girl,consent} = await request.json() as any;
    if (consent !== true || !validBirth(boy) || !validBirth(girl)) return Response.json({error:'Both consenting adults need confirmed birth times and Indian birthplaces for this matching calculation.'},{status:400});
    const data = await provider('/astrology/kundli-matching',{ayanamsa:'1',la:'en',boy_dob:boy.datetime,girl_dob:girl.datetime,boy_coordinates:`${boy.latitude},${boy.longitude}`,girl_coordinates:`${girl.latitude},${girl.longitude}`});
    const score = data.guna_milan;
    if (!score || !Number.isFinite(score.total_points) || score.maximum_points !== 36 || score.total_points < 0 || score.total_points > 36 || typeof data.message?.description !== 'string') throw Error('Invalid matching');
    return Response.json({score:score.total_points,maximum:36,interpretation:data.message.description,source:'Prokerala · Ashta Kuta',note:'This is a traditional chart comparison, not a prediction of relationship success. Consent, trust and communication matter.'});
  } catch { return Response.json({error:'Matching is unavailable right now. No result has been created.'},{status:503}); }
}
