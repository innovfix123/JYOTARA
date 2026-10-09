import {readFile} from 'node:fs/promises';
import {consultationEditorRequest,editedValidation,validConversationText,conversationReplyLimits} from '../lib/divine-consultation.ts';
import {chatUsageMetadata} from '../lib/chat-model-adapter.ts';

// Run the bundled script over authenticated SSH. The protected key stays on
// the server and is never written into the bundle, report, or command line.
const env=await readFile('/etc/jyotara/api.env','utf8');
let key=/^OPENROUTER_API_KEY=(.*)$/m.exec(env)?.[1]?.trim();
if(key&&((key.startsWith('"')&&key.endsWith('"'))||(key.startsWith("'")&&key.endsWith("'"))))key=key.slice(1,-1);
if(!key)throw Error('Protected OpenRouter configuration unavailable');

const person={name:'Synthetic editor fixture',gender:'male',datetime:'2001-06-12T06:20:00+05:30',place:'Chennai',latitude:13.0827,longitude:80.2707};
const natalChart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',lagna:'Mithuna',lagnaLord:'Mercury',planets:[
  {name:'Mercury',rasi:'Mithuna',position:3,degree:10,isRetrograde:false},
  {name:'Venus',rasi:'Tula',position:7,degree:20,isRetrograde:false},
]};
const source='Mercury is the supplied ascendant lord. The Mercury-Venus period may support patient discussion about work and family choices, but it cannot guarantee an outcome. Mercury and Venus are in different natal signs; this period is not a conjunction. A lower-paid day-shift role may allow more regular sleep and family time, depending on the actual schedule. A higher-paid night-shift role may improve income, but fatigue could make the routine harder to sustain. Neither role is certain to be the better choice. Compare confirmed pay, working hours and your wellbeing before deciding.';
const cases=[
  {id:'english_tradeoff',style:'english',category:'Career',userMessageBatch:['The night job pays more, but I am tired after shifts.','My family already knows about both offers.','Explain how to compare it with a lower-paid day job.'],dialogue:[{role:'user',content:'I want a sustainable routine, not a guaranteed prediction.'},{role:'assistant',content:'We can separate the traditional indication from the practical trade-offs.'}],conversationMemory:['Both offers have already been discussed with my family.']},
  {id:'tamil_tradeoff',style:'tamil',category:'Career',userMessageBatch:['இரவு வேலைக்கு சம்பளம் அதிகம். ஆனால் வேலை முடிந்ததும் சோர்வாக இருக்கிறேன்.','இரு வேலை வாய்ப்புகளையும் பற்றி குடும்பத்திடம் ஏற்கனவே பேசிவிட்டேன்.','குறைந்த சம்பளமுள்ள பகல் வேலைக்கும் இதற்கும் உள்ள சாதக பாதகங்களை விளக்குங்கள்.'],dialogue:[{role:'user',content:'எனக்கு நீடித்த தினசரி நடைமுறை வேண்டும். உறுதியான கணிப்பு வேண்டாம்.'},{role:'assistant',content:'ஜாதகக் குறிப்பையும் நடைமுறை விஷயங்களையும் தனித்தனியாகப் பார்க்கலாம்.'}],conversationMemory:['இரு வேலை வாய்ப்புகளும் குடும்பத்துக்கு ஏற்கனவே தெரியும்.']},
  {id:'tanglish_tradeoff',style:'tanglish',category:'Career',userMessageBatch:['Night job-la salary adhigam, aana shift mudinja romba tired-a irukken.','Rendu offer pathiyum veetla already pesitten.','Konjam kammi salary day job-oda compare panni kaaranangalai sollunga.'],dialogue:[{role:'user',content:'Enakku sustainable routine venum; fixed prediction vendaam.'},{role:'assistant',content:'Chart kurippaiyum practical vishayangalaiyum thanithaniya paarkalaam.'}],conversationMemory:['Rendu offer pathiyum family-kku already theriyum.']},
  {id:'english_latest_correction',style:'english',category:'Relationships',userMessageBatch:['Correction: the late reply was because of work, not dishonesty.','We already agreed to give each other space.','What can I do while waiting without sending another message?'],dialogue:[{role:'user',content:'My partner replied late. I wondered whether something was wrong.'},{role:'assistant',content:'A late reply alone does not establish dishonesty.'},{role:'user',content:'I asked about it and learned that they were working.'},{role:'assistant',content:'That explanation changes the context.'}],conversationMemory:['My partner and I agreed to wait without contacting each other.']},
];
const results=[];
for(const scenario of cases) {
  for(const model of ['google/gemini-2.5-flash','openai/gpt-6.1-sol']) {
    const input={...scenario,id:'synthetic-'+scenario.id,person,natalChart,responseMode:'conversation',question:scenario.userMessageBatch.join('\n'),guideNotes:'Warm, thoughtful and direct. Do not invent feelings or repeat a step already completed.'};
    const reading=scenario.id==='english_latest_correction'?'The supplied reading cannot establish dishonesty or whether someone will reply. A traditional relationship theme may invite patient discussion, but it cannot determine another person’s private actions or decisions. Follow the user’s reported work explanation and agreed waiting boundary.':source;
    const request=consultationEditorRequest(model,input,reading);
    const started=Date.now();
    let response;
    try {
      response=await fetch('https://openrouter.ai/api/v1/chat/completions',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json'},body:JSON.stringify(request),signal:AbortSignal.timeout(35000),redirect:'error'});
      if(!response.ok) {results.push({case:scenario.id,model,httpStatus:response.status,elapsedMs:Date.now()-started,accepted:false,costKnown:false});continue;}
      const payload=await response.json();
      const raw=payload.choices?.[0]?.message?.content||'';
      const limits=conversationReplyLimits(input);
      const checked=editedValidation(raw,reading,scenario.style,limits.maxWords,limits.maxCharacters);
      const shape=checked.answer!==null&&validConversationText(checked.answer,input);
      const usage=chatUsageMetadata(payload);
      const parsed=(()=>{try{return JSON.parse(raw);}catch{return {};}})();
      results.push({case:scenario.id,style:scenario.style,model,httpStatus:response.status,elapsedMs:Date.now()-started,finishReason:payload.choices?.[0]?.finish_reason,accepted:checked.answer!==null&&shape&&payload.choices?.[0]?.finish_reason!=='length',validationReason:checked.reason??(!shape?'conversation_message_bound':null),answer:parsed.answer??null,sourceQuotes:parsed.source_quotes??null,messageCount:typeof parsed.answer==='string'?parsed.answer.trim().split(/\n+/).filter(Boolean).length:null,...usage,costKnown:usage.costUsd!==undefined});
    }catch {
      // No retries: an uncertain provider delivery may already have incurred cost.
      results.push({case:scenario.id,model,elapsedMs:Date.now()-started,accepted:false,status:'delivery_uncertain',costKnown:false});
    }
    process.stderr.write(JSON.stringify({case:scenario.id,model,completed:results.length})+'\n');
  }
}
process.stdout.write(JSON.stringify({createdAt:new Date().toISOString(),syntheticOnly:true,divineCalls:0,openRouterAttempts:results.length,knownInferenceCostUsd:results.reduce((sum,result)=>sum+(result.costUsd??0),0),unknownCostAttempts:results.filter(result=>!result.costKnown).length,results},null,2)+'\n');
