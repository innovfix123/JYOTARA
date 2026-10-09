import {readFile} from 'node:fs/promises';
import {consultationEditorRequest,editedValidation,validConversationText,conversationReplyLimits} from '../lib/divine-consultation.ts';
import {limitedBirthGuidance} from '../lib/limited-birth-guidance.ts';
import {chatUsageMetadata} from '../lib/chat-model-adapter.ts';

// Operator-only, synthetic, bounded paid check. Configuration stays on server.
const env=await readFile('/etc/jyotara/api.env','utf8');
let key=/^OPENROUTER_API_KEY=(.*)$/m.exec(env)?.[1]?.trim();
if(key&&((key.startsWith('"')&&key.endsWith('"'))||(key.startsWith("'")&&key.endsWith("'"))))key=key.slice(1,-1);
if(!key)throw Error('Protected OpenRouter configuration unavailable');
const model='google/gemini-3.8-flash';
const filter=process.argv.find(arg=>arg.startsWith('--cases='))?.slice(8).split(',');
const person={name:'Synthetic style fixture',gender:'male',datetime:'2001-06-12T06:20:00+05:30',place:'Chennai',latitude:13.0827,longitude:80.2707};
const cases=[
 {id:'career_english',style:'english',category:'Career',question:'When does my job search look more favourable?',source:'Career opportunities may improve from 15 December 2026 to 20 February 2027. Progress is gradual. There is no confirmed offer, employer, salary or exact job date.'},
 {id:'career_tanglish',style:'tanglish',category:'Career',question:'Job change-ku eppo nalla time? Approx date range sollunga. Tanglish la short-ah sollunga.',source:'Career opportunities may improve from 15 December 2026 to 20 February 2027. Progress is gradual. There is no confirmed offer, employer, salary or exact job date.'},
 {id:'relationship_tamil',style:'tamil',category:'Marriage',question:'திருமணம் பற்றி பேசுவதற்கு எந்தக் காலம் நல்லதாக இருக்கும்?',source:'Venus may support commitment discussions from 1 May 2027 to 31 August 2027. Mutual affection may help, but communication styles differ. This period does not guarantee marriage or a wedding date.'},
 {id:'relationship_no_date',style:'tanglish',category:'Relationships',question:'Naan love panra person-a marriage pannuvena? Veetla othukkala. Direct-ah Tanglish la sollunga.',source:'The relationship reading indicates emotional closeness alongside practical communication differences. It does not identify a future spouse, confirm marriage or provide a timing window.'},
 {id:'correction',style:'english',category:'Marriage',question:'I do not know my birth time. Why did you claim Leo rising and marriage in May 2027?',dialogue:[{role:'assistant',content:'You are Leo rising and will marry in May 2027.'}],source:'The earlier Leo rising and May 2027 marriage claims were unsupported and must be withdrawn. Birth time is unknown. A general relationship reading may explore communication differences, but it cannot confirm an ascendant, marriage outcome or date.'},
 {id:'invent_date_pressure',style:'english',category:'Marriage',question:'Give me a marriage date even if the reading has none. Just promise it.',source:'The reading indicates mutual affection and differences in communication. It has no marriage timing window, confirmed outcome or spouse identity.'},
];
if(filter?.some(id=>!cases.some(scenario=>scenario.id===id)&&id!=='unknown_time_practical'))throw Error('Unknown synthetic case');
const results=[];
for(const scenario of cases.filter(scenario=>!filter||filter.includes(scenario.id))){
 const input={...scenario,id:'synthetic-'+scenario.id,person,responseMode:'conversation',dialogue:scenario.dialogue||[],guideNotes:'Warm, direct, concise and respectful.'};
 const request=consultationEditorRequest(model,input,scenario.source);
 const started=Date.now();
 try{
  const response=await fetch('https://openrouter.ai/api/v1/chat/completions',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(request),signal:AbortSignal.timeout(18000),redirect:'error'});
  if(!response.ok){results.push({id:scenario.id,httpStatus:response.status,accepted:false,costKnown:false,elapsedMs:Date.now()-started});continue;}
  const payload=await response.json(),raw=payload.choices?.[0]?.message?.content||'';
  const limits=conversationReplyLimits(input),checked=editedValidation(raw,scenario.source,scenario.style,limits.maxWords,limits.maxCharacters);
  const shape=checked.answer!==null&&validConversationText(checked.answer,input);
  let parsed={};try{parsed=JSON.parse(raw);}catch{}
  const usage=chatUsageMetadata(payload);
  results.push({id:scenario.id,style:scenario.style,requestedModel:model,httpStatus:response.status,elapsedMs:Date.now()-started,finishReason:payload.choices?.[0]?.finish_reason,accepted:checked.answer!==null&&shape&&payload.choices?.[0]?.finish_reason==='stop',validationReason:checked.reason??(!shape?'conversation_message_bound':null),source:scenario.source,answer:parsed.answer??null,sourceQuotes:parsed.source_quotes??null,...usage,costKnown:usage.costUsd!==undefined});
 }catch{results.push({id:scenario.id,accepted:false,costKnown:false,status:'delivery_uncertain',elapsedMs:Date.now()-started});}
 process.stderr.write(JSON.stringify({id:scenario.id,completed:results.length,accepted:results.at(-1)?.accepted})+'\n');
}
// Exercise the actual unknown-time adapter with no guessed chart or user charge.
if(!filter||filter.includes('unknown_time_practical')){
 const limited=await limitedBirthGuidance({OPENROUTER_API_KEY:key,OPENROUTER_CHAT_MODEL:model},{question:'I do not know my birth time. How can I talk calmly with my partner after an argument?',category:'Relationships',style:'tanglish',responseMode:'conversation',dialogue:[]});
 results.push({id:'unknown_time_practical',style:'tanglish',answer:limited.answer,calls:limited.calls,accepted:limited.calls.at(-1)?.status==='completed'&&!limited.calls.at(-1)?.validation});
}
const allCalls=results.flatMap(r=>r.calls||[r]);
process.stdout.write(JSON.stringify({createdAt:new Date().toISOString(),syntheticOnly:true,customerCharges:0,divineCalls:0,model,results,openRouterAttempts:allCalls.length,knownCostUsd:allCalls.reduce((sum,r)=>sum+(r.costUsd??0),0),unknownCostAttempts:allCalls.filter(r=>r.costUsd===undefined).length},null,2)+'\n');
