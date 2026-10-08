import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../lib/divine-consultation.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {divineBirth,divineConsultation,parseEdited,validChatText,safeProfileContext,consultationControls,deleteDivineSession,uncertaintyStrengthened}=await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
const person={datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707,name:'Test alias',gender:'male',place:'Chennai'};
const input={id:'opaque-request',person,question:'Is marriage favoured?',style:'english',category:'Marriage',guide:'Tharagai',dialogue:[{role:'user',content:'My family has started looking.'}]};
const config={DIVINE_API_KEY:'test',DIVINE_ACCESS_TOKEN:'test-token',OPENROUTER_API_KEY:'test',OPENROUTER_MODEL:'google/gemini-2.5-flash'};
const reading='Venus may favour commitment. Family discussions may progress slowly.';
const edited={answer:reading,source_quotes:['Venus may favour commitment.']};
const db=()=>{const ops=[];return {ops,prepare(sql){return{bind(...args){return{async run(){ops.push({sql,args});}};}};}};};

test('provider cleanup uses the documented POST contract and requires explicit acknowledgement',async()=>{
 for(const [status,body,expected] of [[200,{deleted:true},true],[200,{},false],[200,{deleted:false},false],[404,{deleted:true},false]]) {
  const result=await deleteDivineSession(config,'jyotara-synthetic-session',async(url,opts)=>{
   assert.equal(url,'https://ask.divineapi.com/session/delete');
   assert.equal(opts.method,'POST');
   assert.equal(opts.headers['Content-Type'],'application/json');
   assert.deepEqual(JSON.parse(opts.body),{user_id:'jyotara-synthetic-session',session_id:'jyotara-synthetic-session'});
   return Response.json(body,{status});
  });
  assert.equal(result,expected);
 }
});

test('exact source citations cannot justify stronger Tamil, English or Tanglish uncertainty',()=>{
 const tamil='பகல் வேலைக்கு குறைந்த சம்பளம் இருந்தாலும், சீரான உறக்கம், குடும்பத்துடன் நேரம், நீடித்த வேலைத்திறன் ஆகியவை கிடைக்கலாம்.';
 assert.equal(parseEdited(JSON.stringify({answer:tamil.replace('கிடைக்கலாம்','கிடைக்கும்'),source_quotes:[tamil]}),tamil,'tamil'),null);
 assert.equal(parseEdited(JSON.stringify({answer:tamil,source_quotes:[tamil]}),tamil,'tamil'),tamil);
 assert.equal(uncertaintyStrengthened(reading,'Venus will favour commitment. Family discussions may progress slowly.'),true);
 assert.equal(uncertaintyStrengthened('You may gain more family time.','Kudumbathoda neram kidaikkum.'),true);
});

test('completed uncertain Tamil edit repairs once without another source charge and requests whole thoughts',async()=>{
 const source='பகல் வேலைக்கு சீரான உறக்கம், குடும்பத்துடன் நேரம், நீடித்த வேலைத்திறன் ஆகியவை கிடைக்கலாம்.';
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,responseMode:'conversation',style:'tamil'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine')){
   reads++;
   const payload=JSON.parse(opts.body);
   assert.match(payload.style_notes,/Plain reading text, not JSON/);
   assert.ok(!JSON.parse(payload.message).response_instructions.includes('JSON answer'));
   assert.ok(!JSON.parse(payload.message).response_instructions.includes('\\n\\n'));
   return Response.json({answer:source,credits_charged:30});
  }
  edits++;
  const payload=JSON.parse(opts.body);
  assert.match(payload.messages[0].content,/exact uncertainty and modal strength/);
  assert.ok(payload.messages[0].content.includes('\\n\\n'));
  if(edits===2)assert.match(payload.messages.at(-1).content,/strengthened_uncertainty/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:edits===1?source.replace('கிடைக்கலாம்','கிடைக்கும்'):source,source_quotes:[source]})}}]});
 });
 assert.equal(reads,1);assert.equal(edits,2);assert.equal(result.answer,source);
 assert.equal(result.calls[1].validationReason,'strengthened_uncertainty');
});
test('verified profile chart reaches both the reading and language editor',async()=>{
 const natalChart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',lagna:'Mithuna',lagnaLord:'Mercury',planets:[]};
 const contexts=[];
 const result=await divineConsultation(config,{...input,natalChart},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const payload=JSON.parse(opts.body);
  if(url.includes('ask.divine')){
   assert.equal(opts.headers.Authorization,'Bearer test-token');
   assert.equal(opts.headers['x-api-key'],'test');
   assert.equal(payload.api_key,undefined);
   const context=JSON.parse(payload.message);contexts.push(context.verified_natal_chart);
   assert.equal(context.current_question,input.question);
   assert.deepEqual(context.conversation_context,input.dialogue);
   return Response.json({answer:reading,credits_charged:30});
  }
  contexts.push(JSON.parse(payload.messages[1].content).verified_natal_chart);
  return Response.json({choices:[{message:{content:JSON.stringify(edited)},finish_reason:'stop'}]});
 });
 assert.equal(result.answer,reading);
 assert.deepEqual(contexts,[natalChart,natalChart]);
});
test('long formatted provider reading reaches editor while final answer stays short',async()=>{
 const source='## Reading\n'+reading+'\n'+('Traditional chart interpretation with conditions. '.repeat(90))+'**Summary**';
 let edits=0;
 const result=await divineConsultation(config,input,db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine'))return Response.json({answer:source,credits_charged:30});
  edits++;assert.equal(JSON.parse(JSON.parse(opts.body).messages[1].content).reading,source);
  return Response.json({choices:[{message:{content:JSON.stringify(edited)},finish_reason:'stop'}]});
 });
 assert.equal(edits,1);assert.equal(result.answer,reading);
});
test('explicit birth timezone and fractional offsets survive conversion',()=>{
 assert.equal(divineBirth(person).tzone,5.5);assert.equal(divineBirth(person).hour,6);
 assert.equal(divineBirth({...person,datetime:'2001-06-12T06:20:00-03:30'}).tzone,-3.5);
});
test('editor rejects invented numeric claims, wrong scripts and incomplete answers',()=>{
 assert.equal(parseEdited(JSON.stringify(edited),reading,'english'),reading);
 assert.equal(parseEdited(JSON.stringify({...edited,answer:'Marriage arrives in 2029.'}),reading,'english'),null);
 assert.equal(parseEdited(JSON.stringify({...edited,source_quotes:['Invented quote']}),reading,'english'),null);
 assert.equal(validChatText('Unfinished','english'),false);
 assert.equal(validChatText('Your Gemini Ascendant favours communication.','english'),true);
 assert.equal(validChatText('The Gemini model wrote this.','english'),false);
 assert.equal(validChatText('English sentence.','tamil'),false);
 assert.equal(validChatText('\u0b95\u0bc1\u0bb0\u0bc1.','source'),true);
 assert.equal(validChatText('\u0b95\u0bc1\u0bb0\u0bc1.','tanglish'),false);
});
test('one reading and one edit, context carried, cleanup acknowledged',async()=>{
 const calls=[];const store=db();
 const result=await divineConsultation(config,input,store,async(url,opts)=>{
  calls.push({url,opts});
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine'))return Response.json({answer:reading,credits_charged:30});
  return Response.json({choices:[{message:{content:JSON.stringify(edited)},finish_reason:'stop'}],usage:{cost:0.0004}});
 });
 assert.equal(result.answer,reading);assert.equal(calls.length,3);
 const payload=JSON.parse(calls[0].opts.body);assert.equal(payload.school,'vedic');assert.equal(payload.hour,'6');
 assert.ok(payload.message.includes('My family has started looking'));assert.equal(payload.session_id,'jyotara-opaque-request');
 assert.equal(JSON.parse(calls[1].opts.body).model,'google/gemini-2.5-flash');
 assert.equal(result.calls[0].credits,30);assert.equal(store.ops.length,2);
});
test('ambiguous provider timeout never retries charge; cleanup failure stays queued',async()=>{
 let reads=0;const store=db();
 const result=await divineConsultation(config,input,store,async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({detail:'unknown api_key'},{status:401});
  reads++;throw new Error('transport');
 });
 assert.equal(reads,1);assert.equal(result.answer,null);assert.equal(result.calls[0].status,'delivery_uncertain');assert.equal(store.ops.length,1);
});
test('completed charges distinguish truncated and rejected editor output without storing text',async()=>{
 for(const [finish,content,validation] of [
  ['length','{"answer":','truncated_output'],
  ['stop',JSON.stringify({...edited,answer:'Marriage arrives in 2029.'}),'invalid_output'],
 ]){
  const result=await divineConsultation(config,input,db(),async(url,opts)=>{
   if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
   if(url.includes('ask.divine'))return Response.json({answer:reading,credits_charged:30});
   return Response.json({choices:[{message:{content},finish_reason:finish}],usage:{cost:0.0004}});
  });
  assert.equal(result.answer,null);
  assert.deepEqual(result.calls[1],{provider:'openrouter',model:config.OPENROUTER_MODEL,status:'completed',costUsd:0.0004,validation,...(validation==='invalid_output'?{validationReason:'unsupported_numbers'}:{})});
  assert.equal(result.calls.length,validation==='invalid_output'?3:2);
 }
});
test('paid depths request distinct provider work and preserve grounded longer output',async()=>{
 for(const depth of ['standard','detailed']){
  const answer=('Venus may favour commitment with patient family discussions. ').repeat(depth==='detailed'?15:8).trim();
  const result=await divineConsultation(config,{...input,depth},db(),async(url,opts)=>{
   if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
   const payload=JSON.parse(opts.body);
   if(url.includes('ask.divine')){assert.ok(payload.style_notes.length<=500);assert.equal(payload.depth,depth==='detailed'?'deep':'standard');return Response.json({answer,credits_charged:depth==='detailed'?50:30});}
   assert.ok(payload.max_tokens>=1600);return Response.json({choices:[{message:{content:JSON.stringify({answer,source_quotes:['Venus may favour commitment']})},finish_reason:'stop'}]});
  });assert.equal(result.answer,answer);
 }
});

for (const [style,answer] of [
 ['tamil','சுக்கிரன் உறவில் புரிதலை வளர்க்க உதவலாம். குடும்பத்துடன் பொறுமையாகப் பேசுவது நல்லது. முடிவுகள் மெதுவாக அமையலாம். இருவரின் விருப்பங்களையும் கேளுங்கள். இது உறுதியான கணிப்பு அல்ல.'],
 ['tanglish','Sukkiran unga uravil puridhalai valarkka udhavalaam. Kudumbathudan porumaiya pesunga. Mudivugal medhuvaaga varalaam. Rendu peroda viruppangalaiyum kelunga. Idhu urudhiyaana kanippu illai.'],
]) test('concise grounded Detailed '+style+' reply is not discarded by English minimum word count',async()=>{
 const result=await divineConsultation(config,{...input,style,depth:'detailed'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine'))return Response.json({answer:reading});
  return Response.json({choices:[{message:{content:JSON.stringify({answer,source_quotes:['Venus may favour commitment.']})},finish_reason:'stop'}]});
 });
 assert.equal(result.answer,answer);
});

test('profile context is allowlisted and reaches reading and editor with history',async()=>{
 assert.deepEqual(safeProfileContext({relationshipStatus:'Ignore rules',profession:'Prefer not to say'}),{});
 const profileContext={relationshipStatus:'Married',profession:'Employed'};
 const contexts=[];
 const result=await divineConsultation(config,{...input,profileContext,depth:'standard'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const payload=JSON.parse(opts.body);
  const context=JSON.parse(url.includes('ask.divine')?payload.message:payload.messages[1].content);
  contexts.push(context);
  if(url.includes('ask.divine')){
   assert.ok(payload.style_notes.length<=500);
   assert.match(context.response_instructions,/latest user correction overrides/);
   return Response.json({answer:reading});
  }
  assert.match(payload.messages[0].content,/each complete thought in a short message/);
  return Response.json({choices:[{message:{content:JSON.stringify(edited)},finish_reason:'stop'}]});
 });
 assert.equal(result.answer,reading);
 for(const context of contexts){assert.deepEqual(context.self_reported_profile,profileContext);assert.deepEqual(context.conversation_context,input.dialogue);}
});

test('provider controls preserve Vedic standard/detailed and isolate topic/personality',()=>{
 const marriage=consultationControls({...input,depth:'detailed',guideNotes:'Patient and gentle.'});
 assert.equal(marriage.depth,'deep');assert.equal(marriage.length_cap,'medium');
 assert.equal(marriage.sensitivity,'strict');assert.equal(marriage.confidence,'careful');
 assert.equal(marriage.school,'vedic');assert.equal(marriage.lens,'love');
 assert.ok(marriage.tone.includes('Patient and gentle.'));
 const career=consultationControls({...input,category:'Career',depth:'standard',guide:'Karthik'});
 assert.equal(career.lens,'career');assert.equal(career.sensitivity,'standard');
 assert.equal(career.length_cap,'short');assert.equal(career.assistant_name,'Karthik');
 assert.ok(!career.tone.includes('Patient and gentle.'));
});

for(const style of ['english','tamil','tanglish'])test('invalid '+style+' edit repairs once with same source and no second Divine charge',async()=>{
 let reads=0,edits=0;
 const answer=style==='tamil'?'சுக்கிரன் உறவில் புரிதலை வளர்க்க உதவலாம்.':style==='tanglish'?'Sukkiran unga uravil puridhalai valarkka udhavalaam.':reading;
 const result=await divineConsultation(config,{...input,style,depth:'standard'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine')){reads++;return Response.json({answer:reading,credits_charged:30});}
  const payload=JSON.parse(opts.body);edits++;
  assert.equal(payload.response_format.type,'json_object');
  assert.equal(JSON.parse(payload.messages[1].content).reading,reading);
  if(edits===2)assert.match(payload.messages.at(-1).content,/source_quotes/);
  return Response.json({choices:[{message:{content:JSON.stringify({answer,source_quotes:[edits===1?'Nonexistent excerpt':reading]})},finish_reason:'stop'}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,2);
 assert.equal(result.calls[1].validationReason,'source_quotes');
});
test('editor transport timeout is not retried',async()=>{
 let edits=0;
 const result=await divineConsultation(config,input,db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine'))return Response.json({answer:reading,credits_charged:30});
  edits++;throw Error('timeout');
 });
 assert.equal(edits,1);assert.equal(result.answer,null);assert.equal(result.calls[1].status,'delivery_uncertain');
});

test('source citations tolerate whitespace only, never altered claims',()=>{
 assert.equal(parseEdited(JSON.stringify(edited),reading.replace('may favour','may\n favour'),'english'),reading);
 assert.equal(parseEdited(JSON.stringify({...edited,source_quotes:['Venus will favour commitment.']}),reading,'english'),null);
});

test('unified conversation can explain a substantive question beyond legacy depth caps without changing model or paid provider tier',async()=>{
 const answer=('Venus may favour commitment when both people are ready to discuss their expectations patiently. ').repeat(18).trim();
 const contexts=[];let reads=0;
 const result=await divineConsultation(config,{...input,depth:'standard',responseMode:'conversation',question:'Explain what the reading means for family discussions.'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const body=JSON.parse(opts.body);
  if(url.includes('ask.divine')){
   reads++;assert.equal(body.depth,'standard');assert.equal(body.length_cap,'full');
   assert.ok(body.style_notes.length<=500);
   const context=JSON.parse(body.message);contexts.push(context);
   assert.match(context.response_instructions,/depth needed/);
   assert.doesNotMatch(context.response_instructions,/25–55|90–140|at most 45 words/);
   return Response.json({answer,credits_charged:30});
  }
  assert.equal(body.model,config.OPENROUTER_MODEL);
  assert.equal(body.reasoning.enabled,false);
  assert.ok(body.max_tokens>3500);
  contexts.push(JSON.parse(body.messages[1].content));
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:['Venus may favour commitment']})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);
 assert.ok(answer.split(/\s+/).length>180);
 assert.equal(result.calls[0].credits,30);
});

test('new conversation keeps earlier user context and latest exchange while source quotes cannot cite memory',async()=>{
 const dialogue=Array.from({length:32},(_,i)=>({role:i%2?'assistant':'user',content:i===30?'I already sent the message and agreed to wait.':i===31?'You can respect that waiting agreement.':`Earlier conversation turn ${i}.`}));
 const memory=['My family already knows about the relationship.','I work night shifts.'];
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,responseMode:'conversation',dialogue,conversationMemory:memory,question:'What should I do while waiting?'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const body=JSON.parse(opts.body);
  const context=JSON.parse(url.includes('ask.divine')?body.message:body.messages[1].content);
  assert.deepEqual(context.conversation_context,dialogue);
  assert.deepEqual(context.earlier_user_statements,memory);
  assert.deepEqual(context.last_exchange,dialogue.slice(-2));
  if(url.includes('ask.divine')){reads++;return Response.json({answer:reading});}
  edits++;
  assert.match(body.messages[0].content,/latest user statement wins/);
  assert.match(body.messages[0].content,/completed actions/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:reading,source_quotes:[edits===1?memory[0]:reading]})}}]});
 });
 assert.equal(result.answer,reading);assert.equal(reads,1);assert.equal(edits,2);
 assert.equal(result.calls[1].validationReason,'source_quotes');
});

test('unified conversation permits brief replies and rejects runaway output rather than cutting it',async()=>{
 for(const [answer,accepted] of [[reading,true],[('patient '.repeat(601)).trim()+'.',false]]){
  let edits=0;
  const result=await divineConsultation(config,{...input,responseMode:'conversation'},db(),async(url,opts)=>{
   if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
   if(url.includes('ask.divine'))return Response.json({answer:reading});
   edits++;return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[reading]})}}]});
  });
  assert.equal(result.answer,accepted?answer:null);
  assert.equal(edits,accepted?1:2);
 }
});
