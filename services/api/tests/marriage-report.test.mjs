import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const source = path => readFileSync(new URL(path, import.meta.url), 'utf8');
const moduleUrl = path => url(compile(source(path)));
const evidence = moduleUrl('../lib/astrology-evidence.ts');
const tickets = url(compile(source('../lib/chart-ticket.ts')).replace('./astrology-evidence', evidence));
const receipts = moduleUrl('../db/guidance-requests.ts');
const deletion = url(compile(source('../db/profile-deletion.ts')).replace('./guidance-requests', receipts));
const rules = moduleUrl('../lib/career-rules.ts');
const contract = url(compile(source('../lib/career-answer-contract.ts')).replace('./career-rules', rules));
const career = url(compile(source('../lib/career-response.ts')).replaceAll('./astrology-evidence', evidence).replace('./career-rules', rules).replace('./career-answer-contract', contract));
const { issueChartTicket, openChartTicket } = await import(tickets);
const { sealReply, openReply } = await import(receipts);
const route = url(compile(source('../app/api/guidance/route.ts'))
  .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__receiptTestEnv;')
  .replace('@/lib/chart-ticket', tickets)
  .replace('@/db/guidance-requests', receipts)
  .replace('@/db/profile-deletion', deletion)
  .replace('@/lib/career-response', career)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/marriage-report', moduleUrl('../lib/marriage-report.ts'))
  .replaceAll('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(source('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence)))
  .replace('@/lib/astrology-evidence', evidence)
  .replace('@/lib/guidance-language', moduleUrl('../lib/guidance-language.ts')));

const {parseMarriageReport,marriageTimingQuestion,marriageReportReply}=await import(moduleUrl('../lib/marriage-report.ts'));
const text='Synthetic cover\fFavourable Marriage Periods\nDasha Lord Sub Dasha Lord Start End\nMercury Venus 2020-01-01 2027-01-01\nMercury Moon 2028-01-01 2030-01-01\fDisclaimer';
test('report parser cites the actual page and distinguishes timing follow-ups from new topics',()=>{
 const report=parseMarriageReport(text,'a'.repeat(64));
 assert.equal(report.page,2);
 assert.equal(marriageTimingQuestion('When will I get a job?',['When will I marry?'],'Marriage'),false);
 assert.equal(marriageTimingQuestion('What about after that?',['When will I marry?'],'Love'),true);
 assert.equal(marriageTimingQuestion('Hello',[],'Marriage'),false);
 assert.throws(()=>parseMarriageReport(text.replace('2027-01-01','2027-02-30'),'a'.repeat(64)));
 assert.equal(marriageReportReply(report,'english','What about next?',new Date('2026-09-09'),['When will I marry?']).window.start,'2028-01-01');
 for(const style of ['english','tamil','tanglish'])assert.ok(marriageReportReply(report,style,'When?',new Date('2026-09-09')).answer.length<600);
});
test('typed marriage question buys once, records actual usage, cites report and reuses it for follow-ups',async()=>{
 const db=new DatabaseSync(':memory:');
 for(const name of ['0000_perpetual_giant_man','0001_chilly_purple_man','0002_broad_spacker_dave','0003_reflective_betty_ross','0004_powerful_juggernaut','0007_cold_inhumans','0009_salty_skrulls','0010_green_johnny_blaze','0011_report_evidence'])db.exec(source(`../drizzle/${name}.sql`));
 const adapter={prepare(sql){let args=[];return {bind(...v){args=v;return this;},async run(){return {meta:{changes:Number(db.prepare(sql).run(...args).changes)}};},async first(){return db.prepare(sql).get(...args)??null;}};},async batch(statements){db.exec('BEGIN');try{const rows=[];for(const s of statements)rows.push(await s.run());db.exec('COMMIT');return rows;}catch(e){db.exec('ROLLBACK');throw e;}}};
 const secret='c5'.repeat(32), originalFetch=globalThis.fetch;let calls=0;
 globalThis.__receiptTestEnv={NIRAYANA_CHART_TICKET_KEY:secret,PROKERALA_ENVIRONMENT:'production',JYOTARA_QUESTION_LIMIT:'15',PROKERALA_CLIENT_ID:'report-test',PROKERALA_CLIENT_SECRET:'synthetic',DB:adapter,JYOTARA_EXTRACT_PDF:async()=>text};
 globalThis.fetch=async address=>{const u=new URL(address);if(u.pathname==='/token')return Response.json({access_token:'synthetic',expires_in:3600});assert.equal(u.pathname,'/v2/report/personal-reading/instant');assert.equal(u.searchParams.get('options[modules][0][options][period_type]'),'marriage');calls++;return new Response('%PDF-synthetic',{headers:{'content-type':'application/pdf','x-api-credits':'6000'}});};
 try{
 const {POST,DELETE}=await import(`${route}#marriage`);
 const person={datetime:'2000-01-01T05:00:00+05:30',latitude:10,longitude:76,name:'Synthetic',gender:'male',place:'Test city'};
 const chartTicket=await issueChartTicket(secret,{sessionId:'report-owner',profileId:'report-profile',birthTimeKnown:true,birthDatetime:person.datetime,contextLocation:{latitude:10,longitude:76},chart:{rashi:'Meena',nakshatra:'Revati',planets:[],yogas:[]}});
 const base={requestId:'report-question-0001',category:'Marriage',question:'When will I get married?',responseStyle:'english',language:'en',profileId:'report-profile',chartTicket,reportPerson:person};
 const request=(body,method='POST')=>new Request('https://example.test/api/guidance',{method,headers:{Cookie:'nirayana_pilot_session=report-owner','Content-Type':'application/json'},body:JSON.stringify(body)});
 const first=await(await POST(request(base))).json();assert.equal(first.answerMode,'provider_reading');assert.equal(first.reportEvidence.page,2);assert.equal(first.providerUsage.calls[0].actualCredits,6000);assert.equal(calls,1);
 const replay=await(await POST(request(base))).json();assert.equal(replay.replayed,true);assert.equal(calls,1);
 const next=await(await POST(request({...base,requestId:'report-question-0002',question:'What about after that?',previousUserMessages:[base.question]}))).json();assert.equal(next.reportStatus,'cached');assert.equal(next.reportEvidence.window.start,'2028-01-01');assert.equal(next.providerUsage.newProviderCalls,0);assert.equal(calls,1);
 assert.equal(db.prepare('SELECT SUM(actual_credits) n FROM provider_usage').get().n,6000);
 assert.ok(!db.prepare('SELECT response_ciphertext FROM provider_reports').get().response_ciphertext.includes('Mercury'));
 const mismatch=await(await POST(request({...base,requestId:'report-question-0003',reportPerson:{...person,latitude:11}}))).json();assert.equal(mismatch.reportStatus,'profile_details_mismatch');assert.equal(calls,1);
 const unknown=await issueChartTicket(secret,{sessionId:'report-owner',profileId:'unknown',birthTimeKnown:false,chart:{rashi:'Meena',nakshatra:'Revati',planets:[],yogas:[]}});
 const noTime=await(await POST(request({...base,requestId:'report-question-0004',profileId:'unknown',chartTicket:unknown}))).json();assert.equal(noTime.reportStatus,'birth_time_unknown');assert.equal(calls,1);
 const {deleteChartSession}=await import(deletion);await deleteChartSession(adapter,'report-owner');assert.equal(db.prepare('SELECT COUNT(*) n FROM provider_reports').get().n,0);
 }finally{globalThis.fetch=originalFetch;delete globalThis.__receiptTestEnv;db.close();}
});
