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
  .replace('@/lib/divine-calculations', moduleUrl('../lib/divine-calculations.ts'))
  .replace('@/lib/divine-consultation', moduleUrl('../lib/divine-consultation.ts'))
  .replace('@/lib/marriage-report', moduleUrl('../lib/marriage-report.ts'))
  .replaceAll('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/lib/provider-chart', url(compile(source('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence)))
  .replace('@/lib/profile-overview', url(compile(source('../lib/profile-overview.ts')))).replace('@/lib/astrology-evidence', evidence)
  .replace('@/lib/guidance-language', moduleUrl('../lib/guidance-language.ts')).replace('@/lib/consultation-writer', moduleUrl('../lib/consultation-writer.ts')));

const {parseMarriageReport,marriageTimingQuestion,marriageReportReply}=await import(moduleUrl('../lib/marriage-report.ts'));
const text='Synthetic cover\fFavourable Marriage Periods\nDasha Lord Sub Dasha Lord Start End\nMercury Venus 2020-01-01 2027-01-01\nMercury Moon 2028-01-01 2030-01-01\fDisclaimer';
test('report parser cites the actual page and distinguishes timing follow-ups from new topics',()=>{
 const report=parseMarriageReport(text,'a'.repeat(64));
 assert.equal(report.page,2);
 assert.equal(marriageReportReply(report,'english','In 2029?',new Date('2026-09-09')).window.start,'2028-01-01');
 assert.equal(marriageReportReply(report,'english','In 2035?',new Date('2026-09-09')),null);
 assert.equal(marriageTimingQuestion('When will I get a job?',['When will I marry?'],'Marriage'),false);
 assert.equal(marriageTimingQuestion('What about after that?',['When will I marry?'],'Love'),true);
 assert.equal(marriageTimingQuestion('Hello',[],'Marriage'),false);
 assert.equal(marriageTimingQuestion('In 2029?',['When will I marry?'],'Love'),true);
 assert.throws(()=>parseMarriageReport(text.replace('2027-01-01','2027-02-30'),'a'.repeat(64)));
 assert.equal(marriageReportReply(report,'english','What about next?',new Date('2026-09-09'),['When will I marry?']).window.start,'2028-01-01');
 for(const style of ['english','tamil','tanglish'])assert.ok(marriageReportReply(report,style,'When?',new Date('2026-09-09')).answer.length<600);
});
// Paid PDF routing retired: new marriage conversations are covered by guidance-idempotency's Divine flow.
