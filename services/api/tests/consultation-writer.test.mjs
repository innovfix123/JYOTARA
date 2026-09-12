import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const source=readFileSync(new URL('../lib/consultation-writer.ts',import.meta.url),'utf8');
const js=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {writeConsultation,parseReviewedReply,replyShapeErrors,consultationMode}=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const context={question:'Does this mean she is cheating?',language:'English',category:'Relationships',dialogue:[{role:'user',content:'She replies late.'},{role:'assistant',content:'Venus means she is cheating.'}],evidence:[{id:'house',text:'Venus is in the eleventh house. Traditionally this connects romance with shared hopes.'}]};
test('fabricated citations and citations to dialogue cannot authorize a claim',()=>{
 const review={answer:'Venus shows she is cheating. Ask her about it.',claims:[{claim:'Venus shows she is cheating',sourceId:'house',quote:'Venus means she is cheating.'}],corrections:[]};
 assert.equal(parseReviewedReply(JSON.stringify(review),context).value,null);
 review.claims[0].sourceId='dialogue';assert.equal(parseReviewedReply(JSON.stringify(review),context).value,null);
});
test('malformed review never exposes the unchecked draft, even after retry',async()=>{
 const requests=[];const result=await writeConsultation(context,async r=>{requests.push(r);return requests.length===1?'Your partner is cheating. Venus proves it.':'not JSON';});
 assert.equal(result.answer,null);assert.equal(requests.length,3);
 assert.match(requests[2].input.at(-1).content,/review must be JSON/);
});
test('final review replaces unsupported draft and carries ordered context',async()=>{
 const answer='Late replies alone do not establish cheating. Ask her what communication rhythm works for both of you.';
 const calls=[];const result=await writeConsultation(context,async r=>{calls.push(r);return calls.length===1?'Venus proves cheating. Leave her.':JSON.stringify({answer,claims:[],corrections:['Removed unsupported cheating inference.']});});
 assert.equal(result.answer,answer);assert.equal(calls.length,2);
 assert.deepEqual(JSON.parse(calls[1].input.at(-1).content).dialogue,context.dialogue);
});
test('length violation triggers revision instead of truncating the direct answer',async()=>{
 let count=0;const answer='This placement traditionally connects romance with shared hopes. It does not reveal your partner’s intentions.';
 const result=await writeConsultation(context,async()=>{
  count++;if(count===1)return 'draft';
  return JSON.stringify({answer:count===2?'Word '.repeat(90)+'. Another sentence.':answer,claims:[],corrections:[]});
 });assert.equal(count,3);assert.equal(result.answer,answer);
});
test('shape gate checks full answer and language, including questions inside quotes',()=>{
 assert.ok(replyShapeErrors('Ask “Why?” What happened?','English').includes('more than one question'));
 assert.ok(replyShapeErrors('உங்கள் ஜாதகம். இதைப் பாருங்கள்.','Tanglish').length);
 assert.ok(replyShapeErrors('One. Two. Three. Four. Five.','English').length);
 assert.deepEqual(replyShapeErrors('Take your time before deciding. What matters most to you?','English'),[]);
});

test('practical follow-up cannot receive chart documents, while new readings retain them',async()=>{
 const requests=[];
 await writeConsultation({...context,question:'I asked that. She said she needs two months. Should I wait?'},async r=>{
  requests.push(JSON.parse(r.input.at(-1).content));
  return requests.length===1?'Agree on what the pause means. Decide whether that works for you.':JSON.stringify({answer:'Agree on what the pause means. Decide whether that works for you.',claims:[],corrections:[]});
 });
 assert.ok(requests.every(r=>r.evidence.length===0));
 assert.equal(consultationMode('What career themes are visible in my chart?',context.dialogue),'reading');
 assert.equal(consultationMode('நீங்கள் கூறிய கிரக அமைப்பை எளிய தமிழில் விளக்குங்கள்.',context.dialogue),'explain');
});

test('timing clarification can mention a planet without inventing a placement', async()=>{
 const answer='A Jupiter period does not guarantee a wedding. Meeting someone and choosing marriage still matter.';
 let calls=0;
 const result=await writeConsultation({...context,question:'Please explain your answer in just two sentences.'},async()=>++calls===1?answer:JSON.stringify({answer,claims:[],corrections:[]}));
 assert.equal(result.answer,answer);
 assert.equal(consultationMode('Please explain your answer in just two sentences.',context.dialogue),'explain');
});
test('citation retry identifies invented quote and rejects it again',async()=>{
 const reading={...context,question:'What does my chart say?',evidence:[{id:'house',text:'Venus is in the eleventh house.'}]};
 const requests=[];
 const result=await writeConsultation(reading,async r=>{
  requests.push(r);return requests.length===1?'draft':JSON.stringify({answer:'Venus is in the seventh house. Let us discuss relationships.',claims:[{claim:'Venus is in the seventh house',sourceId:'house',quote:'Venus is in the seventh house.'}],corrections:[]});
 });
 assert.equal(result.answer,null);
 assert.match(requests[2].input.at(-1).content,/Citation not found in document house/);
});

test('Tamil selection rejects mostly Tanglish even if it contains a few Tamil words',()=>{
 assert.ok(replyShapeErrors('Ava night shift nu sonna pressure illaama கேளுங்க. Oru message mattum anuppunga.', 'tamil').some(e=>e.includes('predominantly')));
 assert.deepEqual(replyShapeErrors('அவர் இரவு வேலை செய்வதால் பகலில் ஓய்வு தேவைப்படலாம். ஓய்வு எடுத்த பிறகு பேச வசதியான நேரத்தைச் சொல்லச் சொல்லுங்கள்.', 'tamil'),[]);
});
