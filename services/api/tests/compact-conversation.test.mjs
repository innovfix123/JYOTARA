import test from 'node:test';
import assert from 'node:assert/strict';
import {moduleFor} from './helpers/load.mjs';
const {divineConsultation,consultationEditorRequest,validConversationText,conversationReplyLimits}=await import(moduleFor('../lib/divine-consultation.ts'));
const config={DIVINE_API_KEY:'fixture',DIVINE_ACCESS_TOKEN:'fixture',OPENROUTER_API_KEY:'fixture',OPENROUTER_CHAT_MODEL:'google/gemini-3.8-flash'};
const input={id:'synthetic-compact',person:{name:'Synthetic fixture',gender:'male',datetime:'2001-06-12T06:20:00+05:30',place:'Chennai',latitude:13.0827,longitude:80.2707},category:'Career',responseMode:'conversation',dialogue:[]};
const source='Career opportunities may improve from 15 December 2026 to 20 February 2027. Progress is gradual. This does not confirm an offer, employer or exact job date.';
const db=()=>({prepare(){return {bind(){return {async run(){}};}};}});

test('a paragraph below the total word cap still fails the individual bubble cap',()=>{
 const paragraph='Your reading suggests that career opportunities may improve gradually when you consider relevant opportunities carefully and remain open to discussion, but this does not confirm an offer, a particular employer, a salary increase or a precise date for starting a new job.';
 assert.ok(paragraph.split(/\s+/).length<65);
 assert.ok(paragraph.split(/\s+/).length>32);
 assert.equal(validConversationText(paragraph),false);
 assert.equal(validConversationText(''),false);
});

for(const [style,question,answer] of [
 ['english','When does my job search look more favourable?','15 December 2026 to 20 February 2027 may be a more supportive period for your job search.\n\nProgress looks gradual; this does not confirm an offer or an exact joining date.\n\nAre you changing jobs or looking for your first role?'],
 ['tamil','வேலை தேடுவதற்கு எந்தக் காலம் சாதகமாக இருக்கும்?','15 டிசம்பர் 2026 முதல் 20 பிப்ரவரி 2027 வரை வேலை தேடுவதற்கு ஆதரவு இருக்கலாம்.\n\nமுன்னேற்றம் படிப்படியாக அமையலாம்; வேலை கிடைக்கும் நாளை இது உறுதி செய்யவில்லை.\n\nபுதிய வேலைக்கு மாறுகிறீர்களா, அல்லது முதல் வேலையைத் தேடுகிறீர்களா?'],
 ['tanglish','Job search-ku eppo nalla time?','15 December 2026 mudhal 20 February 2027 varai unga job search-ku aadharavu irukkalaam.\n\nMunnetram padippadiya irukkalaam; idhu offer-aiyo joining date-aiyo confirm pannala.\n\nVelai maarreengala, illa mudhal velai thedureengala?'],
]) test('compact '+style+' answer preserves timing and uncertainty and ends with one question',async()=>{
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,style,question},db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(String(url).includes('ask.divine')){reads++;return Response.json({answer:source,credits_charged:30});}
  edits++;const request=JSON.parse(options.body);
  assert.match(request.messages[0].content,/end with one short, relevant question in its own final message/);
  assert.match(request.messages[0].content,/never ask again for information already supplied/);
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer,source_quotes:[source]})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,1);
 assert.equal(answer.split(/\n\n/).length,3);assert.equal(answer.match(/\?/g).length,1);assert.ok(answer.endsWith('?'));
 assert.equal(validConversationText(answer),true);
});

test('oversized single bubble is repaired without repeating the paid Divine reading',async()=>{
 const oversized=Array(3).fill('Career opportunities may improve gradually, but this does not confirm an offer or an exact job date.').join(' ');
 const answer='Your job search may become more supportive from 15 December 2026 to 20 February 2027, with gradual progress.\n\nAre you looking for a new role or growth in your current job?';
 let reads=0,edits=0;
 const result=await divineConsultation(config,{...input,style:'english',question:'When is my career looking more supportive?'},db(),async(url,options)=>{
  if(String(url).endsWith('/session/delete'))return Response.json({deleted:true});
  if(String(url).includes('ask.divine')){reads++;return Response.json({answer:source,credits_charged:30});}
  edits++;const request=JSON.parse(options.body);
  if(edits===2){assert.match(request.messages.at(-1).content,/conversation_message_bound/);assert.match(request.messages.at(-1).content,/at most 32 words/);}
  return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:edits===1?oversized:answer,source_quotes:[source]})}}]});
 });
 assert.equal(result.answer,answer);assert.equal(reads,1);assert.equal(edits,2);
 assert.equal(result.calls[1].validationReason,'conversation_message_bound');
});

test('a follow-up uses the latest context and never trades the direct answer for a hook',()=>{
 const dialogue=[{role:'user',content:'I want to change jobs, and I already have two offers.'},{role:'assistant',content:'We can look at the timing while you compare them.'}];
 const request=consultationEditorRequest(config.OPENROUTER_CHAT_MODEL,{...input,style:'english',question:'Which period supports moving?',dialogue},source);
 assert.deepEqual(JSON.parse(request.messages[1].content).last_exchange,dialogue);
 assert.match(request.messages[0].content,/not permission to reveal an answer you already have/);
 assert.match(request.messages[0].content,/Respect a request for no questions/);
 assert.match(request.messages[0].content,/urgent safety guidance need no question/);
 assert.match(request.messages[0].content,/Do not omit a material condition/);
 assert.match(request.messages[0].content,/Never withhold the core answer/);
});

test('requesting detail permits a bounded explanation rather than a long report',()=>{
 const limits=conversationReplyLimits({question:'Explain more about that timing.'});
 assert.equal(limits.maxWords,110);assert.equal(limits.maxMessageWords,45);assert.equal(limits.maxMessages,4);
 const longParagraph=Array(3).fill('This period may support patient discussions when both people are comfortable, though the timing does not confirm any specific future outcome.').join(' ');
 assert.ok(longParagraph.split(/\s+/).length<110);
 assert.equal(validConversationText(longParagraph,{question:'Explain more.'}),false);
});
