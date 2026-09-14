/** Divine calculation adapter. The output retains Jyotara's saved-chart schema.
 * Provider fields are validated before issuing authenticated chart tickets.
 * Docs: developers.divineapi.com/openapi.yaml, verified 2026-09-14. */
export type CalculationConfig = {DIVINE_API_KEY?:string; DIVINE_ACCESS_TOKEN?:string};
export type CalculationCharge = {module:string;provider:'divine';expectedCredits:number|null;actualCredits:number|null;status:string;httpStatus?:number};
export type BirthInput = {datetime:string;latitude:number;longitude:number};
const base='https://astroapi-3.divineapi.com/indian-api/';
export const signNames=['Mesha','Vrishabha','Mithuna','Karka','Simha','Kanya','Tula','Vrischika','Dhanu','Makara','Kumbha','Meena'];
const english=['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces'];
const lords=['Mars','Venus','Mercury','Moon','Sun','Mercury','Venus','Mars','Jupiter','Saturn','Saturn','Jupiter'];
const planetIds:Record<string,number>={Sun:0,Moon:1,Mercury:2,Venus:3,Mars:4,Jupiter:5,Saturn:6,Ascendant:100,Rahu:101,Ketu:102};
const ok=(data:unknown)=>({status:'ok',provider:'divine',data});
const text=(v:unknown):string=>{if(typeof v!=='string'||!v.trim()||v.length>10000)throw Error('Incomplete calculation response');return v;};
export function birthFields(input:BirthInput) {
  // Preserve the offset in supplied birth details. UTC context is converted to IST.
  const m=input.datetime.match(/(Z|([+-])(\d{2}):(\d{2}))$/);
  if(!m||!Number.isFinite(Date.parse(input.datetime)))throw Error('Invalid birth date');
  const minutes=m[1]==='Z'?330:(m[2]==='-'?-1:1)*(Number(m[3])*60+Number(m[4]));
  const d=new Date(Date.parse(input.datetime)+minutes*60000);
  return {full_name:'Saved profile',place:'Selected birthplace',gender:'male',year:d.getUTCFullYear(),month:d.getUTCMonth()+1,day:d.getUTCDate(),hour:d.getUTCHours(),min:d.getUTCMinutes(),sec:d.getUTCSeconds(),lat:input.latitude,lon:input.longitude,tzone:minutes/60,lan:'en'};
}
export async function divineData(config:CalculationConfig,url:string,fields:Record<string,unknown>,charges:CalculationCharge[]=[]) {
  if(!config.DIVINE_API_KEY||!config.DIVINE_ACCESS_TOKEN)throw Error('Calculation service is not configured');
  const u=new URL(url);
  if(!['astroapi-3.divineapi.com','astroapi-1.divineapi.com','astroapi-5.divineapi.com'].includes(u.hostname)||u.protocol!=='https:')throw Error('Unsupported calculation endpoint');
  const charge:CalculationCharge={module:u.pathname,provider:'divine',expectedCredits:null,actualCredits:null,status:'started'};
  charges.push(charge);
  try {
    const body=new URLSearchParams(Object.entries({...fields,api_key:config.DIVINE_API_KEY}).map(([k,v])=>[k,String(v)]));
    const r=await fetch(url,{method:'POST',body,headers:{Authorization:`Bearer ${config.DIVINE_ACCESS_TOKEN}`},signal:AbortSignal.timeout(18000),redirect:'error'});
    charge.httpStatus=r.status;
    if(!r.ok){charge.status='provider_error';throw Error('Calculation service is unavailable');}
    const data:any=await r.json();
    if(data.success!==1||!data.data||typeof data.data!=='object'){charge.status='provider_error';throw Error('Calculation service is unavailable');}
    // Never substitute an assumed credit price when this endpoint supplies none.
    charge.status='received';
    return data.data;
  }catch{if(charge.status==='started')charge.status='unknown';throw Error('Calculation service is unavailable');}
}
export function positions(data:any) {
  if(!Array.isArray(data?.planets))throw Error('Missing planets');
  const seen=new Set<string>();
  const rows=data.planets.filter((p:any)=>Object.hasOwn(planetIds,p.name)).map((p:any)=>{
    const n=p.sign_no,degree=Number(p.full_degree);
    if(seen.has(p.name)||!Number.isInteger(n)||n<1||n>12||p.sign!==english[n-1]||!Number.isFinite(degree)||degree<0||degree>=360||Math.floor(degree/30)!==n-1||!['true','false',true,false].includes(p.is_retro))throw Error('Invalid planet position');
    seen.add(p.name);
    return {id:planetIds[p.name],name:p.name,rasi:{id:n-1,name:signNames[n-1],lord:{name:lords[n-1]}},position:n,degree:degree%30,is_retrograde:p.is_retro==='true'||p.is_retro===true};
  });
  if(rows.length!==10)throw Error('Incomplete planets');
  return ok({planet_position:rows});
}
export function identity(data:any) {
  positions(data);
  const moon=data.planets.find((p:any)=>p.name==='Moon');
  if(!Number.isInteger(moon.nakshatra_pada)||moon.nakshatra_pada<1||moon.nakshatra_pada>4)throw Error('Invalid birth star');
  return ok({nakshatra_details:{chandra_rasi:{name:signNames[moon.sign_no-1],lord:{name:lords[moon.sign_no-1]}},nakshatra:{name:text(moon.nakshatra),lord:{name:text(moon.nakshatra_lord)},pada:moon.nakshatra_pada}}});
}
export function dashaPeriods(data:any,offset:string) {
  const date=(v:unknown)=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)?v+'T00:00:00'+offset:null;
  if(!data.maha_dasha||typeof data.maha_dasha!=='object')throw Error('Missing dasha');
  const rows=Object.entries(data.maha_dasha).map(([name,v]:[string,any])=>({name,start:date(v.start_date),end:date(v.end_date),antardasha:Object.entries(v.antar_dasha??{}).map(([name,a]:[string,any])=>({name,start:date(a.start_time),end:date(a.end_time)})).filter(a=>a.start&&a.end)}));
  if(rows.some(r=>!r.start||!r.end||Date.parse(r.start)>=Date.parse(r.end)))throw Error('Invalid dasha');
  return ok({dasha_periods:rows});
}
export function navamsaPositions(data:any) {
  const groups=Object.values(data.data??{}) as any[];
  if(groups.length!==12)throw Error('Invalid Navamsa');
  const signs=new Set<number>(),seen=new Set<string>();
  const result=groups.map(g=>{
    const n=g.sign_no;if(!Number.isInteger(n)||n<1||n>12||signs.has(n)||!Array.isArray(g.planet))throw Error('Invalid Navamsa');signs.add(n);
    const rasi={id:n-1,name:signNames[n-1]};
    return {rasi,planet_positions:g.planet.filter((p:any)=>Object.hasOwn(planetIds,p.name)).map((p:any)=>{
      if(seen.has(p.name))throw Error('Duplicate Navamsa planet');seen.add(p.name);
      // This endpoint returns signs, not divisional degrees. Do not invent a degree.
      return {planet:{id:planetIds[p.name],name:p.name},rasi};
    })};
  });
  if(seen.size!==10)throw Error('Incomplete Navamsa');
  return {...ok({divisional_positions:result}),degreePrecision:'sign-only'};
}
export function panchangIntervals(data:any,datetime:string) {
  const offset=datetime.endsWith('Z')?'+05:30':datetime.slice(-6);
  const date=(v:unknown)=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(v)?v.replace(' ','T')+offset:null;
  const intervals=(rows:any,key:string)=>Array.isArray(rows)?rows.flatMap(r=>{
    const start=date(r.start_time),end=date(r.end_time);
    return start&&end&&typeof r[key]==='string'&&Date.parse(start)<Date.parse(end)?[{name:r[key],start,end}]:[];
  }):[];
  // No invented end time for a trailing star. Missing intervals remain absent.
  let start=date(data.sunrise);
  const stars=(data.nakshatras?.nakshatra_list??[]).flatMap((r:any)=>{const end=date(r.end_time),s=start;start=end;return s&&end&&Date.parse(s)<Date.parse(end)?[{name:text(r.nak_name),start:s,end}]:[];});
  return ok({tithi:intervals(data.tithis,'tithi'),yoga:intervals(data.yogas,'yoga_name'),karana:intervals(data.karnas,'karana_name'),nakshatra:stars});
}
export async function divineContext(config:CalculationConfig,module:'transit'|'panchang',input:BirthInput,charges:CalculationCharge[]=[]) {
  const fields=birthFields(input);
  return module==='transit'?positions(await divineData(config,base+'v2/planetary-positions',fields,charges)):
    panchangIntervals(await divineData(config,'https://astroapi-1.divineapi.com/indian-api/v2/find-panchang',fields,charges),input.datetime);
}
export async function divineChart(config:CalculationConfig,input:BirthInput,known:boolean,charges:CalculationCharge[]=[]) {
  const fields=birthFields(input);
  const planets=await divineData(config,base+'v2/planetary-positions',fields,charges);
  const result=identity(planets);
  const planetPosition=positions(planets);
  const [dasha,d9,mangal]=await Promise.allSettled(known?[
    divineData(config,base+'v1/vimshottari-dasha',{...fields,dasha_type:'antar-dasha'},charges).then(d=>dashaPeriods(d,input.datetime.endsWith('Z')?'+05:30':input.datetime.slice(-6))),
    divineData(config,base+'v1/horoscope-chart/D9',fields,charges).then(navamsaPositions),
    divineData(config,base+'v2/manglik-dosha',fields,charges),
  ]:[]);
  if(mangal?.status==='fulfilled'&&['Yes','No'].includes(mangal.value.manglik_dosha))Object.assign(result.data as object,{mangal_dosha:{has_dosha:mangal.value.manglik_dosha==='Yes',description:mangal.value.manglik_dosha==='Yes'?'Manglik condition identified in this traditional calculation.':'No Manglik condition identified in this traditional calculation.'}});
  return {result,planetPosition,dashaPeriods:dasha?.status==='fulfilled'?dasha.value:null,navamsa:d9?.status==='fulfilled'?d9.value:null};
}
export async function divineMatch(config:CalculationConfig,boy:BirthInput,girl:BirthInput) {
  const fields={...Object.fromEntries(Object.entries(birthFields(boy)).filter(([k])=>k!=='lan').map(([k,v])=>['p1_'+k,v])),...Object.fromEntries(Object.entries({...birthFields(girl),gender:'female'}).filter(([k])=>k!=='lan').map(([k,v])=>['p2_'+k,v])),lan:'en'};
  const d=await divineData(config,base+'v2/ashtakoot-milan',fields);
  const keys=['varna','vashya','tara','yoni','graha_maitri','gana','bhakoota','nadi'];
  const summary=d.ashtakoot_milan_result;
  const guna=keys.map((k,i)=>({id:i+1,maximum_points:d.ashtakoot_milan?.[k]?.max_ponits,obtained_points:d.ashtakoot_milan?.[k]?.points_obtained}));
  const dosha=(v:unknown)=>v==='true'||v==='false'?{has_dosha:v==='true'}:null;
  return {guna_milan:{total_points:summary?.points_obtained,maximum_points:summary?.max_ponits,guna},message:{description:summary?.content},boy_mangal_dosha_details:dosha(d.manglik_dosha?.p1),girl_mangal_dosha_details:dosha(d.manglik_dosha?.p2)};
}
