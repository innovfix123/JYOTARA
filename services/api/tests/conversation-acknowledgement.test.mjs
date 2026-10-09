import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {localConversationAcknowledgement}=await import(moduleFor('../lib/conversation-acknowledgement.ts'));
const turn=(question,extra={})=>({question,responseMode:'conversation',...extra});

test('standalone length preferences, thanks and goodbyes receive deterministic selected-language copy',()=>{
 for(const [style,question,answer] of [
  ['english',' Please keep it brief! ','Sure, I’ll keep replies brief.'],
  ['english','THANK YOU.','You’re welcome.'],
  ['tamil','சுருக்கமாகப் பதில் சொல்லுங்கள்.','சரி, சுருக்கமாகப் பதில் சொல்கிறேன்.'],
  ['tamil','நன்றி','மகிழ்ச்சி.'],
  ['tanglish','Surukkama sollunga.','Sari, surukkama badhil solren.'],
  ['tanglish','Appuram pesalaam.','Nalama irunga. Appuram pesalaam.'],
 ])assert.equal(localConversationAcknowledgement(turn(question,{style})),answer,question);
 // The selected reply style is authoritative, not the language of the phrase.
 assert.equal(localConversationAcknowledgement(turn('Thanks',{style:'tamil'})),'மகிழ்ச்சி.');
 const userMessageBatch=['Please keep it brief','Thank you','Bye'];
 assert.equal(localConversationAcknowledgement(turn(userMessageBatch.join('\n'),{userMessageBatch})),'Take care. Bye for now.');
});

test('substantive questions, factual answers and mixed batches always use normal reading handling',()=>{
 for(const question of [
  'Thanks, what does my chart say about career?',
  'Please keep it brief: will I get a job?',
  'Please keep it brief. Will I get a job?',
  'Thank you. I want to know about marriage.',
  'I am changing jobs.',
  'Yes','Okay','No','English please','Reply in Tamil','Explain more','What next?',
 ])assert.equal(localConversationAcknowledgement(turn(question)),null,question);
 for(const userMessageBatch of [
  ['Please keep it brief','Will I get a job?'],
  ['Does my chart indicate career growth?','Please keep it brief'],
  ['Thanks','I work as a teacher.'],
 ])assert.equal(localConversationAcknowledgement(turn(userMessageBatch.join('\n'),{userMessageBatch})),null);
});

test('the local decision enforces canonical question and batch binding, bounds and conversational mode',()=>{
 assert.equal(localConversationAcknowledgement(turn('Will I get a job?',{userMessageBatch:['Thanks']})),null);
 assert.equal(localConversationAcknowledgement(turn('Thanks',{userMessageBatch:['Will I get a job?']})),null);
 assert.equal(localConversationAcknowledgement(turn(undefined,{userMessageBatch:['Thanks']})),'You’re welcome.');
 for(const extra of [{responseMode:undefined},{responseMode:'legacy'},{userMessageBatch:[]},{userMessageBatch:['Thanks',null]},{userMessageBatch:Array(5).fill('Thanks')}]){
  assert.equal(localConversationAcknowledgement(turn('Thanks',extra)),null);
 }
 assert.equal(localConversationAcknowledgement(turn('Thanks '.repeat(40))),null);
});

test('hidden content, question punctuation and non-whitelisted Unicode punctuation are rejected',()=>{
 for(const question of ['Thanks?','Thanks？','Thanks\u200b','Please\u200d keep it brief','Thanks\u0000','Thanks\n','Thanks。','Thanks！','Ｔｈａｎｋｓ','Thanks....','Thanks;']){
  // A trailing newline is trimmed by the canonical request contract; unlike
  // hidden content inside a turn it cannot carry an additional question.
  assert.equal(localConversationAcknowledgement(turn(question)),question==='Thanks\n'?'You’re welcome.':null,question);
 }
 assert.equal(localConversationAcknowledgement(turn('Thanks\nPlease keep it brief')),null);
});
