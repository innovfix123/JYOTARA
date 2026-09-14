import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {moduleFor} from './helpers/load.mjs';
const c=await import(moduleFor('../lib/divine-calculations.ts'));
const {normalizeProviderChart,normalizeProviderNavamsa}=await import(moduleFor('../lib/provider-chart.ts'));
const fixture=name=>JSON.parse(fs.readFileSync(new URL('./fixtures/divine/'+name+'.json',import.meta.url)));
const birth={datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707};
test('Divine natal identity, sign-only D9 and dated dashas retain exact provider facts',()=>{
 const planet=fixture('planets').data;
 const navamsa=c.navamsaPositions(fixture('d9').data);
 const payload={sandbox:false,result:c.identity(planet),planetPosition:c.positions(planet),dashaPeriods:c.dashaPeriods(fixture('dasha').data,'+05:30'),navamsa};
 const chart=normalizeProviderChart(payload,true,new Date('2026-09-14T12:00:00+05:30'));
 assert.equal(chart.rashi,'Kumbha');assert.equal(chart.lagna,'Mithuna');assert.equal(chart.nakshatra,'Dhanishtha');
 assert.equal(chart.currentDasha.name,'Jupiter');assert.equal(chart.currentAntardasha.name,'Mercury');
 assert.equal(chart.navamsa.length,9);assert.equal(chart.navamsa.find(p=>p.name==='Moon').position,8);
 assert.ok(chart.navamsa.every(p=>p.degree===undefined),'no invented divisional degree');
 const unknown=normalizeProviderChart(payload,false,new Date('2026-09-14T12:00:00+05:30'));
 assert.equal(unknown.lagna,undefined);assert.equal(unknown.navamsa,undefined);assert.equal(unknown.currentDasha,undefined);
 const bad=structuredClone(navamsa);bad.data.divisional_positions[0].planet_positions[0].sign_degree=NaN;
 assert.equal(normalizeProviderNavamsa(bad,true),undefined);
});
test('invalid, contradictory or duplicate Divine planet data fails before chart issuance',()=>{
 for(const edit of [d=>d.planets[0].sign_no=12,d=>d.planets[0].full_degree='NaN',d=>d.planets.push(d.planets[0]),d=>d.planets=d.planets.filter(p=>p.name!=='Moon')]){
  const d=fixture('planets').data;edit(d);assert.throws(()=>c.positions(d));
 }
});
test('Divine chart transport uses only approved endpoints, preserves birth offset and never retries',async()=>{
 const old=globalThis.fetch;const calls=[];let fail=false;
 globalThis.fetch=async(url,opts)=>{
  calls.push(url);assert.match(url,/^https:\/\/astroapi-[135]\.divineapi\.com\//);assert.equal(opts.method,'POST');assert.equal(opts.body.get('hour'),'6');assert.equal(opts.body.get('min'),'20');assert.equal(opts.body.get('tzone'),'5.5');
  if(fail)throw Error('timeout');
  const name=url.includes('planetary')?'planets':url.includes('vimshottari')?'dasha':url.endsWith('/D9')?'d9':'manglik';return Response.json(fixture(name));
 };
 try{
  const charges=[];const result=await c.divineChart({DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test'},birth,true,charges);
  assert.equal(calls.length,4);assert.ok(result.navamsa);assert.ok(result.dashaPeriods);assert.ok(charges.every(c=>c.provider==='divine'&&c.status==='received'&&c.actualCredits===null));
  calls.length=0;await c.divineChart({DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test'},birth,false);assert.equal(calls.length,1);
  fail=true;calls.length=0;await assert.rejects(c.divineChart({DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test'},birth,true));assert.equal(calls.length,1);
 }finally{globalThis.fetch=old;}
});
test('Panchang omits unknown intervals instead of inventing their boundaries',()=>{
 const p=c.panchangIntervals(fixture('panchang').data,'2026-09-14T12:00:00+05:30').data;
 assert.equal(p.tithi[1].name,'Chaturthi');assert.equal(p.tithi[1].start,'2026-09-14T07:08:01+05:30');
 assert.equal(p.nakshatra.length,1);assert.equal(p.nakshatra[0].name,'Chitra');
});
