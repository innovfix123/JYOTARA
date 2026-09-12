// Run the production writer against a frozen, fictional conversation corpus.
// No credentials or personal data belong in this file or output.
import {build} from 'esbuild';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const baseline=process.argv[2], destination=process.argv[3];
if(!baseline||!destination)throw Error('Usage: node scripts/replay-consultations.mjs BASELINE OUTPUT');
await mkdir(destination,{recursive:true});
await build({entryPoints:['lib/consultation-writer.ts'],outfile:path.join(destination,'writer.mjs'),platform:'node',format:'esm',bundle:true});
await build({entryPoints:['lib/guidance-language.ts'],outfile:path.join(destination,'language.mjs'),platform:'node',format:'esm',bundle:true});
const {writeConsultation,evidenceDocuments,consultationVersion}=await import(pathToFileURL(path.join(destination,'writer.mjs')));
const {conversationTopic}=await import(pathToFileURL(path.join(destination,'language.mjs')));
const config=Object.fromEntries((await readFile('/Users/apple/.config/jyotara/model.env','utf8')).split('\n').filter(l=>l.includes('=')&&!l.startsWith('#')).map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1).trim().replace(/^["']|["']$/g,'')]}));
const protocol=JSON.parse(await readFile(path.join(baseline,'protocol.json')));
await writeFile(path.join(destination,'protocol.json'),JSON.stringify({...protocol,version:consultationVersion,mode:'Frozen authentic provider evidence replay with production writer. No new Divine calls; live route integration verified separately.'},null,2));
function extract(r){return r.output_text||r.output?.flatMap(o=>o.content||[]).map(c=>c.text||'').join('\n')||'';}
async function group(index){
 const dialogue=[];
 for(let turn=0;turn<10;turn++){
  const id=index*10+turn+1, tag=String(id).padStart(2,'0'), file=path.join(destination,tag+'.json');
  try {const previous=JSON.parse(await readFile(file));if(previous.answer){dialogue.push({role:'user',content:previous.question},{role:'assistant',content:previous.answer});continue;}}catch{}
  const [originalCategory,question]=protocol.questions[index][turn];
  const category=conversationTopic(question,originalCategory,dialogue.filter(t=>t.role==='user').map(t=>t.content));
  const bhava=JSON.parse(await readFile(path.join(baseline,'provider',`question-${tag}-bhava.json`))).response.data;
  const basic=JSON.parse(await readFile(path.join(baseline,'provider',`profile-${index+1}-basic.json`))).response.data;
  const dasha=JSON.parse(await readFile(path.join(baseline,'provider',`profile-${index+1}-dasha.json`))).response.data;
  const relevant={Love:[5,7,11],Relationships:[5,7,2],Breakup:[5,7,12],Marriage:[7,2,11],Family:[2,4,7],Career:[10,6,11],Business:[7,10,2],Money:[2,11,10],Education:[4,5,9],Daily:[1,4,9]}[category]||[1,4,9];
  const context={question,category,language:protocol.languages[index],dialogue:[...dialogue],evidence:evidenceDocuments({basic,house_interpretations:bhava.houses.filter(h=>relevant.includes(h.house_no)),dasha_periods:dasha})};
  const calls=[]; const start=Date.now();
  try{
   const result=await writeConsultation(context,async request=>{
    const start=Date.now();
    const response=await fetch('https://openrouter.ai/api/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${config.OPENROUTER_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({model:config.OPENROUTER_MODEL||'openai/gpt-5.4',store:false,...request}),signal:AbortSignal.timeout(25000)});
    const payload=await response.json();if(!response.ok)throw Error(`Model HTTP ${response.status}`);
    const text=extract(payload);calls.push({seconds:(Date.now()-start)/1000,usage:payload.usage,model:payload.model,output:text});return text;
   });
   await writeFile(file,JSON.stringify({id,group:index+1,question,originalCategory,category,language:context.language,...result,seconds:(Date.now()-start)/1000,calls,context},null,2));
   if(result.answer)dialogue.push({role:'user',content:question},{role:'assistant',content:result.answer});
   console.log(JSON.stringify({id,ok:!!result.answer,attempts:result.attempts,seconds:(Date.now()-start)/1000}));
  }catch(error){await writeFile(file,JSON.stringify({id,question,error:error.message,calls,context},null,2));console.log(JSON.stringify({id,error:error.message}));}
 }
}
// Independent conversations, ordered turns within each conversation.
for(let i=0;i<protocol.questions.length;i+=3)await Promise.all(Array.from({length:Math.min(3,protocol.questions.length-i)},(_,n)=>group(i+n)));
console.log('REPLAY COMPLETE');
