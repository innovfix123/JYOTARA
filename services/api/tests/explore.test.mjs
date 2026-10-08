import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {moduleFor} from './helpers/load.mjs';
const {validCalendarInput,calendarData,tamilCalendarLabels,panchang}=await import(moduleFor('../runtime/explore.ts'));
const now=Date.parse('2026-09-14T12:00:00+05:30');
test('calendar bounds reject impossible dates, unsupported locations and excessive horizon',()=>{
 const v={date:'2026-09-14',latitude:13.08,longitude:80.27,language:'en'};
 assert.equal(validCalendarInput(v,now),true);
 for(const change of [{date:'2026-02-30'},{date:'2028-09-14'},{latitude:NaN},{longitude:0},{language:'xx'}])assert.equal(validCalendarInput({...v,...change},now),false);
});
test('calendar uses provider intervals and leaves missing nakshatra boundary unknown',()=>{
 const p=JSON.parse(fs.readFileSync(new URL('./fixtures/divine/panchang.json',import.meta.url))).data;
 p.sunrise='2026-09-14 06:00:00';p.sunset='2026-09-14 18:00:00';
 p.nakshatras={nakshatra_list:[{nak_name:'Chitra',end_time:''}]};
 const r=calendarData(p,{rahu_kaal:{start_time:'2026-09-14 07:30:00',end_time:'2026-09-14 09:00:00'}},{abhijit_muhurta:[]},'2026-09-14');
 assert.equal(r.nakshatra[0].end,null);assert.equal(r.timings.length,1);
 assert.equal(r.timings[0].start,'2026-09-14T07:30:00+05:30');
 assert.throws(()=>calendarData(p,{}, {},'2026-09-15'));
});

test('Tamil calendar vocabulary loads without an AI translation request',async()=>{
 const old=globalThis.fetch;
 globalThis.fetch=async()=>{throw Error('No model request expected');};
 try {assert.deepEqual(await tamilCalendarLabels(['Dashami','Ekadashi','Pushya','Ashleysha','Shiva','Vanija','Vishti','Bav','Rahu Kalam','Brahma Muhurta','Tryodashi','Gar']),['தசமி','ஏகாதசி','பூசம்','ஆயில்யம்','சிவம்','வணிசை','பத்திரை','பவம்','ராகு காலம்','பிரம்ம முகூர்த்தம்','திரயோதசி','கரசை']);}
 finally{globalThis.fetch=old;}
});
test('optional timings outage keeps the selected date Panchang usable in Tamil',async()=>{
 const old=globalThis.fetch;
 const key=process.env.DIVINE_API_KEY,token=process.env.DIVINE_ACCESS_TOKEN;
 process.env.DIVINE_API_KEY='fixture';process.env.DIVINE_ACCESS_TOKEN='fixture';
 let calls=0;
 const date=new Date().toISOString().slice(0,10);
 globalThis.fetch=async url=>{
  calls++;
  if(!String(url).includes('find-panchang'))return Response.json({success:0},{status:503});
  return Response.json({success:1,data:{sunrise:date+' 06:00:00',sunset:date+' 18:00:00',tithis:[{tithi:'Dashami',start_time:date+' 03:00:00',end_time:date+' 20:00:00'}],nakshatras:{nakshatra_list:[{nak_name:'Pushya',end_time:''}]}}});
 };
 try{
  const response=await panchang(new Request('https://example.test/panchang',{method:'POST',body:JSON.stringify({date,latitude:11.235,longitude:78.881,language:'ta'})}));
  assert.equal(response.status,200);
  const result=await response.json();assert.equal(result.date,date);assert.equal(result.tithi[0].name,'தசமி');assert.equal(result.timingsStatus,'partial');assert.deepEqual(result.timings,[]);assert.equal(calls,3);
 }finally{globalThis.fetch=old;if(key===undefined)delete process.env.DIVINE_API_KEY;else process.env.DIVINE_API_KEY=key;if(token===undefined)delete process.env.DIVINE_ACCESS_TOKEN;else process.env.DIVINE_ACCESS_TOKEN=token;}
});
