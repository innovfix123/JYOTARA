import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const encode = source => 'data:text/javascript;base64,'+Buffer.from(ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText).toString('base64');
const client=encode(readFileSync(new URL('../lib/prokerala-client.ts',import.meta.url),'utf8'));
const source=readFileSync(new URL('../runtime/discovery.ts',import.meta.url),'utf8').replace("'../lib/prokerala-client'",JSON.stringify(client));
const {validDay,validBirth,daily,matching}=await import(encode(source));
test('daily dates use IST and reject outside the three-day window',()=>{
 const now=Date.parse('2026-09-08T20:00:00Z');
 for(const date of ['2026-09-08','2026-09-09','2026-09-10'])assert.equal(validDay(date,now),true);
 for(const date of ['2026-09-07','2026-09-11','bad',null])assert.equal(validDay(date,now),false);
});
test('matching accepts unknown time while rejecting minors and missing consent',async()=>{
 const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:true};
 assert.equal(validBirth(birth),true);
 assert.equal(validBirth({...birth,exactTime:false}),true);
 assert.equal(validBirth({...birth,datetime:'2020-01-01T12:00:00+05:30'}),false);
 const res=await matching(new Request('https://test',{method:'POST',body:JSON.stringify({boy:birth,girl:birth,consent:false})}));
 assert.equal(res.status,400);
});
test('invalid signs never trigger provider calls',async()=>{
 const res=await daily(new Request('https://test',{method:'POST',body:JSON.stringify({sign:'unknown',date:'2026-09-09'})}));
 assert.equal(res.status,400);
});
test('daily summary preserves provider differences after shared openings and decodes entities',async()=>{
 const {readingSummary,readablePrediction}=await import(encode(source));
 const prefix='The Sun is in Virgo. The Moon is in Leo. ';
 assert.equal(readingSummary(prefix+'Aries detail. Aries action.'),'Aries detail. Aries action.');
 assert.equal(readingSummary(prefix+'Pisces detail. Pisces action.'),'Pisces detail. Pisces action.');
 assert.equal(readingSummary(prefix,'Insight: Focus on your selected task.'),'Focus on your selected task.');
 assert.equal(readablePrediction('You&#039;ll find clarity &amp; focus.'),"You'll find clarity & focus.");
});

test('unknown-time matching uses explicit noon reference and returns a provisional Tamil comparison',async()=>{
 const original=globalThis.fetch;
 process.env.PROKERALA_CLIENT_ID='test';process.env.PROKERALA_CLIENT_SECRET='test';process.env.OPENROUTER_API_KEY='test';
 let calculated;
 globalThis.fetch=async(url,options)=>{
  if(String(url).endsWith('/token'))return Response.json({access_token:'test',expires_in:3600});
  if(String(url).includes('/kundli-matching')){calculated=new URL(url);return Response.json({status:'ok',data:{guna_milan:{total_points:22,maximum_points:36},message:{description:'Exact report that must not be used for unknown times.'}}});}
  const texts=JSON.parse(JSON.parse(options.body).input[1].content);
  assert.match(texts[0],/noon/);
  return Response.json({output_text:JSON.stringify(['உத்தேசப் பொருத்தம். பிறந்த நேரம் தெரியாததால் நண்பகல் பயன்படுத்தப்பட்டது.','உண்மையான நேரத்தால் மதிப்பெண் மாறலாம்.'])});
 };
 try{
  const birth={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,exactTime:false};
  const response=await matching(new Request('https://test',{method:'POST',body:JSON.stringify({boy:birth,girl:{...birth,exactTime:true},consent:true,language:'ta'})}));
  assert.equal(response.status,200);const result=await response.json();
  assert.equal(result.provisional,true);assert.equal(result.language,'ta');
  assert.match(result.interpretation,/உத்தேச/);
  assert.equal(calculated.searchParams.get('boy_dob'),'2002-07-29T12:00:00+05:30');
  assert.equal(calculated.searchParams.get('girl_dob'),'2002-07-29T05:00:00+05:30');
 }finally{globalThis.fetch=original;}
});
test('Tamil daily reading translates summary and details and keeps language caches separate',async()=>{
 const original=globalThis.fetch;let translated=0;
 process.env.PROKERALA_CLIENT_ID='test';process.env.PROKERALA_CLIENT_SECRET='test';process.env.OPENROUTER_API_KEY='test';
 const date=new Date(Date.now()+19800000).toISOString().slice(0,10);
 globalThis.fetch=async(url,options)=>{
  if(String(url).endsWith('/token'))return Response.json({access_token:'test',expires_in:3600});
  if(String(url).includes('/horoscope/'))return Response.json({status:'ok',data:{datetime:date+'T12:00:00+05:30',daily_predictions:[{sign:{name:'Aries'},predictions:['general','love','career'].map(type=>({type,prediction:type+' reading.'}))}]}});
  translated++;const texts=JSON.parse(JSON.parse(options.body).input[1].content);
  return Response.json({output_text:JSON.stringify(texts.map((_,i)=>'தமிழ் பலன் '+i))});
 };
 try{
  const req=language=>new Request('https://test',{method:'POST',body:JSON.stringify({sign:'aries',date,language})});
  const en=await (await daily(req('en'))).json();assert.match(en.sections[0].text,/general/);
  const ta=await (await daily(req('ta'))).json();assert.equal(ta.language,'ta');
  for(const section of ta.sections){assert.match(section.text,/தமிழ்/);assert.match(section.details,/தமிழ்/);}
  await daily(req('ta'));assert.equal(translated,1);
 }finally{globalThis.fetch=original;}
});
