import test from 'node:test';
import assert from 'node:assert/strict';
import {moduleFor} from './helpers/load.mjs';
const {divineBirth,divineConsultation,parseEdited,validChatText,validConversationText,conversationReplyLimits,practicalGuidanceRequested,safeProfileContext,consultationControls,deleteDivineSession,uncertaintyStrengthened,consultationEditorRequest}=await import(moduleFor('../lib/divine-consultation.ts'));
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

test('explicit current detail request expands conversation without changing model or paid provider tier',async()=>{
 const thought=('Venus may favour commitment when both people are ready to discuss their expectations patiently. ').repeat(3).trim();
 const answer=Array.from({length:4},()=>thought).join('\n\n');
 const contexts=[];let reads=0;
 const result=await divineConsultation(config,{...input,depth:'standard',responseMode:'conversation',question:'Explain in detail what the reading means for family discussions.'},db(),async(url,opts)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  const body=JSON.parse(opts.body);
  if(url.includes('ask.divine')){
   reads++;assert.equal(body.depth,'standard');assert.equal(body.length_cap,'full');
   assert.ok(body.style_notes.length<=500);
   const context=JSON.parse(body.message);contexts.push(context);
   assert.match(context.response_instructions,/explicitly requested more detail/);
   assert.match(context.response_instructions,/at most 220 words/);
   assert.doesNotMatch(context.response_instructions,/25–55|90–140|at most 45 words/);
   return Response.json({answer,credits_charged:30});
  }
  assert.equal(body.model,config.OPENROUTER_MODEL);
  assert.equal(body.reasoning.enabled,false);
  assert.equal(body.max_tokens,2200);
  contexts.push(JSON.parse(body.messages[1].content));
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:['Venus may favour commitment']})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);
 assert.ok(answer.split(/\s+/).length>120);assert.ok(answer.split(/\s+/).length<=220);
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

test('new GPT editor uses supported low reasoning and a strict source schema while retaining bounded depth',async()=>{
 const model='openai/gpt-6.1-sol';
 const messages=['My family is pressuring me.','I already told them I need time.','How can I explain that calmly?'];
 const requestInput={...input,responseMode:'conversation',userMessageBatch:messages,question:messages.join('\n')};
 const request=consultationEditorRequest(model,requestInput,reading);
 assert.equal(request.model,model);assert.deepEqual(request.reasoning,{effort:'low'});
 assert.equal(request.temperature,undefined);assert.equal(request.top_p,undefined);
 assert.equal(request.max_tokens,1400);assert.equal(request.response_format.type,'json_schema');
 assert.equal(request.response_format.json_schema.strict,true);
 assert.deepEqual(request.response_format.json_schema.schema.required,['answer','source_quotes']);
 const userContext=JSON.parse(request.messages[1].content);
 assert.deepEqual(userContext.current_user_messages,messages);assert.equal(userContext.question,messages.join('\n'));
 assert.match(request.messages[0].content,/latest correction/);
 assert.match(request.messages[0].content,/maximum of 120 words and three messages/);
 assert.match(request.messages[0].content,/Do not substitute an unsolicited study routine/);
 let reads=0,edits=0;
 const result=await divineConsultation({...config,OPENROUTER_CHAT_MODEL:model},requestInput,db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine')){reads++;assert.deepEqual(JSON.parse(JSON.parse(options.body).message).current_user_messages,messages);return Response.json({answer:reading,credits_charged:30});}
  edits++;assert.equal(JSON.parse(options.body).model,model);
  return Response.json({id:'synthetic-generation',model,choices:[{finish_reason:'stop',message:{content:JSON.stringify(edited)}}],usage:{cost:0.005,prompt_tokens:1000,completion_tokens:200,completion_tokens_details:{reasoning_tokens:100},prompt_tokens_details:{cached_tokens:100}}});
 });
 assert.equal(result.answer,reading);assert.equal(reads,1);assert.equal(edits,1);
 assert.equal(result.calls[1].costUsd,0.005);assert.equal(result.calls[1].reasoningTokens,100);
 assert.equal(result.calls[1].generationId,'synthetic-generation');
 assert.ok(!JSON.stringify(result.calls).includes(messages[0]));
});

test('conversation message bounds reject an explosion or oversized bubble without cutting the answer',()=>{
 assert.equal(validConversationText('Let us look at what changed.\n\nWhat has already helped?'),true);
 assert.equal(validConversationText(Array.from({length:6},()=>reading).join('\n\n')),false);
 assert.equal(validConversationText('A '.repeat(181)+'thought.'),false);
});

test('conversation editor answers fully before an optional specific follow-up without extending the reply budget',()=>{
 const request=consultationEditorRequest('openai/gpt-6.1-sol',{...input,responseMode:'conversation',category:'Career',question:'What does the reading indicate for my career?'},reading);
 const prompt=request.messages[0].content;
 assert.match(prompt,/Give the complete direct answer first/);
 assert.match(prompt,/Then ask at most one relevant, specific follow-up/);
 assert.match(prompt,/changing jobs or growth in the current role/);
 assert.match(prompt,/Avoid generic closers/);
 assert.match(prompt,/Never withhold the core answer, manufacture unnecessary questions/);
 assert.match(prompt,/pressure the user to stay or spend/);
 assert.match(prompt,/Explicit goodbyes and short factual answers need no follow-up/);
 assert.match(prompt,/maximum of 120 words and three messages/);assert.equal(request.max_tokens,1400);
});

test('current detail and brevity requests control limits; earlier context never expands a reply',()=>{
 const defaults=conversationReplyLimits({question:'What does this indicate for my exam?',dialogue:[{role:'user',content:'Explain in detail.'}],conversationMemory:['I like detailed answers.']});
 assert.deepEqual(defaults,{expanded:false,maxWords:120,maxCharacters:3000,maxMessages:3,maxTokens:1400});
 for(const question of ['Explain more about that indication.','Please explain in detail.','இன்னும் விரிவாக விளக்குங்கள்.','Konjam virivaaga sollunga.'])assert.equal(conversationReplyLimits({question}).maxWords,220);
 assert.equal(conversationReplyLimits({question:'Explain in detail but keep the answer short.'}).expanded,false);
 assert.equal(conversationReplyLimits({userMessageBatch:['Explain in detail.','Actually, a short answer please.']}).expanded,false);
 assert.equal(conversationReplyLimits({userMessageBatch:['A short answer first.','Now explain more.']}).expanded,true);
 const fourThoughts=Array(4).fill('Venus may favour commitment when both people are ready.').join('\n\n');
 assert.equal(validConversationText(fourThoughts,{question:'What does the chart indicate?'}),false);
 assert.equal(validConversationText(fourThoughts,{question:'Explain more.'}),true);
 assert.equal(validConversationText(('word '.repeat(120))+'end.'),false);
 assert.equal(validConversationText(('word '.repeat(110))+'end.\n\n'+('word '.repeat(110))+'end.',{question:'Explain more.'}),false);
 assert.equal(practicalGuidanceRequested({question:'Does my chart indicate exam success?'}),false);
 assert.equal(practicalGuidanceRequested({question:'How can astrology indicate my career prospects?'}),false);
 assert.equal(practicalGuidanceRequested({question:'What can I expect from the chart?'}),false);
 assert.equal(practicalGuidanceRequested({question:'Suggest a simple study plan.'}),true);
 assert.equal(practicalGuidanceRequested({question:'How can I prepare for the exam?'}),true);
});

test('negated detail requests remain concise in each supported language and latest batch preference wins',()=>{
 for(const question of [
  "Don't explain in detail; just answer the question.",
  'Do not give a detailed explanation.',
  'Not in detail, please.',
  'விரிவாக விளக்க வேண்டாம். கேள்விக்கான பதில் மட்டும் சொல்லுங்கள்.',
  'Detaila solla vendaam. Kelvikku badhil mattum sollunga.',
  'Virivaaga vilakkama solla thevai illai.',
 ]){
  const limits=conversationReplyLimits({question});
  assert.equal(limits.expanded,false,question);assert.equal(limits.maxWords,120,question);assert.equal(limits.maxTokens,1400,question);
  assert.equal(conversationReplyLimits({userMessageBatch:['Explain in detail.',question]}).expanded,false,question);
 }
 assert.equal(conversationReplyLimits({userMessageBatch:["Don't explain in detail.",'Now explain more.']}).expanded,true);
});

test('latest current refusal of practical help overrides earlier plan requests without erasing a later new request',()=>{
 for(const refusal of [
  'No plan or coaching. Only explain the astrological indication.',
  "I don't want advice or a routine. Answer the astrology question only.",
  'படிப்புத் திட்டம் வேண்டாம். ஜோதிடக் குறிப்பை மட்டும் சொல்லுங்கள்.',
  'ஆலோசனை தேவையில்லை. ஜோதிடக் குறிப்பை மட்டும் சொல்லுங்கள்.',
  'Plan coaching vendaam. Jothida kurippu mattum sollunga.',
  'Study plan thevai illai. Astrology mattum sollunga.',
 ]){
  assert.equal(practicalGuidanceRequested({question:refusal}),false,refusal);
  assert.equal(practicalGuidanceRequested({userMessageBatch:['Give me a study plan.',refusal]}),false,refusal);
 }
 assert.equal(practicalGuidanceRequested({userMessageBatch:['Give me a study plan.','I work during the day.']}),true);
 assert.equal(practicalGuidanceRequested({userMessageBatch:['No plan or coaching.','Actually, suggest a simple study plan.']}),true);
});

test('a long default edit is repaired into the same concise grounded answer rather than silently falling back',async()=>{
 const longAnswer=Array(4).fill('Venus may favour commitment when both people are ready to discuss their expectations patiently.').join('\n\n');
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,responseMode:'conversation',question:'What does the chart indicate?'},db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine')){reads++;return Response.json({answer:reading});}
  edits++;const request=JSON.parse(options.body);assert.equal(request.max_tokens,1400);
  assert.match(request.messages[0].content,/120 words and three messages/);
  if(edits===2)assert.match(request.messages.at(-1).content,/conversation_message_bound/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:edits===1?longAnswer:reading,source_quotes:[reading]})}}]});
 });
 assert.equal(result.answer,reading);assert.equal(reads,1);assert.equal(edits,2);assert.equal(result.calls[1].validationReason,'conversation_message_bound');
});

test('default astrology reply condenses the full source into the requested indication without volunteered exam coaching',async()=>{
 const indication='The Mercury period may support study and careful reasoning when effort is consistent. This is a traditional indication only; it cannot establish exam selection or a pass result.';
 const fullSource=Array(8).fill(indication).join('\n\n');
 const answer='The supplied Mercury-period indication may support study and careful reasoning when effort is consistent.\n\nThat suggests a supportive traditional theme, with the effort condition kept in place. It does not establish exam selection or whether you will pass.\n\nThis reading supports a cautious indication, rather than a definite result.';
 let reads=0,edits=0;
 const requestInput={...input,category:'Education',responseMode:'conversation',question:'Does the reading show support for my banking exam?'};
 const result=await divineConsultation(config,requestInput,db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(url.includes('ask.divine')){reads++;return Response.json({answer:fullSource,credits_charged:30});}
  edits++;const request=JSON.parse(options.body),context=JSON.parse(request.messages[1].content);
  assert.equal(context.reading,fullSource);assert.ok(fullSource.split(/\s+/).length>220);
  assert.equal(request.max_tokens,1400);assert.match(request.messages[0].content,/requested astrological indication/);
  assert.match(request.messages[0].content,/only when the current user explicitly asks for practical help/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[indication]})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,1);assert.equal(result.calls[0].credits,30);
 assert.equal(answer.split(/\n\n/).length,3);assert.ok(answer.split(/\s+/).length<=120);
 assert.doesNotMatch(answer,/minutes|syllabus|practice questions|error log/);
});
