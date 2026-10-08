import test from 'node:test';
import assert from 'node:assert/strict';
import {moduleFor} from './helpers/load.mjs';
const {issueChartTicket}=await import(moduleFor('../lib/chart-ticket.ts'));
test('Divine-only handler helps without complete birth metadata while rejecting identity overrides and malformed inputs without provider calls',async()=>{
 const secret='ab'.repeat(32),old=globalThis.fetch;let calls=0;
 globalThis.fetch=()=>{calls++;throw Error('Unexpected provider request');};
 globalThis.__divineTestEnv={JYOTARA_CHART_TICKET_KEY:secret,DB:{prepare(){return{bind(){return this;},async first(){return null;},async run(){return{meta:{changes:1}};}};}}};
 try{
  const {POST}=await import(moduleFor('../app/api/guidance/route.ts'));
  const chart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',planets:[],yogas:[]};
  const chartTicket=await issueChartTicket(secret,{sessionId:'owner',profileId:'one',birthTimeKnown:true,chart});
  const base={requestId:'request-valid-0001',profileId:'one',chartTicket,question:'When will I get married?',category:'Marriage',language:'en',responseStyle:'english'};
  const send=body=>POST(new Request('https://test',{method:'POST',headers:{cookie:'nirayana_pilot_session=owner'},body:JSON.stringify(body)}));
  const answer=await (await send(base)).json();assert.equal(answer.answerMode,'limited_guidance');assert.doesNotMatch(answer.answer,/confirm your saved|birth time/);assert.equal(calls,0);
  assert.equal((await send({...base,profileId:'other'})).status,401);
  assert.equal((await send({...base,chartTicket:'tampered'})).status,401);
  assert.equal((await send({...base,question:''})).status,400);
  assert.equal((await send({...base,requestId:{}})).status,400);
  const safety=await (await send({...base,requestId:'request-safety-0001',question:'How is my parents health?'})).json();
  assert.equal(safety.answerMode,'grounded_fallback');assert.equal(calls,0);
  // Unknown time is an ordinary conversation path, not a repeated setup prompt.
  globalThis.__divineTestEnv.OPENROUTER_API_KEY='test-only';
  let captured;
  globalThis.fetch=async(url,options)=>{
    calls++;assert.match(url,/openrouter/);const payload=JSON.parse(options.body);
    captured=JSON.parse(payload.messages[1].content);
    return Response.json({choices:[{finish_reason:'stop',message:{content:JSON.stringify({answer:'Compare the role requirements with your current skills. Choose one skill to practise before applying.'})}}]});
  };
  const unknownTicket=await issueChartTicket(secret,{sessionId:'owner',profileId:'unknown',birthTimeKnown:false,chart});
  const unknown=await (await send({...base,requestId:'unknown-career-0001',profileId:'unknown',chartTicket:unknownTicket,question:'How can I prepare for my future job?',category:'Career',reportPerson:{profession:'Student'}})).json();
  assert.equal(unknown.answerMode,'limited_guidance');assert.match(unknown.answer,/skills/);assert.doesNotMatch(unknown.answer,/birth time|confirm your saved/);
  assert.deepEqual(captured.self_reported_profile,{profession:'Student'});assert.equal(captured.chart,undefined);assert.equal(calls,1);
 }finally{globalThis.fetch=old;delete globalThis.__divineTestEnv;}
});
