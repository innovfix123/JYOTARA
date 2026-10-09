import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {divineConsultation,consultationEditorRequest,editedValidation}=await import(moduleFor('../lib/divine-consultation.ts'));
const config={DIVINE_API_KEY:'fixture',DIVINE_ACCESS_TOKEN:'fixture',OPENROUTER_API_KEY:'fixture',OPENROUTER_MODEL:'google/gemini-2.5-flash',OPENROUTER_CHAT_MODEL:'google/gemini-3.8-flash'};
const input={id:'synthetic-style-request',person:{name:'Synthetic fixture',gender:'male',datetime:'2001-06-12T06:20:00+05:30',place:'Chennai',latitude:13.0827,longitude:80.2707},question:'When is a favourable period to discuss commitment?',category:'Marriage',responseMode:'conversation',dialogue:[]};
const source='Venus may support commitment discussions from 1 May 2027 to 31 August 2027. Mutual affection may help, but communication styles differ. This period does not guarantee marriage or a wedding date.';
const db=()=>({prepare(){return {bind(){return {async run(){}};}};}});

for(const [style,answer] of [
 ['english','Your reading points to 1 May 2027 to 31 August 2027 as a period that may support commitment discussions.\n\nIt may help you explore your different communication styles, without promising marriage or a wedding date.'],
 ['tamil','உங்கள் வாசிப்பில் 1 மே 2027 முதல் 31 ஆகஸ்ட் 2027 வரை உறவைப் பற்றிப் பேசுவதற்கு ஆதரவு இருக்கலாம்.\n\nபேசும் விதத்தில் உள்ள வேறுபாடுகளைப் புரிந்துகொள்ள உதவலாம்; இது திருமண நாளை உறுதி செய்யவில்லை.'],
 ['tanglish','Unga reading-la 1 May 2027 mudhal 31 August 2027 varai commitment pathi pesa aadharavu irukkalaam.\n\nPesura vidhathula irukkura vithiyasangalai purinjukka udhavalaam; idhu kalyana date-ai confirm pannala.'],
]) test('Gemini Ask accepts the supplied timing window in '+style+' without a second reading',async()=>{
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,style},db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const body=JSON.parse(options.body);
  if(String(url).includes('ask.divine')){reads++;return Response.json({answer:source,credits_charged:30});}
  edits++;assert.equal(body.model,'google/gemini-3.8-flash');assert.equal(body.response_format.type,'json_object');
  assert.equal(JSON.parse(body.messages[1].content).reading,source);
  return Response.json({model:'google/gemini-3.8-flash',choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[source]})}}],usage:{cost:0.001}});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,1);
 assert.equal(result.calls[0].credits,30);assert.equal(result.calls[1].returnedModel,'google/gemini-3.8-flash');
});

test('a fabricated timing date is rejected and repaired using the same paid reading',async()=>{
 let reads=0,edits=0;
 const answer='Your reading may support commitment discussions from 1 May 2027 to 31 August 2027.';
 const result=await divineConsultation(config,{...input,style:'english'},db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(String(url).includes('ask.divine')){reads++;return Response.json({answer:source,credits_charged:30});}
  edits++;
  if(edits===2)assert.match(JSON.parse(options.body).messages.at(-1).content,/unsupported_numbers/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:edits===1?'Your marriage date is 9 May 2027.':answer,source_quotes:[source]})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,2);assert.equal(result.calls[1].validationReason,'unsupported_numbers');
});

test('astrologer voice does not permit an invented guarantee despite genuine source quotes',async()=>{
 const result=await divineConsultation(config,{...input,style:'english'},db(),async(url)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(String(url).includes('ask.divine'))return Response.json({answer:source});
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'You will definitely marry on 1 May 2027.',source_quotes:[source]})}}]});
 });
 assert.equal(result.answer,null);assert.equal(result.calls[1].validationReason,'strengthened_uncertainty');
});

test('current source is the only timing evidence, with supported interpretation before narrow limitations',()=>{
 const request=consultationEditorRequest(config.OPENROUTER_CHAT_MODEL,{...input,style:'tanglish',dialogue:[{role:'assistant',content:'Earlier I guessed a wedding in September.'}]},source);
 const context=JSON.parse(request.messages[1].content);
 assert.equal(context.reading,source);assert.equal(context.conversation_context[0].content,'Earlier I guessed a wedding in September.');
 assert.match(request.messages[0].content,/lead with what it DOES indicate/);
 assert.match(request.messages[0].content,/do not reuse|do not invent a date or reuse dates/i);
 assert.match(request.messages[0].content,/usually 35–75 words/);
 assert.match(request.messages[0].content,/source notes, datasets, verification pipelines/);
 assert.match(request.messages[0].content,/unga\/neenga/);
 assert.match(request.messages[0].content,/translate month names into Tamil script/);
});

test('a denied Tanglish guarantee does not reject a tentative supplied career window',()=>{
 const reading='Career opportunities may improve from 15 December 2026 to 20 February 2027. Progress is gradual. There is no confirmed offer, employer, salary or exact job date.';
 const answer='Unga chart padi, 15 December 2026 la irundhu 20 February 2027 kulla career opportunities improve aagalaam.\n\nIdhula progress gradual-ah dhaan irukkum, kandippa offer kidaikkum-nu solluradhukku illai.';
 assert.equal(editedValidation(JSON.stringify({answer,source_quotes:[reading]}),reading,'tanglish',120).answer,answer);
 for(const claim of [
  'Opportunities improve aagalaam. Kandippa offer kidaikkum.',
  'Nichayam kalyanam nadakkum. Kandippa offer kidaikkum-nu solluradhukku illai.',
  'Kandippa kidaikkum aana varum-nu solla mudiyadhu.',
 ]) assert.equal(editedValidation(JSON.stringify({answer:claim,source_quotes:[reading]}),reading,'tanglish',120).reason,'strengthened_uncertainty');
});

test('Tamil answers require translated month names while their source quotes remain exact',()=>{
 const answer='உறவைப் பற்றிப் பேச 1 மே 2027 முதல் 31 ஆகஸ்ட் 2027 வரை ஆதரவு இருக்கலாம்.';
 assert.equal(editedValidation(JSON.stringify({answer,source_quotes:[source]}),source,'tamil',120).answer,answer);
 assert.equal(editedValidation(JSON.stringify({answer:answer.replace('மே','May'),source_quotes:[source]}),source,'tamil',120).reason,'text_language_length_or_completion');
});
