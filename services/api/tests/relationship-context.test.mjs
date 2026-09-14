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


function environment(){
 const db=new DatabaseSync(':memory:');
 for(const name of ['0000_perpetual_giant_man','0001_chilly_purple_man','0002_broad_spacker_dave','0003_reflective_betty_ross','0004_powerful_juggernaut','0007_cold_inhumans','0009_salty_skrulls','0010_green_johnny_blaze','0011_report_evidence'])db.exec(source(`../drizzle/${name}.sql`));
 globalThis.__receiptTestEnv={NIRAYANA_CHART_TICKET_KEY:'a3'.repeat(32),OPENROUTER_API_KEY:'TEST-ONLY',DB:{
 async batch(statements){const result=[];for(const s of statements)result.push(await s.run());return result;},
 prepare(sql){let args=[];return {bind(...v){args=v;return this;},async run(){const r=db.prepare(sql).run(...args);return {meta:{changes:Number(r.changes)}};},async first(){return db.prepare(sql).get(...args)??null;}};}}};
 return db;
}
test('a narrow denial phrase does not hide an actual guarantee elsewhere',async()=>{
 const {acceptableAnswer}=await import(moduleUrl('../lib/guidance-language.ts'));
 assert.equal(acceptableAnswer('Proceed without expecting fixed dates or guaranteed results.', 'english'),true);
 assert.equal(acceptableAnswer('Proceed without expecting fixed dates or guaranteed results. You will definitely marry.', 'english'),false);
 assert.equal(acceptableAnswer('Your marriage is guaranteed.', 'english'),false);
 assert.equal(acceptableAnswer('A good outcome cannot be guaranteed. Prepare one clear point.', 'english'),true);
 assert.equal(acceptableAnswer('A good outcome cannot be guaranteed. You will definitely marry.', 'english'),false);
});

test('language validation rejects foreign-script contamination',async()=>{
 const {acceptableAnswer}=await import(moduleUrl('../lib/guidance-language.ts'));
 assert.equal(acceptableAnswer('எனக்கு поддержки வேண்டும் என்று சொல்லுங்கள்.', 'tamil'),false);
 assert.equal(acceptableAnswer('ஒரு நேர்மையான句ை சொல்லலாம்.', 'tamil'),false);
 assert.equal(acceptableAnswer('Enakku உதவி venum.', 'tanglish'),false);
 assert.equal(acceptableAnswer('எனக்கு உங்கள் உதவி வேண்டும் என்று சொல்லுங்கள்.', 'tamil'),true);
 assert.equal(acceptableAnswer('Enakku unga udhavi venum nu sollunga.', 'tanglish'),true);
});

test('Panchang certainty questions receive a direct limit and useful next step in each style',async()=>{
 const {relationshipResponse}=await import(moduleUrl('../lib/guidance-language.ts'));
 for(const [style,q] of [['english','Can Panchang guarantee success?'],['tamil','இன்றைய பஞ்சாங்கம் என் வேலை வெற்றியை உறுதிசெய்யுமா?'],['tanglish','Panchangam vetriyai urudhi seiyuma?']]) {
   const reply=relationshipResponse('Daily',q,[],style);
   assert.equal(reply.kind,'panchang_limits');
   assert.ok(reply.answer.length>120);
 }
 assert.equal(relationshipResponse('Panchang','What is the tithi?',[],'english'),null);
});

test('ordinary conflict or a negated argument does not imply long distance',async()=>{
 const {relationshipResponse}=await import(moduleUrl('../lib/guidance-language.ts'));
 for(const q of ['Naan mattum plans podren. Sandai illaama eppadi sollalaam?','எங்கள் குடும்பங்களின் பழக்கங்கள் வேறுபடுகின்றன. சண்டையை எப்படிக் குறைக்கலாம்?']) {
   assert.equal(relationshipResponse('Marriage',q,[],'tamil'),null);
 }
 assert.equal(relationshipResponse('Relationships','We are in a long distance relationship.',[],'english').kind,'communication');
});


test('quoted question inside a sentence does not cut off its answer', async () => {
 const {conciseReply}=await import(moduleUrl('../lib/guidance-language.ts'));
 const reply='You have an interview next week. Focus less on “will I get it?” and practise explaining your accounting project.';
 assert.equal(conciseReply(reply),reply);
});

test('relationship coaching covers distinct concerns in the requested language only', async () => {
 const {relationshipCoaching}=await import(moduleUrl('../lib/guidance-language.ts'));
 for (const style of ['english','tamil','tanglish']) {
  const examples=relationshipCoaching(style,'Love');
  assert.equal(examples.length,9);
  assert.match(examples[0],/fictional teaching examples, NOT evidence/);
  assert.match(examples.join('\n'),/one-sided effort|money pressure|broken promises/);
  assert.match(examples[0],/never copy.*mechanically/);
  if(style==='tamil') assert.match(examples[1],/சந்தேகம்/);
  else assert.doesNotMatch(examples.join('\n'),/[\u0B80-\u0BFF]/u);
 }
 assert.deepEqual(relationshipCoaching('english','Career'),[]);
});

test('ordinary uncertainty starts with relevant help, not a stock inability message', async () => {
 const {relationshipResponse}=await import(moduleUrl('../lib/guidance-language.ts'));
 for(const style of ['english','tamil','tanglish']) {
  const result=relationshipResponse('Love','They give mixed signals',[],style);
  assert.equal(result.kind,'feelings');
  assert.doesNotMatch(result.answer,/cannot|முடியா|mudiyaadhu/i);
 }
});
