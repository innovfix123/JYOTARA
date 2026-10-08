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
  assert.match(result.answer,/documents/);assert.doesNotMatch(result.answer,/birth time|general guidance/);assert.equal(result.calls[0].validation,'invalid_output');
 }
});

test('practical questions mentioning a Rasi still receive useful help without repeated time warnings',async()=>{
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock'},{...input,category:'Relationships',question:'My Rasi is Meena. How can I improve communication in my relationship?',dialogue:[{role:'assistant',content:'Birth time is unknown.'}]},async(_,options)=>{
  assert.match(JSON.parse(options.body).messages[0].content,/Do not repeat the birth-time limitation/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'Choose a calm moment to explain what has been bothering you. Listen to their reply before deciding on your next step.'})}}]});
 });
 assert.match(result.answer,/calm moment/);assert.doesNotMatch(result.answer,/birth time|can’t confirm/);assert.equal(result.calls.length,1);
});

test('unified unknown-time conversation explains useful practical context without inventing astrology',async()=>{
 const answer=('While waiting for the official result, keep your documents ready and review what the next stage requires. ').repeat(10).trim();
 const dialogue=Array.from({length:32},(_,i)=>({role:i%2?'assistant':'user',content:i===30?'I have already completed my application.':`Previous exam discussion ${i}.`}));
 const memory=['I prefer a bank role near my family.'];
 const result=await limitedBirthGuidance({OPENROUTER_API_KEY:'mock',OPENROUTER_MODEL:'google/gemini-2.5-flash'},{...input,depth:'standard',responseMode:'conversation',conversationMemory:memory,dialogue},async(url,options)=>{
  assert.match(url,/openrouter/);
  const body=JSON.parse(options.body),context=JSON.parse(body.messages[1].content);
  assert.equal(body.model,'google/gemini-2.5-flash');assert.ok(body.max_tokens>1200);
  assert.deepEqual(context.conversation_context,dialogue);assert.deepEqual(context.last_exchange,dialogue.slice(-2));
  assert.deepEqual(context.earlier_user_statements,memory);
  assert.equal(context.chart,undefined);assert.equal(context.hour,undefined);
  assert.match(body.messages[0].content,/completed actions/);
  assert.doesNotMatch(body.messages[0].content,/at most 55 words|at most 90 words/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer})}}]});
 });
 assert.ok(answer.split(/\s+/).length>110);assert.equal(result.answer,answer);assert.equal(result.calls.length,1);
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
  assert.equal(calls,1);assert.match(result.answer,/documents/);
  assert.equal(result.calls[0][kind==='transport'?'status':'validation'],kind==='transport'?'delivery_uncertain':'truncated_output');
 }
});
