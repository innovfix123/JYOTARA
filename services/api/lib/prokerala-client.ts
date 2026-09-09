import type { D1Database } from '@cloudflare/workers-types';
type Credentials = { PROKERALA_CLIENT_ID?: string; PROKERALA_CLIENT_SECRET?: string; DB?: D1Database };
export type ProviderCharge = {module:string; expectedCredits:number; actualCredits:number|null; status:string; httpStatus?:number};
export type ProviderAudit = {requestId:string; sessionId:string; charges?:ProviderCharge[]};
export async function meteredProkeralaFetch(credentials:Credentials, path:string, params:URLSearchParams, expectedCredits:number, audit?:ProviderAudit) {
  if(credentials.DB && audit)await credentials.DB.prepare('DELETE FROM provider_usage WHERE created_at<?').bind(Date.now()-30*86400000).run();
  const id=crypto.randomUUID(), charge:ProviderCharge={module:path,expectedCredits,actualCredits:null,status:'started'};
  if(credentials.DB && audit) await credentials.DB.prepare('INSERT INTO provider_usage (id,request_id,session_id,module,status,expected_credits,created_at) VALUES (?,?,?,?,?,?,?)')
    .bind(id,audit.requestId,audit.sessionId,path,'started',expectedCredits,Date.now()).run();
  const save=async()=>{
    audit?.charges?.push({...charge});
    if(credentials.DB && audit) await credentials.DB.prepare('UPDATE provider_usage SET status=?,http_status=?,actual_credits=? WHERE id=?')
      .bind(charge.status,charge.httpStatus??null,charge.actualCredits,id).run();
  };
  let response:Response;
  try {
    const token=await prokeralaToken(credentials);
    response=await fetch('https://api.prokerala.com/v2'+path+'?'+params,{signal:AbortSignal.timeout(path.startsWith('/report/')?25000:12000),redirect:'manual',headers:{Authorization:'Bearer '+token}});
    charge.httpStatus=response.status;
    const reported=response.headers.get('x-api-credits');
    charge.actualCredits=reported!==null && /^\d+$/.test(reported) && Number.isSafeInteger(Number(reported)) ? Number(reported):null;
    charge.status=response.ok?'received':'provider_error';
  } catch(error) { charge.status='unknown'; await save(); throw error; }
  await save();
  return response;
}

let cached: { id: string; value: string; expiresAt: number } | null = null;
let pending: { id: string; promise: Promise<string> } | null = null;

export async function prokeralaToken(credentials: Credentials): Promise<string> {
  const id = credentials.PROKERALA_CLIENT_ID;
  const secret = credentials.PROKERALA_CLIENT_SECRET;
  if (!id || !secret) throw new Error('Prokerala credentials are not configured');
  if (cached?.id === id && cached.expiresAt > Date.now() + 60_000) return cached.value;
  if (pending?.id === id) return pending.promise;
  const promise = (async () => {
    const response = await fetch('https://api.prokerala.com/token', {
      method: 'POST', signal: AbortSignal.timeout(10_000), redirect: 'manual',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'client_credentials', client_id: id, client_secret: secret }),
    });
    if (!response.ok) throw new Error('Calculation service authentication failed');
    const data = await response.json() as { access_token?: unknown; expires_in?: unknown };
    if (typeof data.access_token !== 'string' || !data.access_token || typeof data.expires_in !== 'number' || !Number.isFinite(data.expires_in) || data.expires_in <= 0) throw new Error('Invalid calculation service token');
    cached = { id, value: data.access_token, expiresAt: Date.now() + data.expires_in * 1000 };
    return data.access_token;
  })();
  pending = { id, promise };
  try { return await promise; } finally { if (pending?.promise === promise) pending = null; }
}

export async function prokeralaJson(credentials: Credentials, path: string, input: {
  datetime: string; latitude: number; longitude: number; language?: string;
}, audit?:ProviderAudit) {
  const url = new URL(`https://api.prokerala.com/v2${path}`);
  url.searchParams.set('ayanamsa', '1');
  url.searchParams.set('coordinates', `${input.latitude},${input.longitude}`);
  url.searchParams.set('datetime', input.datetime);
  url.searchParams.set('la', input.language === 'ta' ? 'ta' : 'en');
  // Only the explicitly selected D9 module is supported here. The app cannot
  // choose arbitrary divisional charts or cause an additional request.
  if (path === '/astrology/divisional-planet-position') url.searchParams.set('chart_type', 'navamsa');
  const costs:Record<string,number>={'/astrology/kundli/advanced':300,'/astrology/planet-position':30,'/astrology/panchang':10,'/astrology/dasha-periods':200,'/astrology/divisional-planet-position':50};
  const response = await meteredProkeralaFetch(credentials,path,url.searchParams,(costs[path]??0)*(input.language==='ta'?2:1),audit);
  if (!response.ok) throw new Error('Calculation service is unavailable');
  const data: unknown = await response.json();
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      !('data' in data) || data.data === null || typeof data.data !== 'object' ||
      ('status' in data && data.status === 'error')) {
    throw new Error('Invalid calculation service response');
  }
  return data;
}
