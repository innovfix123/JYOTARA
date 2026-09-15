import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../lib/divine-consultation.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {divineBirth,divineConsultation,parseEdited,validChatText}=await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
const person={datetime:'2001-06-12T06:20:00+05:30',latitude:13.0827,longitude:80.2707,name:'Test alias',gender:'male',place:'Chennai'};
const input={id:'opaque-request',person,question:'Is marriage favoured?',style:'english',category:'Marriage',guide:'Tharagai',dialogue:[{role:'user',content:'My family has started looking.'}]};
const config={DIVINE_API_KEY:'test',OPENROUTER_API_KEY:'test',OPENROUTER_MODEL:'google/gemini-2.5-flash'};
const reading='Venus may favour commitment. Family discussions may progress slowly.';
const edited={answer:reading,source_quotes:['Venus may favour commitment.']};
const db=()=>{const ops=[];return {ops,prepare(sql){return{bind(...args){return{async run(){ops.push({sql,args});}};}};}};};
test('long formatted provider reading reaches editor while final answer stays short',async()=>{
 const source='## Reading\n'+reading+'\n'+('Traditional chart interpretation with conditions. '.repeat(90))+'**Summary**';
 let edits=0;
 const result=await divineConsultation(config,input,db(),async(url,opts)=>{
  if(opts.method==='DELETE')return Response.json({deleted:true});
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
  if(opts.method==='DELETE')return Response.json({deleted:true});
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
  if(opts.method==='DELETE')return Response.json({detail:'unknown api_key'},{status:401});
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
   if(opts.method==='DELETE')return Response.json({deleted:true});
   if(url.includes('ask.divine'))return Response.json({answer:reading,credits_charged:30});
   return Response.json({choices:[{message:{content},finish_reason:finish}],usage:{cost:0.0004}});
  });
  assert.equal(result.answer,null);
  assert.deepEqual(result.calls[1],{provider:'openrouter',model:config.OPENROUTER_MODEL,status:'completed',costUsd:0.0004,validation});
 }
});
