import type {D1Database} from '@cloudflare/workers-types';
export type MarriageWindow={dasha:string;subDasha:string;start:string;end:string};
export type MarriageReport={module:'favourable-periods:marriage';page:number;pdfSha256:string;windows:MarriageWindow[];calculatedAt:string};
export type ReportPerson={datetime:string;latitude:number;longitude:number;name:string;gender:'male'|'female';place:string};
export function reportPerson(value:unknown):ReportPerson|null {
  if(!value||typeof value!=='object')return null;
  const p=value as ReportPerson;
  if(typeof p.datetime!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?(?:Z|[+-]\d{2}:\d{2})$/.test(p.datetime)||!Number.isFinite(Date.parse(p.datetime)))return null;
  if(!Number.isFinite(p.latitude)||!Number.isFinite(p.longitude)||Math.abs(p.latitude)>90||Math.abs(p.longitude)>180||!['male','female'].includes(p.gender))return null;
  if(typeof p.name!=='string'||!p.name.trim()||p.name.length>60||typeof p.place!=='string'||!p.place.trim()||p.place.length>160)return null;
  return p;
}
export function marriageTimingQuestion(question:string,history:string[]=[],category='') {
  const q=question.toLowerCase();
  const marriage=/marry|married|marriage|wedding|kalyanam|kalyaanam|திருமண|கல்யாண/iu;
  const timing=/20\d{2}|21\d{2}|when|timing|period|date|soon|delay|year|month|next|after|later|miss|eppo|eppa|eppodhu|kaalam|neram|adutha|apram|எப்போது|காலம்|தேதி|தாமத|அடுத்து|பிறகு/iu;
  const otherTopic=/\b(job|career|business|education|exam|study|work)\b|வேலை|தொழில்|படிப்பு/iu;
  if(otherTopic.test(q)&&!marriage.test(q))return false;
  return timing.test(q)&&(marriage.test(q)||category==='Marriage'||history.slice(-3).some(v=>marriage.test(v)&&timing.test(v)));
}
export function parseMarriageReport(text:string,pdfSha256:string,now=new Date()):MarriageReport {
  if(!text.includes('Favourable Marriage Periods')||!text.includes('Dasha Lord')||!text.includes('Sub Dasha Lord'))throw Error('Unrecognised marriage report');
  const pages=text.split('\f');
  const page=pages.findIndex(p=>p.includes('Favourable Marriage Periods'));
  const planet='(Sun|Moon|Mercury|Venus|Mars|Jupiter|Saturn|Rahu|Ketu)';
  const re=new RegExp(planet+'\\s+'+planet+'\\s+(\\d{4}-\\d{2}-\\d{2})\\s+(\\d{4}-\\d{2}-\\d{2})','g');
  const windows=[...text.matchAll(re)].map(m=>({dasha:m[1],subDasha:m[2],start:m[3],end:m[4]}));
  const validDate=(d:string)=>{const n=Date.parse(d+'T00:00:00Z');return Number.isFinite(n)&&new Date(n).toISOString().slice(0,10)===d;};
  if(!/^[a-f0-9]{64}$/.test(pdfSha256)||!windows.length||windows.length>100||windows.some((w,i)=>!validDate(w.start)||!validDate(w.end)||w.end<=w.start||(i>0&&w.start<windows[i-1].end)))throw Error('Invalid marriage report periods');
  return {module:'favourable-periods:marriage',page:page+1,pdfSha256,windows,calculatedAt:now.toISOString()};
}
export function marriageReportReply(report:MarriageReport,style:string,question:string,now=new Date(),history:string[]=[]) {
  const day=new Date(now.getTime()+19800000).toISOString().slice(0,10);
  const requestedYears=[...question.matchAll(/\b(20\d{2}|21\d{2})\b/g)].map(m=>Number(m[1]));
  const year=requestedYears.length===1?requestedYears[0]:undefined;
  const eligible=report.windows.filter(w=>w.end>=day && (year===undefined || (w.start<=`${year}-12-31` && w.end>=`${year}-01-01`)));
  const next=/next|after|later|miss|adutha|apram|அடுத்து|பிறகு/iu.test(question);
  const window=next&&eligible[0]?.start<=day?eligible[1]:eligible[0];
  if(!window)return null;
  const active=window.start<=day;
  const date=(d:string)=>new Intl.DateTimeFormat(style==='tamil'?'ta-IN':'en-GB',{day:'numeric',month:'short',year:'numeric',timeZone:'UTC'}).format(new Date(d+'T12:00:00Z'));
  const range=active?`${style==='tamil'?'இப்போது முதல்':style==='tanglish'?'Ippo irundhu':'now through'} ${date(window.end)}`:`${date(window.start)} – ${date(window.end)}`;
  const answer=style==='tamil'?`உங்கள் ஜாதக அறிக்கை ${range} திருமணப் பேச்சு, நிச்சயதார்த்தம் போன்றவற்றுக்குச் சாதகமான காலமாகக் குறிப்பிடுகிறது. இது பாரம்பரிய வழிகாட்டல்; இந்தக் காலத்தில் திருமணம் உறுதியாக நடக்கும் என்று பொருள் இல்லை. வீட்டில் வரன் பார்க்கத் தொடங்கிவிட்டார்களா?`
    :style==='tanglish'?`Unga birth-chart report-la ${range} kalyana pechu, nichayathartham pondravatrukku saadhagamaana kaalamnu irukku. Idhu paarambariya kurippu; indha kaalathula kalyanam kandippa nadakkumnu artham illa. Veetla varan paarka aarambichutaangala?`
    :`Your birth-chart report lists ${range} as a traditionally favourable window for marriage discussions or engagement. This does not guarantee a wedding in that period. Has your family started looking, or are you already considering someone?`;
  const concise=history.length?answer.replace(/[^.!?।]*[?]$/, '').trim():answer;
  return {answer:concise,window,evidence:[`Birth chart · Favourable Marriage Periods · page ${report.page}`,`${window.dasha} / ${window.subDasha}: ${window.start} to ${window.end}`],source:{module:report.module,page:report.page,pdfSha256:report.pdfSha256,calculatedAt:report.calculatedAt,window}};
}
export async function verifiedReportPerson(db:D1Database,person:ReportPerson,session:string,profileId:string,location:{latitude:number;longitude:number}|undefined,deps:{hash:(values:unknown[])=>Promise<string>;open:(id:string,ciphertext:string)=>Promise<unknown>}) {
  if(!location||person.latitude!==location.latitude||person.longitude!==location.longitude)return false;
  // Legacy and current profiles are bound to the original encrypted successful
  // chart receipt. Caller birth data alone never authorises a paid report.
  for(const la of ['en','ta']) {
    const hash=await deps.hash([person.datetime,person.latitude,person.longitude,true,la]);
    const row=await db.prepare('SELECT id,response_ciphertext FROM profile_generations WHERE session_id=? AND request_hash=? AND status=? AND response_expires_at>? ORDER BY created_at DESC LIMIT 1')
      .bind(session,hash,'success',Date.now()).first<{id:string;response_ciphertext:string|null}>();
    if(!row?.response_ciphertext)continue;
    const reply=await deps.open(`profile:${row.id}`,row.response_ciphertext).catch(()=>null) as {profileId?:string}|null;
    if(reply?.profileId===profileId)return true;
  }
  return false;
}
export async function loadMarriageReport(db:D1Database,person:ReportPerson,input:{id:string;session:string;profile:string;expiresAt:number},deps:{fetch:(params:URLSearchParams)=>Promise<Response>;extract:(pdf:Uint8Array)=>Promise<string>;seal:(value:unknown)=>Promise<string>;open:(value:string)=>Promise<unknown>}) {
  await db.prepare('DELETE FROM provider_reports WHERE expires_at<=?').bind(Date.now()).run();
  const cached=await db.prepare('SELECT status,response_ciphertext FROM provider_reports WHERE id=?').bind(input.id).first<{status:string;response_ciphertext:string|null}>();
  if(cached){
    if(cached.status!=='ready'||!cached.response_ciphertext)return {status:'unavailable' as const,cached:true};
    return {status:'ready' as const,cached:true,report:await deps.open(cached.response_ciphertext) as MarriageReport};
  }
  const day=new Date(Date.now()+19800000).toISOString().slice(0,10);
  const claim=await db.prepare("INSERT OR IGNORE INTO provider_reports (id,session_id,profile_id,day_key,status,expires_at) SELECT ?,?,?,?,'pending',? WHERE (SELECT COUNT(*) FROM provider_reports WHERE day_key=?)<3 AND NOT EXISTS (SELECT 1 FROM deleted_chart_sessions WHERE session_id=? AND expires_at>?)")
    .bind(input.id,input.session,input.profile,day,input.expiresAt,day,input.session,Date.now()).run();
  if(claim.meta.changes!==1)return {status:'limit' as const,cached:false};
  try {
    const params=new URLSearchParams();
    const flatten=(v:unknown,k:string)=>{if(v&&typeof v==='object')for(const [a,b]of Object.entries(v))flatten(b,`${k}[${a}]`);else params.append(k,String(v));};
    flatten({first_name:person.name,gender:person.gender,datetime:person.datetime,coordinates:`${person.latitude},${person.longitude}`,place:person.place},'input');
    flatten({modules:[{name:'favourable-periods',options:{period_type:'marriage'}}],template:{style:'basic',footer:'Jyotara'},report:{name:'Marriage periods',caption:'Traditional astrology report',brand_name:'Jyotara',la:'en'}},'options');
    const response=await deps.fetch(params);
    if(!response.ok||!response.headers.get('content-type')?.includes('application/pdf'))throw Error('Report unavailable');
    const length=Number(response.headers.get('content-length')??0);
    if(length>5_000_000)throw Error('Report too large');
    const bytes=new Uint8Array(await response.arrayBuffer());
    if(bytes.length>5_000_000)throw Error('Report too large');
    const hash=await crypto.subtle.digest('SHA-256',bytes).then(v=>Array.from(new Uint8Array(v),b=>b.toString(16).padStart(2,'0')).join(''));
    const report=parseMarriageReport(await deps.extract(bytes),hash);
    const saved=await db.prepare("UPDATE provider_reports SET status='ready',response_ciphertext=? WHERE id=? AND status='pending'").bind(await deps.seal(report),input.id).run();
    if(saved.meta.changes!==1)return {status:'unavailable' as const,cached:false};
    return {status:'ready' as const,cached:false,report};
  }catch{
    await db.prepare("UPDATE provider_reports SET status='unavailable' WHERE id=? AND status='pending'").bind(input.id).run();
    return {status:'unavailable' as const,cached:false};
  }
}
