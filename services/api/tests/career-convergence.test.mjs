import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile=text=>ts.transpileModule(text,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const url=text=>`data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const module=file=>url(compile(readFileSync(new URL(file,import.meta.url),'utf8')));
const rulesUrl=module('../lib/career-rules.ts');
const {careerRules}=await import(rulesUrl);
const contractSource=compile(readFileSync(new URL('../lib/career-answer-contract.ts',import.meta.url),'utf8')).replace('./career-rules',rulesUrl);
const responseSource=compile(readFileSync(new URL('../lib/career-response.ts',import.meta.url),'utf8')).replaceAll('./astrology-evidence', module('../lib/astrology-evidence.ts')).replace('./career-rules',rulesUrl).replace('./career-answer-contract',url(contractSource));
const {careerCopyBundles,reviewedCareerResponse}=await import(url(responseSource));
const {buildEvidencePacket}=await import(module('../lib/astrology-evidence.ts'));
const chart={lagna:'Karka',rashi:'Karka',nakshatra:'Pushya',planets:['Sun','Moon','Mars','Mercury','Jupiter','Venus','Saturn','Rahu','Ketu'].map(name=>({name,rasi:'Karka',position:4,degree:1,isRetrograde:false})),yogas:[],navamsa:[{name:'Mars',rasi:'Mithuna',position:3,degree:1}]};
const packet=(language='en')=>buildEvidencePacket({category:'Career',question:'Which career direction could I explore?',language,birthTimeKnown:true,chart});
// These copies of the registry are TEST fixtures, not production approvals.
const syntheticRegistry={rules:careerRules.filter(r=>r.id.includes('CONVERGENCE')).map(r=>({...r,status:'approved',review:{interpretation:'SYNTHETIC',rights:'SYNTHETIC',language:'SYNTHETIC'}})),
  bundles:careerCopyBundles.map(b=>({...b,status:'approved',direct:{...b.direct,reviewId:'SYNTHETIC'},step:{...b.step,reviewId:'SYNTHETIC'},limitation:{...b.limitation,reviewId:'SYNTHETIC'}}))};
const input={snapshotId:'test-profile',questionId:'test-question',style:'english',packet:packet()};
test('only bounded English review is enabled in the real catalogue',()=>{
  const result=reviewedCareerResponse(input);
  assert.equal(result.ok,true);
  assert.equal(result.evidence.length,19);
  assert.match(result.answer,/recorded natal planets leave the tenth houses/u);
  assert.match(result.answer,/Try one small task/u);
  for(const style of ['tamil','tanglish']) assert.equal(reviewedCareerResponse({...input,style}).ok,false);
  assert.ok(careerCopyBundles.filter(b=>b.responseStyle!=='english'&&b.questionKind==='career_direction').every(b=>b.status==='candidate'&&!b.direct.reviewId));
});
test('review plumbing composes all five answer parts from actual chain fields',()=>{
  for(const style of ['english','tamil','tanglish']){
    const result=reviewedCareerResponse({...input,style,packet:packet(style==='tamil'?'ta':'en')},syntheticRegistry);
    assert.equal(result.ok,true,`${style}: ${result.reason}`);
    assert.equal(result.evidence.length,19);
    assert.equal(result.answer.split('\n\n').length,4);
    assert.equal(result.provenance.snapshotId,'test-profile');
    assert.ok(result.provenance.ruleVersions[0].includes('CONVERGENCE'));
    if(style==='tanglish')assert.doesNotMatch(result.answer,/[\u0B80-\u0BFF]/);
  }
});

test('missing natal planets and occupied tenth houses cannot satisfy the scan prerequisite',()=>{
  const evaluate=modified=>{
    const p=buildEvidencePacket({category:'Career',question:'Which career direction could I explore?',language:'en',birthTimeKnown:true,chart:modified});
    return reviewedCareerResponse({...input,packet:p},syntheticRegistry);
  };
  for(const p of chart.planets){
    assert.equal(evaluate({...chart,planets:chart.planets.filter(x=>x.name!==p.name)}).ok,false,`missing ${p.name}`);
    assert.equal(evaluate({...chart,planets:chart.planets.map(x=>x.name===p.name?{...x,rasi:'Mesha',position:1}:x)}).ok,false,`occupied by ${p.name}`);
  }
  for(const field of ['career_natal_occupancy_coverage','career_lagna_tenth_house_empty','career_moon_tenth_house_empty']) {
    assert.equal(reviewedCareerResponse({...input,packet:{...input.packet,facts:input.packet.facts.filter(f=>f.field!==field)}},syntheticRegistry).ok,false,field);
  }
});
test('one differing or missing branch and timing questions cannot use direction copy',()=>{
  for(const field of ['career_lagna_tenth_lord_navamsa_lord','career_moon_tenth_lord_navamsa_lord','career_sun_tenth_lord_navamsa_lord']){
    const changed={...input.packet,facts:input.packet.facts.map(f=>f.field===field?{...f,value:'Venus'}:f)};
    assert.equal(reviewedCareerResponse({...input,packet:changed},syntheticRegistry).ok,false);
    assert.equal(reviewedCareerResponse({...input,packet:{...input.packet,facts:input.packet.facts.filter(f=>f.field!==field)}},syntheticRegistry).ok,false);
  }
  for(const question of ['When will I get hired?','Should I accept this offer?','Will I get promoted?'])assert.equal(reviewedCareerResponse({...input,packet:{...input.packet,question}},syntheticRegistry).ok,false);
});

test('Lagna and Moon occupancy are checked independently and unknown time supplies neither',()=>{
  const distinct={...chart,rashi:'Simha',nakshatra:'Magha',
    planets:chart.planets.map(p=>p.name==='Moon'?{...p,rasi:'Simha',position:5}:p),
    navamsa:[...chart.navamsa,{name:'Venus',rasi:'Mithuna',position:3,degree:1}]};
  const make=(c,known=true)=>buildEvidencePacket({category:'Career',question:input.packet.question,language:'en',birthTimeKnown:known,chart:c});
  assert.equal(reviewedCareerResponse({...input,packet:make(distinct)},syntheticRegistry).ok,true);
  for(const [rasi,position,occupied,empty]of [['Mesha',1,'lagna','moon'],['Vrishabha',2,'moon','lagna']]){
    const p=make({...distinct,planets:distinct.planets.map(x=>x.name==='Saturn'?{...x,rasi,position}:x)});
    const facts=Object.fromEntries(p.facts.map(f=>[f.field,f.value]));
    assert.equal(facts['career_'+occupied+'_tenth_house_empty'],'false');
    assert.equal(facts['career_'+empty+'_tenth_house_empty'],'true');
    assert.equal(reviewedCareerResponse({...input,packet:p},syntheticRegistry).ok,false);
  }
  assert.ok(make(distinct,false).facts.every(f=>!f.field.includes('tenth_house_empty')));
});

test('Moon convergence uses its own reviewed theme, not Mercury text or Moon sign alone',()=>{
  const moonChart={...chart,navamsa:[{name:'Mars',rasi:'Karka',position:4,degree:1}]};
  const p=buildEvidencePacket({category:'Career',question:input.packet.question,language:'en',birthTimeKnown:true,chart:moonChart});
  const result=reviewedCareerResponse({...input,packet:p});
  assert.equal(result.ok,true);
  assert.match(result.answer,/Cultivation and trade in water-derived products/u);
  assert.doesNotMatch(result.answer,/writing, accounting/iu);
  assert.equal(result.evidence.length,19);
  assert.ok(result.provenance.ruleVersions.includes('CAREER-BJ10-D9-MOON-CONVERGENCE-english@1'));
  for(const question of ['When will I get hired?','Should I invest in farming?'])assert.equal(reviewedCareerResponse({...input,packet:{...p,question,category:question.includes('invest')?'Business':'Career'}}).ok,false);
  const missing=buildEvidencePacket({category:'Career',question:input.packet.question,language:'en',birthTimeKnown:true,chart:{...moonChart,navamsa:undefined}});
  assert.equal(reviewedCareerResponse({...input,packet:missing}).ok,false);
});

test('all six mixed Mercury/Moon patterns retain branch identity without ranking',()=>{
  for(let mask=1;mask<7;mask++){
    const mixed={...chart,rashi:'Simha',nakshatra:'Magha',
      planets:chart.planets.map(p=>p.name==='Moon'?{...p,rasi:'Simha',position:5}:p.name==='Sun'?{...p,rasi:'Kanya',position:6}:p),
      navamsa:['Mars','Venus','Mercury'].map((name,bit)=>({name,rasi:mask&(1<<bit)?'Karka':'Mithuna',position:mask&(1<<bit)?4:3,degree:1})),
    };
    const p=buildEvidencePacket({category:'Career',question:input.packet.question,language:'en',birthTimeKnown:true,chart:mixed});
    const result=reviewedCareerResponse({...input,packet:p});
    assert.equal(result.ok,true,`${mask}: ${result.reason}`);
    assert.equal(result.evidence.length,19);
    assert.ok(result.provenance.ruleVersions.includes(`CAREER-BJ10-D9-MIXED-MERCURY-MOON-${mask}-english@1`));
    for(const[bit,origin]of ['Lagna','Moon','Sun'].entries())assert.ok(result.answer.includes(`${origin} reference: the tenth-lord Navamsa chain ends with ${mask&(1<<bit)?'Moon':'Mercury'}`));
    assert.match(result.answer,/without judging which is stronger/);
    const missing={...p,facts:p.facts.filter(f=>f.field!=='career_sun_tenth_lord_navamsa_lord')};
    assert.equal(reviewedCareerResponse({...input,packet:missing}).ok,false);
    const different={...p,facts:p.facts.map(f=>f.field==='career_sun_tenth_lord_navamsa_lord'?{...f,value:'Saturn'}:f)};
    assert.equal(reviewedCareerResponse({...input,packet:different}).ok,false);
  }
});
