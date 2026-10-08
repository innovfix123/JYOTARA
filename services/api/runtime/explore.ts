import {birthFields, divineData, panchangIntervals} from '../lib/divine-calculations';
import {tamilTranslation} from './discovery';
// Calendar names are a fixed vocabulary, not generated prose. Translate them
// locally so Tamil Panchang does not depend on a second model request.
const tamilCalendarNames: Record<string,string> = {};
tamilCalendarNames['pratipada'] = 'பிரதமை';
tamilCalendarNames['dwitiya'] = 'துவிதியை';
tamilCalendarNames['tritiya'] = 'திருதியை';
tamilCalendarNames['chaturthi'] = 'சதுர்த்தி';
tamilCalendarNames['panchami'] = 'பஞ்சமி';
tamilCalendarNames['shashthi'] = 'சஷ்டி';
tamilCalendarNames['saptami'] = 'சப்தமி';
tamilCalendarNames['ashtami'] = 'அஷ்டமி';
tamilCalendarNames['navami'] = 'நவமி';
tamilCalendarNames['dashami'] = 'தசமி';
tamilCalendarNames['ekadashi'] = 'ஏகாதசி';
tamilCalendarNames['dwadashi'] = 'துவாதசி';
tamilCalendarNames['trayodashi'] = 'திரயோதசி';
tamilCalendarNames['chaturdashi'] = 'சதுர்த்தசி';
tamilCalendarNames['purnima'] = 'பௌர்ணமி';
tamilCalendarNames['amavasya'] = 'அமாவாசை';
tamilCalendarNames['ashwini'] = 'அசுவினி';
tamilCalendarNames['bharani'] = 'பரணி';
tamilCalendarNames['krittika'] = 'கார்த்திகை';
tamilCalendarNames['rohini'] = 'ரோகிணி';
tamilCalendarNames['mrigashira'] = 'மிருகசீரிடம்';
tamilCalendarNames['ardra'] = 'திருவாதிரை';
tamilCalendarNames['punarvasu'] = 'புனர்பூசம்';
tamilCalendarNames['pushya'] = 'பூசம்';
tamilCalendarNames['ashlesha'] = 'ஆயில்யம்';
tamilCalendarNames['magha'] = 'மகம்';
tamilCalendarNames['purvaphalguni'] = 'பூரம்';
tamilCalendarNames['uttaraphalguni'] = 'உத்திரம்';
tamilCalendarNames['hasta'] = 'அஸ்தம்';
tamilCalendarNames['chitra'] = 'சித்திரை';
tamilCalendarNames['swati'] = 'சுவாதி';
tamilCalendarNames['vishakha'] = 'விசாகம்';
tamilCalendarNames['anuradha'] = 'அனுஷம்';
tamilCalendarNames['jyeshtha'] = 'கேட்டை';
tamilCalendarNames['mula'] = 'மூலம்';
tamilCalendarNames['purvaashadha'] = 'பூராடம்';
tamilCalendarNames['uttaraashadha'] = 'உத்திராடம்';
tamilCalendarNames['shravana'] = 'திருவோணம்';
tamilCalendarNames['dhanishta'] = 'அவிட்டம்';
tamilCalendarNames['shatabhisha'] = 'சதயம்';
tamilCalendarNames['purvabhadrapada'] = 'பூரட்டாதி';
tamilCalendarNames['uttarabhadrapada'] = 'உத்திரட்டாதி';
tamilCalendarNames['revati'] = 'ரேவதி';
tamilCalendarNames['vishkambha'] = 'விஷ்கம்பம்';
tamilCalendarNames['priti'] = 'பிரீதி';
tamilCalendarNames['ayushman'] = 'ஆயுஷ்மான்';
tamilCalendarNames['saubhagya'] = 'சௌபாக்கியம்';
tamilCalendarNames['shobhana'] = 'சோபனம்';
tamilCalendarNames['atiganda'] = 'அதிகண்டம்';
tamilCalendarNames['sukarma'] = 'சுகர்மம்';
tamilCalendarNames['dhriti'] = 'திருதி';
tamilCalendarNames['shula'] = 'சூலம்';
tamilCalendarNames['ganda'] = 'கண்டம்';
tamilCalendarNames['vriddhi'] = 'விருத்தி';
tamilCalendarNames['dhruva'] = 'துருவம்';
tamilCalendarNames['vyaghata'] = 'வியாகாதம்';
tamilCalendarNames['harshana'] = 'ஹர்ஷணம்';
tamilCalendarNames['vajra'] = 'வஜ்ரம்';
tamilCalendarNames['siddhi'] = 'சித்தி';
tamilCalendarNames['vyatipata'] = 'வியதீபாதம்';
tamilCalendarNames['variyana'] = 'வரியான்';
tamilCalendarNames['parigha'] = 'பரிகம்';
tamilCalendarNames['shiva'] = 'சிவம்';
tamilCalendarNames['siddha'] = 'சித்தம்';
tamilCalendarNames['sadhya'] = 'சாத்தியம்';
tamilCalendarNames['shubha'] = 'சுபம்';
tamilCalendarNames['shukla'] = 'சுக்கிலம்';
tamilCalendarNames['brahma'] = 'பிரம்மம்';
tamilCalendarNames['indra'] = 'இந்திரம்';
tamilCalendarNames['vaidhriti'] = 'வைதிருதி';
tamilCalendarNames['bava'] = 'பவம்';
tamilCalendarNames['balava'] = 'பாலவம்';
tamilCalendarNames['kaulava'] = 'கௌலவம்';
tamilCalendarNames['taitila'] = 'தைதுலம்';
tamilCalendarNames['garaja'] = 'கரசை';
tamilCalendarNames['vanija'] = 'வணிசை';
tamilCalendarNames['vishti'] = 'பத்திரை';
tamilCalendarNames['shakuni'] = 'சகுனி';
tamilCalendarNames['chatushpada'] = 'சதுஷ்பாதம்';
tamilCalendarNames['naga'] = 'நாகம்';
tamilCalendarNames['kimstughna'] = 'கிம்ஸ்துக்னம்';
tamilCalendarNames['rahukalam'] = 'ராகு காலம்';
tamilCalendarNames['yamagandam'] = 'எமகண்டம்';
tamilCalendarNames['gulikai'] = 'குளிகை';
tamilCalendarNames['brahmamuhurta'] = 'பிரம்ம முகூர்த்தம்';
tamilCalendarNames['abhijitmuhurta'] = 'அபிஜித் முகூர்த்தம்';
tamilCalendarNames['ashleysha'] = 'ஆயில்யம்';
tamilCalendarNames['bav'] = 'பவம்';
// Spellings observed in the provider's live 2026-10-07 response.
tamilCalendarNames['tryodashi'] = 'திரயோதசி';
tamilCalendarNames['gar'] = 'கரசை';
export async function tamilCalendarLabels(names:string[]) {
 const labels=names.map(name=>tamilCalendarNames[name.toLowerCase().replace(/[\s_-]/g,'')]);
 const missing=names.filter((_,i)=>!labels[i]);
 const translated=missing.length ? await tamilTranslation(missing) : [];
 let i=0;
 return labels.map(label=>label ?? translated[i++]);
}
const cache=new Map<string,{until:number,value:any}>();
const pending=new Map<string,Promise<any>>();
export function validCalendarInput(v:any,now=Date.now()) {
 if(!v||typeof v.date!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(v.date))return false;
 const d=Date.parse(v.date+'T12:00:00+05:30');
 return Number.isFinite(d)&&new Date(Date.parse(v.date)).toISOString().slice(0,10)===v.date&&Math.abs(d-now)<367*86400000&&Number.isFinite(v.latitude)&&v.latitude>=6&&v.latitude<=38&&Number.isFinite(v.longitude)&&v.longitude>=68&&v.longitude<=98&&['en','ta'].includes(v.language);
}
export function calendarData(p:any,bad:any,good:any,date:string) {
 const instant=(v:any)=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(v)&&Number.isFinite(Date.parse(v.replace(' ','T')+'+05:30'))?v.replace(' ','T')+'+05:30':null;
 const sunrise=instant(p.sunrise),sunset=instant(p.sunset);
 if(!sunrise||!sunset||!sunrise.startsWith(date)||!sunset.startsWith(date)||Date.parse(sunrise)>=Date.parse(sunset))throw Error('Wrong calendar date');
 const data=panchangIntervals(p,date+'T12:00:00+05:30').data as Record<string, unknown>;
 const timings:any[]=[];
 for(const [name,raw] of [['Rahu Kalam',bad.rahu_kaal],['Yamagandam',bad.yamaganda],['Gulikai',bad.gulkai_kaal],['Brahma Muhurta',good.brahma_muhurta],['Abhijit Muhurta',good.abhijit_muhurta]] as const){
  const start=instant(raw?.start_time),end=instant(raw?.end_time);
  if(start&&end&&start.startsWith(date)&&Date.parse(start)<Date.parse(end))timings.push({name,start,end});
 }
 const stars=(p.nakshatras?.nakshatra_list??[]).filter((r:any)=>typeof r.nak_name==='string').map((r:any)=>({name:r.nak_name,end:instant(r.end_time)}));
 return {date,sunrise,sunset,...data,nakshatra:stars,timings,timezone:'Asia/Kolkata',source:'Divine'};
}
export async function panchang(request:Request){
 try{
  const v:any=await request.json();if(!validCalendarInput(v))return Response.json({error:'Choose an Indian location and a date within one year.'},{status:400});
  const key=JSON.stringify([v.date,v.latitude.toFixed(3),v.longitude.toFixed(3),v.language]);
  if(cache.get(key)?.until!>Date.now())return Response.json(cache.get(key)!.value);
  if(!pending.has(key))pending.set(key,(async()=>{
   let value:any;
   if(v.language==='ta'){
    const response=await panchang(new Request(request.url,{method:'POST',body:JSON.stringify({...v,language:'en'})}));if(!response.ok)throw Error();value=await response.json();
    const rows=['tithi','yoga','karana','nakshatra','timings'].flatMap(k=>value[k]??[]);
    const translated=await tamilCalendarLabels(rows.map(r=>r.name));rows.forEach((r,i)=>r.name=translated[i]);
   }else{
    const config={DIVINE_API_KEY:process.env.DIVINE_API_KEY,DIVINE_ACCESS_TOKEN:process.env.DIVINE_ACCESS_TOKEN};
    const fields=birthFields({datetime:v.date+'T12:00:00+05:30',latitude:v.latitude,longitude:v.longitude});
    const base='https://astroapi-1.divineapi.com/indian-api/';
    const [primary,bad,good]=await Promise.allSettled([divineData(config,base+'v2/find-panchang',fields),divineData(config,base+'v1/inauspicious-timings',fields),divineData(config,base+'v1/auspicious-timings',fields)]);
    if(primary.status!=='fulfilled')throw Error('Panchang provider unavailable');
    value=calendarData(primary.value,bad.status==='fulfilled'?bad.value:{},good.status==='fulfilled'?good.value:{},v.date);
    value.timingsStatus=bad.status==='fulfilled'&&good.status==='fulfilled'?'available':'partial';
   }
   value.language=v.language;if(cache.size>=200)cache.delete(cache.keys().next().value!);cache.set(key,{until:Date.now()+3600000,value});return value;
  })());
  try{return Response.json(await pending.get(key));}finally{pending.delete(key);}
 }catch{return Response.json({error:'Panchang could not be loaded. Please retry later.'},{status:503});}
}
