import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {moduleFor} from './helpers/load.mjs';
const {openChartTicket}=await import(moduleFor('../lib/chart-ticket.ts'));
test('Divine chart identity, recovery, overview and unknown-time flow stay protected',async()=>{
 const db=new DatabaseSync(':memory:');
 for(const name of ['0000_perpetual_giant_man','0001_chilly_purple_man','0002_broad_spacker_dave','0003_reflective_betty_ross','0004_powerful_juggernaut','0007_cold_inhumans','0008_damp_marvex','0009_salty_skrulls','0010_green_johnny_blaze','0011_report_evidence','0013_divine_cleanup'])db.exec(fs.readFileSync(new URL('../drizzle/'+name+'.sql',import.meta.url),'utf8'));
 const secret='aa'.repeat(32),old=globalThis.fetch;let calls=0;
 globalThis.__divineTestEnv={JYOTARA_CHART_TICKET_KEY:secret,DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test',DB:{prepare(sql){let args=[];return{bind(...v){args=v;return this;},async first(){return db.prepare(sql).get(...args)||null;},async run(){return{meta:{changes:Number(db.prepare(sql).run(...args).changes)}};}};}}};
 globalThis.fetch=async(url,opts)=>{
  calls++;assert.match(url,/^https:\/\/astroapi-[13]\.divineapi\.com\//);
  const name=url.includes('planetary')?'planets':url.includes('vimshottari')?'dasha':url.endsWith('/D9')?'d9':url.includes('panchang')?'panchang':'manglik';
  return Response.json(JSON.parse(fs.readFileSync(new URL('./fixtures/divine/'+name+'.json',import.meta.url))));
 };
 try{
  const {POST}=await import(moduleFor('../app/api/astrology/kundli/route.ts'));
  const body={datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707,birthTimeKnown:true,language:'en'};
  const send=(b,session='owner')=>POST(new Request('https://test',{method:'POST',headers:{cookie:'nirayana_pilot_session='+session},body:JSON.stringify(b)}));
  const response=await send(body);assert.equal(response.status,200,await response.clone().text());const first=await response.json();
  assert.equal(first.provider,'divine');assert.equal(first.sandbox,false);assert.equal(calls,6);
  const trusted=await openChartTicket(secret,first.chartTicket,'owner',first.profileId);
  assert.equal(trusted.chart.rashi,'Kumbha');assert.equal(trusted.chart.navamsa.length,9);
  assert.equal(trusted.birthDatetime,body.datetime);assert.equal(trusted.contextLocation.latitude,body.latitude);
  const replay=await (await send(body)).json();assert.equal(replay.profileRecovered,true);assert.equal(replay.chartTicket,first.chartTicket);assert.equal(calls,6);
  assert.equal((await send({...body,latitude:999})).status,400);assert.equal(calls,6);
  const {POST:chat}=await import(moduleFor('../app/api/guidance/route.ts'));
  const intro=await chat(new Request('https://test',{method:'POST',headers:{cookie:'nirayana_pilot_session=owner'},body:JSON.stringify({requestId:'overview-valid-0001',profileId:first.profileId,chartTicket:first.chartTicket,category:'Daily',language:'en',responseStyle:'english',question:'Show the selected profile rasi, nakshatra and current Saturn status.',chart:{rashi:'Mesha'}})}));
  const reading=await intro.json();assert.equal(intro.status,200);assert.match(reading.answer,/Kumbha/);assert.doesNotMatch(reading.answer,/Mesha/);assert.equal(calls,6);
  const unknown=await (await send({...body,birthTimeKnown:false},'unknown-owner')).json();assert.ok(unknown.moduleStatus,JSON.stringify(unknown));assert.equal(unknown.moduleStatus.navamsa,'not-requested-unknown-time');assert.equal(calls,7);
 }finally{globalThis.fetch=old;delete globalThis.__divineTestEnv;db.close();}
});
