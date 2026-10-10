import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {limitedBirthGuidance}=await import(moduleFor('../lib/limited-birth-guidance.ts'));
const input={question:'Will I get the bank exam result?',style:'english',category:'Education',dialogue:[]};
test('unknown time gives useful general help without sending invented time or chart to Divine',async()=>{
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},input,async(url,options)=>{
  assert.match(url,/openrouter/);
  const body=JSON.parse(options.body),context=JSON.parse(body.messages[1].content);
  assert.equal(context.question,input.question);assert.equal(context.chart,undefined);assert.equal(context.hour,undefined);
  assert.match(body.messages[0].content,/Do not ask for birth time again/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'I can’t predict the exam result. While waiting, review the next stage requirements and keep your documents ready.'})}}]});
 });
 assert.match(result.answer,/documents ready/);assert.equal(result.calls.length,1);
});
test('never claims an exact Rasi from unknown-time data and supports selected languages',async()=>{
 for(const style of ['english','tamil','tanglish']){
  const result=await limitedBirthGuidance({}, {...input,question:'What is my Rasi?',style},()=>{throw Error('No chart provider call allowed');});
  assert.equal(result.calls.length,0);
  if(style==='english')assert.match(result.answer,/can’t confirm/);
  if(style==='tamil')assert.match(result.answer,/உறுதிப்படுத்த முடியாது/);
  if(style==='tanglish')assert.match(result.answer,/urudhippadutha mudiyadhu/);
 }
});
test('rejects invented chart predictions and truncated answers',async()=>{
 for(const answer of ['Your Venus dasha will bring marriage next year.','You will definitely pass the exam.']){
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},input,async()=>Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]}));
  assert.match(result.answer,/can’t predict/);assert.doesNotMatch(result.answer,/birth time|general guidance/);assert.equal(result.calls[0].validation,'invalid_output');
 }
});

test('practical questions mentioning a Rasi still receive useful help without repeated time warnings',async()=>{
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,category:'Relationships',question:'My Rasi is Meena. How can I improve communication in my relationship?',dialogue:[{role:'assistant',content:'Birth time is unknown.'}]},async(_,options)=>{
  assert.match(JSON.parse(options.body).messages[0].content,/Do not repeat a birth-time limitation/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'Choose a calm moment to explain what has been bothering you. Listen to their reply before deciding on your next step.'})}}]});
 });
 assert.match(result.answer,/calm moment/);assert.doesNotMatch(result.answer,/birth time|can’t confirm/);assert.equal(result.calls.length,1);
});

test('unified unknown-time conversation explains useful practical context without inventing astrology',async()=>{
 const answer='You have already completed your application, so focus on the next stage requirements rather than applying again.\n\nKeep the required documents together and note any submission deadlines in the official notice.\n\nReview the topics or interview format listed for that next stage, adjusting your preparation around the time you have.\n\nWhich next stage are you preparing for?';
 const dialogue=Array.from({length:32},(_,i)=>({role:i%2?'assistant':'user',content:i===30?'I have already completed my application.':`Previous exam discussion ${i}.`}));
 const memory=['I prefer a bank role near my family.'];
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock',OPENROUTER_MODEL:'google/gemini-2.5-flash'},{...input,question:'Explain in detail how I can prepare for the next stage while waiting.',depth:'standard',responseMode:'conversation',conversationMemory:memory,dialogue},async(url,options)=>{
  assert.match(url,/openrouter/);
  const body=JSON.parse(options.body),context=JSON.parse(body.messages[1].content);
  assert.equal(body.model,'google/gemini-2.5-flash');assert.equal(body.max_tokens,1800);
  assert.deepEqual(context.conversation_context,dialogue);assert.deepEqual(context.last_exchange,dialogue.slice(-2));
  assert.deepEqual(context.earlier_user_statements,memory);
  assert.equal(context.chart,undefined);assert.equal(context.hour,undefined);
  assert.match(body.messages[0].content,/completed actions/);
  assert.doesNotMatch(body.messages[0].content,/at most 55 words|at most 90 words/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]});
 });
 assert.ok(answer.split(/\s+/).length>45);assert.ok(answer.split(/\s+/).length<=110);assert.equal(result.answer,answer);assert.equal(result.calls.length,1);
});

test('general guidance selects the chat model and retains complete attempt metadata',async()=>{
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock',OPENROUTER_MODEL:'google/gemini-2.5-flash',OPENROUTER_CHAT_MODEL:'openai/gpt-6.1-sol'},{...input,responseMode:'conversation'},async(_,options)=>{
  const request=JSON.parse(options.body);
  assert.equal(request.model,'openai/gpt-6.1-sol');assert.equal(request.temperature,undefined);
  assert.deepEqual(request.reasoning,{effort:'low'});assert.equal(request.response_format.type,'json_schema');
  assert.deepEqual(request.response_format.json_schema.schema.required,['answer']);
  return Response.json({id:'synthetic-general',model:request.model,choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'You have already finished the application. Keep your next stage documents ready while you wait for the official result.'})}}],usage:{cost:0.005,prompt_tokens:500,completion_tokens:200,completion_tokens_details:{reasoning_tokens:100}}});
 });
 assert.equal(result.calls.length,1);assert.equal(result.calls[0].costUsd,0.005);assert.equal(result.calls[0].reasoningTokens,100);
 assert.equal(result.calls[0].generationId,'synthetic-general');assert.match(result.answer,/already finished/);
});

test('unified general guidance repairs a completed invalid answer once and never retries transport or truncation',async()=>{
 const answer='Use the official result announcement when it is available. You have already completed the application, so keep the next stage documents ready.';
 let attempts=0;
 const repaired=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,responseMode:'conversation'},async(_,options)=>{
  attempts++;
  if(attempts===2)assert.match(JSON.parse(options.body).messages.at(-1).content,/failed validation/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:attempts===1?'Your Venus dasha will bring success.':answer})}}]});
 });
 assert.equal(repaired.answer,answer);assert.equal(attempts,2);assert.equal(repaired.calls[0].validation,'invalid_output');
 for(const kind of ['transport','truncated']){
  let calls=0;
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,responseMode:'conversation'},async()=>{
   calls++;if(kind==='transport')throw Error('timeout');
   return Response.json({choices:[{finish_reason:'length',message:{content:'{"answer":'}}]});
  });
  assert.equal(calls,1);assert.match(result.answer,/can’t predict/);
  assert.equal(result.calls[0][kind==='transport'?'status':'validation'],kind==='transport'?'delivery_uncertain':'truncated_output');
 }
});

test('unknown-time bank preparation accepts optional practical quantities and complete paragraph bubbles',async()=>{
 const userMessageBatch=['I am preparing for a banking entrance exam.','Suggest a simple study routine that I can adjust around work.'];
 const answer='Since you have already covered the basics, use a 20-minute block to revise a weak topic. Then practise 10 related questions and review each mistake.\n\nKeep a short error log so that your next session targets what needs work. Adjust these quantities to the time and energy you actually have.\n\nWhich section is hardest for you right now?';
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock',OPENROUTER_CHAT_MODEL:'openai/gpt-6.1-sol'},{...input,question:userMessageBatch.join('\n'),userMessageBatch,responseMode:'conversation',conversationMemory:['I have already covered the basic concepts.'],dialogue:[{role:'user',content:'I work during the day.'},{role:'assistant',content:'We can adapt a study routine around work.'}]},async(_,options)=>{
  const request=JSON.parse(options.body),context=JSON.parse(request.messages[1].content);
  assert.equal(request.model,'openai/gpt-6.1-sol');assert.equal(request.response_format.type,'json_schema');
  assert.deepEqual(request.response_format.json_schema.schema.required,['answer']);assert.deepEqual(request.reasoning,{effort:'low'});
  assert.equal(request.temperature,undefined);assert.equal(request.top_p,undefined);
  assert.deepEqual(context.current_user_messages,userMessageBatch);assert.deepEqual(context.earlier_user_statements,['I have already covered the basic concepts.']);
  assert.match(request.messages[0].content,/usable concise plan, not result announcements/);assert.match(request.messages[0].content,/optional study minutes/);
  assert.equal(request.max_tokens,1200);assert.match(request.messages[0].content,/maximum of 65 words and three messages/);
  assert.doesNotMatch(request.messages[0].content,/One complete sentence per line/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}],usage:{cost:0.003,prompt_tokens:500,completion_tokens:120}});
 });
 assert.equal(result.answer,answer);assert.equal(result.calls.length,1);assert.equal(result.calls[0].validation,undefined);
});

test('practical numbered quantities work in Tamil and Tanglish without becoming forecasts',async()=>{
 for(const [style,answer] of [
  ['tamil','உங்களால் தொடர்ந்து செய்யக்கூடிய அளவில் படியுங்கள். ஒரு பகுதியை 20 நிமிடங்கள் திரும்பப் படித்து, 10 பயிற்சிக் கேள்விகளைச் செய்து பார்க்கலாம்.\n\nதவறான பதில்களின் காரணத்தைப் புரிந்துகொண்டு, அடுத்த பயிற்சியில் அவற்றைத் திருத்துங்கள்.'],
  ['tanglish','Ungalukku etra alavukku routine-ai maathikkalaam. Oru pagudhiyai 20 nimidam padichu, 10 practice kelvigalai seyyalaam.\n\nThavarugalai purinjukkonga; adutha practice-la avatrai thiruthunga.'],
 ]){
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question:'Help me prepare for a banking exam.',style,responseMode:'conversation'},async()=>Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]}));
  assert.equal(result.answer,answer);assert.equal(result.calls.length,1);
 }
});

test('preparation fallback remains about studying when a provider fails, across the three styles',async()=>{
 for(const [style,question,preparation,resultLanguage] of [
  ['english','I am preparing for a bank exam. Give me a simple plan.',/syllabus|practice paper/i,/official.*result|documents|admission/i],
  ['tamil','வங்கித் தேர்வுக்குத் தயாராகிறேன். எளிய படிப்புத் திட்டம் சொல்லுங்கள்.',/பாடத்திட்ட|பயிற்சி/,/ஆவண|அதிகாரப்பூர்வ/],
  ['tanglish','Bank exam-ku prepare panren. Oru simple plan sollunga.',/syllabus|practice paper/i,/aavanangal|adhikaarappoorva/i],
 ]){
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question,style,responseMode:'conversation'},async()=>{throw Error('synthetic transport failure');});
  assert.match(result.answer,preparation);assert.doesNotMatch(result.answer,resultLanguage);assert.equal(result.calls.length,1);
  assert.equal(result.calls[0].status,'delivery_uncertain');
 }
});

test('transport fallback respects the latest no-coaching correction across English, Tamil and Tanglish',async()=>{
 for(const [style,request,refusal,coaching,limited] of [
  ['english','Give me a study plan.','No plan or coaching. Only explain the astrological indication.',/syllabus|practice paper|routine|study session/i,/astrological indication/],
  ['tamil','படிப்புத் திட்டம் சொல்லுங்கள்.','படிப்புத் திட்டம் வேண்டாம். ஜோதிடக் குறிப்பை மட்டும் சொல்லுங்கள்.',/பாடத்திட்ட|பயிற்சித் தேர்வு|திரும்பப் படித்து/,/ஜோதிடக் குறிப்பை/],
  ['tanglish','Oru simple plan sollunga.','Plan coaching vendaam. Jothida kurippu mattum sollunga.',/syllabus|practice paper|routine|padippai/i,/jothida kurippai/],
 ]){
  const userMessageBatch=[request,refusal];
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question:userMessageBatch.join('\n'),userMessageBatch,style,responseMode:'conversation'},async(_,options)=>{
   assert.equal(JSON.parse(options.body).max_tokens,1200);throw Error('synthetic transport failure');
  });
  assert.match(result.answer,limited);assert.doesNotMatch(result.answer,coaching);assert.equal(result.calls.length,1);
  assert.equal(result.calls[0].status,'delivery_uncertain');
 }
});

test('numeric outcome claims, invented calendar dates, unsupported astrology and oversized message counts stay rejected',async()=>{
 for(const [style,answer] of [
  ['english','You will pass the exam within 30 days.'],
  ['english','Your chance of passing is 80%.'],
  ['english','The result arrives on October 20.'],
  ['english','Your Mercury dasha gives you a strong memory.'],
  ['tamil','நீங்கள் தேர்வில் தேர்ச்சி பெறுவீர்கள்.'],
  ['tanglish','Neenga pass aaguveenga.'],
  ['english',Array(6).fill('Review a weak topic and practise related questions.').join('\n\n')],
 ]){
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question:'Suggest an exam preparation plan.',style,responseMode:'conversation'},async()=>Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]}));
  assert.notEqual(result.answer,answer);assert.equal(result.calls.length,2);assert.ok(result.calls.every(call=>call.validation==='invalid_output'));
 }
});

test('result-only questions retain an official-result boundary and may explicitly negate a guarantee',async()=>{
 const answer='The result is not guaranteed, and I can’t predict it. Check the official announcement and keep your next-stage documents ready.';
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},input,async()=>Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]}));
 assert.equal(result.answer,answer);assert.equal(result.calls.length,1);
 const fallback=await limitedBirthGuidance({},input);
 assert.match(fallback.answer,/official exam|admission process/);assert.match(fallback.answer,/can’t predict/);assert.doesNotMatch(fallback.answer,/documents|study session/);
});

test('astrology outcome questions do not receive unsolicited exam coaching when evidence or delivery is unavailable',async()=>{
 const question='Does astrology indicate that I will clear my bank exam?';
 const fallback=await limitedBirthGuidance({}, {...input,question,responseMode:'conversation'});
 assert.match(fallback.answer,/can’t predict/);assert.doesNotMatch(fallback.answer,/syllabus|practice paper|routine|documents/);
 const answer='I can’t reliably establish an astrological indication for selection from the information available. It would not be responsible to turn that into a pass-or-fail prediction.';
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question,responseMode:'conversation',dialogue:[{role:'user',content:'Give me a detailed study plan.'},{role:'assistant',content:'We discussed practical preparation earlier.'}]},async(_,options)=>{
  const request=JSON.parse(options.body);assert.equal(request.max_tokens,1200);
  assert.match(request.messages[0].content,/do not replace it with generic study or career coaching/);
  assert.match(request.messages[0].content,/current user has not requested an extended explanation/);
  assert.match(request.messages[0].content,/Give the complete direct answer first/);
  assert.match(request.messages[0].content,/Then ask at most one relevant, specific follow-up/);
  assert.match(request.messages[0].content,/Explicit goodbyes and short factual answers need no follow-up/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(result.calls.length,1);
});

test('requested detail alone permits a longer general reply; default overflow repairs concisely without losing the current correction',async()=>{
 const thought='You have already covered the basics, so review the questions you missed and the reasoning behind their answers before choosing your next topic.';
 const longAnswer=Array(4).fill(thought).join('\n\n');
 const shortAnswer='You have already covered the basics. Use a short practice set to identify the weak topic, then review the mistakes before moving on.\n\nAdjust the size of the set to the time you have, rather than restarting the whole syllabus.';
 for(const expanded of [false,true]){
  let attempts=0;
  const question=expanded?'Explain in detail how I can adjust my study plan.':'Suggest a simple study plan.';
  const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,question,responseMode:'conversation',conversationMemory:['I have already completed the basics.']},async(_,options)=>{
   attempts++;const request=JSON.parse(options.body);assert.equal(request.max_tokens,expanded?1800:1200);
   if(attempts===2){assert.match(request.messages.at(-1).content,/65 words and three messages/);assert.match(request.messages.at(-1).content,/completed actions/);}
   return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:expanded||attempts===1?longAnswer:shortAnswer})}}]});
  });
  assert.equal(result.answer,expanded?longAnswer:shortAnswer);assert.equal(attempts,expanded?1:2);
 }
});
