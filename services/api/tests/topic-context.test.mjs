import {readFileSync} from 'node:fs';
import ts from 'typescript';
import test from 'node:test';
import assert from 'node:assert/strict';
const mod=async path=>import('data:text/javascript;base64,'+Buffer.from(ts.transpileModule(readFileSync(new URL(path,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.ES2022,target:ts.ScriptTarget.ES2022}}).outputText).toString('base64'));
const {buildTopicContext}=await mod('../lib/astrology-evidence.ts');
const {conversationTopic,conciseReply,acceptableAnswer}=await mod('../lib/guidance-language.ts');
const chart={rashi:'Meena',nakshatra:'Uttara Bhadrapada',lagna:'Mithuna',yogas:[],planets:[{name:'Jupiter',rasi:'Karka',position:4,degree:12,isRetrograde:false}]};
test('whole-sign domain houses and lords derive from supplied data, never birth-time guesses',()=>{
 const result=buildTopicContext(chart,'Career',true);
 assert.equal(result.houses[0].house,10);assert.equal(result.houses[0].sign,12);
 assert.equal(result.houses[0].lord,'Jupiter');assert.equal(result.houses[0].lordHouse,2);
 const unknown=buildTopicContext(chart,'Marriage',false);
 assert.deepEqual(unknown.houses,[]);assert.deepEqual(unknown.planets,[]);assert.equal(unknown.lagna,undefined);assert.equal(unknown.navamsa,undefined);assert.deepEqual(unknown.periods,{});
 for(const category of ['Love','Relationships','Breakup','Marriage','Family','Career','Business','Education','Property','Spiritual','Daily','Panchang'])assert.ok(buildTopicContext(chart,category,true).focus);
});
test('explicit topics override guide specialty across supported languages',()=>{
 assert.equal(conversationTopic('எனக்கு வேலை கிடைக்குமா?','Love'),'Career');
 assert.equal(conversationTopic('Should I start a business?','Education'),'Business');
 assert.equal(conversationTopic('என் திருமணம் பற்றி','Career'),'Marriage');
 assert.equal(conversationTopic('College studies','Daily'),'Education');
 assert.equal(conversationTopic('Tell me more','Relationships'),'Relationships');
 assert.equal(conversationTopic('Tell me more','Love',['Will I get a job?']),'Career');
 assert.equal(conversationTopic('Now about marriage','Love',['Will I get a job?']),'Marriage');
});

test('brief replies preserve complete quoted examples',()=>{
 const text='Start with an apology. You could say: “I was rude. I am sorry. Take the space you need.” Then listen. Extra advice can wait. A fourth statement is unnecessary.';
 const brief=conciseReply(text);
 assert.ok(brief.includes('“I was rude. I am sorry. Take the space you need.”'));
 assert.ok(!brief.includes('A fourth statement'));
 assert.equal(conciseReply('A clear answer.'),'A clear answer.');
});

test('natural negative guarantee wording is allowed, a separate guarantee is still rejected',()=>{
 assert.equal(acceptableAnswer('This is a traditional theme, not a guaranteed result.','english'),true);
 assert.equal(acceptableAnswer('This is not a guaranteed result. Your marriage is guaranteed.','english'),false);
});

test('one follow-up permits a quoted message question; Tamil duration is not a clock prediction',()=>{
 assert.equal(conciseReply('Both are possible. What matters most? What degree did you study?'),'Both are possible. What matters most?');
 assert.equal(acceptableAnswer('மாலை 5 நிமிடம் அமைதியாக இருக்கலாம்.','tamil'),true);
 assert.equal(acceptableAnswer('மாலை 2–3 நிமிடம் அமைதியாக இருக்கலாம்.','tamil'),true);
 assert.equal(acceptableAnswer('மாலை 5 மணி நல்ல நேரம்.','tamil'),false);
});

 test('four-part reading keeps the direct answer and one useful question',()=>{
 const reply='Your fifth-house lord Venus is in the eleventh house. Traditionally this connects romance with shared hopes. Discuss whether your plans for this relationship match. Have you talked about your future together?';
 assert.equal(conciseReply(reply),reply);
 assert.equal(conciseReply(reply+' What else happened?'),reply);
 });
