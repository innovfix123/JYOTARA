import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';
const compile=ts.transpileModule(readFileSync(new URL('../lib/astrology-evidence.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {buildCareerReferenceChains,buildEvidencePacket}=await import(`data:text/javascript;base64,${Buffer.from(compile).toString('base64')}`);
const chart={lagna:'Karka',rashi:'Meena',planets:[
  {name:'Sun',rasi:'Simha',position:5,degree:1,isRetrograde:false},
  {name:'Mars',rasi:'Mesha',position:1,degree:2,isRetrograde:false},
],yogas:[],navamsa:[
  {name:'Mars',rasi:'Dhanu',position:9,degree:1},
  {name:'Jupiter',rasi:'Mithuna',position:3,degree:2},
  {name:'Venus',rasi:'Kanya',position:6,degree:3},
]};
test('three Career origins retain their own tenth lord and provider D9 chain',()=>{
  assert.deepEqual(buildCareerReferenceChains(chart,true),[
    {origin:'lagna',referenceSign:4,tenthSign:1,tenthLord:'Mars',navamsaSign:9,navamsaLord:'Jupiter'},
    {origin:'moon',referenceSign:12,tenthSign:9,tenthLord:'Jupiter',navamsaSign:3,navamsaLord:'Mercury'},
    {origin:'sun',referenceSign:5,tenthSign:2,tenthLord:'Venus',navamsaSign:6,navamsaLord:'Mercury'},
  ]);
});
test('missing D9 cannot be replaced with natal placements or period names',()=>{
  const chains=buildCareerReferenceChains({...chart,navamsa:undefined,currentDasha:{name:'Mercury',start:'2020-01-01T00:00:00Z',end:'2030-01-01T00:00:00Z'}},true);
  assert.equal(chains.length,3);
  assert.ok(chains.every(c=>c.navamsaLord===undefined && c.navamsaSign===undefined));
  assert.deepEqual(buildCareerReferenceChains(chart,false),[]);
  assert.deepEqual(buildCareerReferenceChains({...chart,navamsa:[...chart.navamsa,chart.navamsa[0]]},true),[]);
  assert.deepEqual(buildCareerReferenceChains({...chart,navamsa:[{...chart.navamsa[0],position:1}]},true),[]);
});
test('evidence exposes sourced branches without declaring a synthesis approved',()=>{
  const p=buildEvidencePacket({category:'Career',question:'Which work suits me?',language:'ta',birthTimeKnown:true,chart});
  assert.equal(p.facts.find(f=>f.field==='career_lagna_tenth_lord_navamsa_lord').value,'Jupiter');
  assert.equal(p.facts.find(f=>f.field==='career_lagna_tenth_lord_navamsa_lord').displayValue,'குரு');
  assert.equal(p.facts.find(f=>f.field==='career_lagna_tenth_lord_navamsa_sign').displayValue,'தனுசு');
  assert.ok(p.facts.find(f=>f.field==='career_house_convention').value.includes('whole-sign'));
  assert.equal(p.facts.some(f=>f.field==='career_synthesis_review'),false);
  const other=buildEvidencePacket({category:'Career',question:'En child ku enna career suit aagum?',language:'en',birthTimeKnown:true,chart});
  assert.equal(other.facts.some(f=>f.field.startsWith('career_')),false);
});
test('whole-sign tenth counting wraps correctly for every sign',()=>{
  const signs=['Mesha','Vrishabha','Mithuna','Karka','Simha','Kanya','Tula','Vrischika','Dhanu','Makara','Kumbha','Meena'];
  const expected=[10,11,12,1,2,3,4,5,6,7,8,9];
  signs.forEach((lagna,index)=>assert.equal(buildCareerReferenceChains({...chart,lagna},true)[0].tenthSign,expected[index]));
});
