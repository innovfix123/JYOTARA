import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile=text=>ts.transpileModule(text,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const url=text=>`data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const evidence=url(compile(readFileSync(new URL('../lib/astrology-evidence.ts',import.meta.url),'utf8')));
const {validDashaTimeline,selectDashaTimeline,buildEvidencePacket,isValidChartFacts}=await import(evidence);
const {issueChartTicket,openChartTicket}=await import(url(compile(readFileSync(new URL('../lib/chart-ticket.ts',import.meta.url),'utf8')).replace('./astrology-evidence',evidence)));
const p=(name,start,end)=>({name,start,end});
const a='2026-01-01T00:00:00Z', b='2026-09-08T00:00:00Z', c='2026-12-01T00:00:00Z',d='2027-01-01T00:00:00Z';
const timeline=[{...p('Mercury',a,c),antardasha:[p('Venus',a,b),p('Sun',b,c)]},{...p('Ketu',c,d),antardasha:[p('Moon',c,d)]}];
const chart={rashi:'Meena',nakshatra:'Revati',planets:[],yogas:[],currentDasha:p('Mercury',a,c),currentAntardasha:p('Venus',a,b),dashaTimeline:timeline};
test('saved provider intervals change exactly at child and parent boundaries',()=>{
  assert.equal(validDashaTimeline(timeline),true);
  assert.equal(selectDashaTimeline(timeline,Date.parse(b)-1).currentAntardasha.name,'Venus');
  assert.equal(selectDashaTimeline(timeline,Date.parse(b)).currentAntardasha.name,'Sun');
  assert.deepEqual(selectDashaTimeline(timeline,Date.parse(c)),{currentDasha:p('Ketu',c,d),currentAntardasha:p('Moon',c,d)});
  assert.deepEqual(selectDashaTimeline(timeline,Date.parse(d)),{});
  assert.deepEqual(selectDashaTimeline(timeline,Date.parse(a)-1),{});
});
test('gaps are not filled and malformed/overlapping timelines are rejected',()=>{
  const gapped=[{...timeline[0],antardasha:[p('Venus',a,b)]}];
  assert.equal(selectDashaTimeline(gapped,Date.parse(b)).currentAntardasha,undefined);
  for(const invalid of [[], [...timeline,timeline[0]], [{...timeline[0],antardasha:[...timeline[0].antardasha,p('Mars',a,b)]}], [{...timeline[0],antardasha:[p('Mars',a,d)]}], [{...timeline[0],start:'2026-02-30T00:00:00Z'}]]){
    assert.equal(validDashaTimeline(invalid),false);
    assert.equal(isValidChartFacts({...chart,dashaTimeline:invalid}),false);
    assert.deepEqual(selectDashaTimeline(invalid,Date.parse(b)),{});
  }
});
test('guidance uses the server clock and unknown time still withholds periods',()=>{
  const packet=(known)=>buildEvidencePacket({category:'Career',question:'What should I focus on?',language:'en',birthTimeKnown:known,chart,now:new Date(b)});
  assert.equal(packet(true).facts.find(f=>f.field==='antardasha').value,'Sun');
  assert.equal(packet(false).facts.some(f=>f.field==='mahadasha'||f.field==='antardasha'),false);
});
test('timeline stays inside the same authenticated profile ticket',async()=>{
  const now=Date.parse(b),key='ab'.repeat(32);
  const token=await issueChartTicket(key,{sessionId:'timeline-test',profileId:'profile-test',birthTimeKnown:true,chart},now);
  const opened=await openChartTicket(key,token,'timeline-test','profile-test',now);
  assert.deepEqual(opened.chart.dashaTimeline,timeline);
  assert.equal(selectDashaTimeline(opened.chart.dashaTimeline,now).currentAntardasha.name,'Sun');
  assert.equal(await openChartTicket(key,token,'timeline-test','wrong-profile',now),null);
});
