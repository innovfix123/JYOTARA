import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import { DatabaseSync } from 'node:sqlite';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, {compilerOptions: {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022}}).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const read = file => readFileSync(new URL(file, import.meta.url), 'utf8');
const evidence = url(compile(read('../lib/astrology-evidence.ts')));
const ticket = url(compile(read('../lib/chart-ticket.ts')).replace('./astrology-evidence', evidence));
const provider = url(compile(read('../lib/provider-chart.ts')).replace('./astrology-evidence', evidence));
const language = url(compile(read('../lib/guidance-language.ts')));
const moduleUrl = file => url(compile(read(file)));
const rules = moduleUrl('../lib/career-rules.ts');
const contract = url(compile(read('../lib/career-answer-contract.ts')).replace('./career-rules', rules));
const career = url(compile(read('../lib/career-response.ts')).replaceAll('./astrology-evidence', evidence).replace('./career-rules', rules).replace('./career-answer-contract', contract));
const recovery = url(compile(read('../db/profile-recovery.ts')).replace('./guidance-requests', moduleUrl('../db/guidance-requests.ts')));
const deletion = url(compile(read('../db/profile-deletion.ts')).replace('./guidance-requests', moduleUrl('../db/guidance-requests.ts')));
const route = file => url(compile(read(file))
  .replace("import { env } from 'cloudflare:workers';", 'const env = globalThis.__chartFlowEnv;')
  .replace('@/lib/chart-ticket', ticket).replace('@/lib/provider-chart', provider)
  .replace('@/lib/astrology-evidence', evidence).replace('@/lib/guidance-language', language)
  .replace('@/lib/birth-request', moduleUrl('../lib/birth-request.ts'))
  .replace('@/db/profile-reservation', moduleUrl('../db/profile-reservation.ts'))
  .replace('@/db/profile-recovery', recovery)
  .replace('@/db/profile-deletion', deletion)
  .replace('@/db/current-context', moduleUrl('../db/current-context.ts'))
  .replace('@/lib/prokerala-client', moduleUrl('../lib/prokerala-client.ts'))
  .replace('@/db/guidance-requests', moduleUrl('../db/guidance-requests.ts'))
  .replace('@/lib/career-response', career));

test('actual calculation-to-guidance routes use provider ticket, never caller chart overrides', async () => {
  const original = globalThis.fetch;
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(read('../drizzle/0004_powerful_juggernaut.sql'));
  sqlite.exec(read('../drizzle/0009_salty_skrulls.sql'));
  sqlite.exec(read('../drizzle/0010_green_johnny_blaze.sql'));
  let calls = 0;
  let navamsaCalls = 0;
  let rejectNavamsa = false;
  const d9 = { status: 'ok', data: { divisional_positions: ['Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', 'Tula', 'Vrischika', 'Dhanu', 'Makara', 'Kumbha', 'Meena'].map((name, id) => ({
    rasi: {name, id}, planet_positions: id < 9 ? [{planet:{id:id < 7 ? id : id + 94, name:['Sun','Moon','Mercury','Venus','Mars','Jupiter','Saturn','Rahu','Ketu'][id]}, rasi:{name,id}, sign_degree:12.5}] : [],
  })) } };
  globalThis.__chartFlowEnv = {
    PROKERALA_ENVIRONMENT: 'production', PROKERALA_CLIENT_ID: 'TEST', PROKERALA_CLIENT_SECRET: 'TEST',
    DB: { async batch() {}, prepare(sql) {
      let args=[];
      return {bind(...values) {args=values;return this;},
        async first() {return sql.includes('profile_generations') ? sqlite.prepare(sql).get(...args) ?? null : null;},
        async run() {return {meta:{changes:sql.includes('profile_generations') ? Number(sqlite.prepare(sql).run(...args).changes) : 1}};}};
    }},
  };
  globalThis.fetch = async input => {
    calls++;
    const address = String(input);
    if (address.endsWith('/token')) return Response.json({access_token: 'TEST', expires_in: 3600});
    if (address.includes('/astrology/kundli')) {
      assert.ok(['2002-07-29T12:00:00+05:30','2002-07-29T05:00:00+05:30'].includes(new URL(address).searchParams.get('datetime')));
      return Response.json({data: {nakshatra_details: {
      chandra_rasi: {name: 'Meena'}, nakshatra: {name: 'Uttara Bhadrapada', pada: 1}}, yoga_details: []}});
    }
    if (address.includes('/planet-position')) return Response.json({data: {planet_position: []}});
    if (address.includes('/divisional-planet-position')) {
      navamsaCalls++;
      const u = new URL(address);
      assert.equal(u.searchParams.get('chart_type'), 'navamsa');
      assert.equal(u.searchParams.get('la'), 'en');
      assert.equal(u.searchParams.get('datetime'), '2002-07-29T05:00:00+05:30');
      return rejectNavamsa ? new Response('', {status:503}) : Response.json(d9);
    }
    if (address.includes('/dasha-periods')) return Response.json({data: {dasha_periods: []}});
    if (address.includes('/panchang')) return Response.json({data: {}});
    throw new Error('Unexpected external call');
  };
  try {
    const {POST: calculate} = await import(route('../app/api/astrology/kundli/route.ts'));
    const {POST: guide} = await import(route('../app/api/guidance/route.ts'));
    const birth = {datetime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, birthTimeKnown: false};
    const req = (body, cookie='') => new Request('https://example.test/', {method:'POST', headers:{'Content-Type':'application/json', cookie}, body:JSON.stringify(body)});
    assert.equal((await calculate(req(birth))).status, 503);
    assert.equal(calls, 0, 'configuration failure must not spend provider credits');
    globalThis.__chartFlowEnv.NIRAYANA_CHART_TICKET_KEY = 'ab'.repeat(32);
    const result = await calculate(req(birth));
    assert.equal(result.status, 200);
    const payload = await result.json();
    assert.ok(payload.chartTicket && payload.profileId);
    assert.equal(navamsaCalls, 0);
    assert.equal(payload.moduleStatus.navamsa, 'not-requested-unknown-time');
    assert.equal(result.headers.get('Cache-Control'), 'no-store');
    const cookie = result.headers.get('Set-Cookie').split(';')[0];
    const afterChartCalls = calls;
    const recovered = await calculate(req(birth,cookie));
    assert.equal(recovered.status,200);
    assert.deepEqual(await recovered.json(),{...payload,profileRecovered:true});
    assert.equal(calls,afterChartCalls,'Recovery must not call any provider');
    const sameUnknownDay = await calculate(req({...birth,datetime:'2002-07-29T18:00:00+05:30'},cookie));
    assert.equal(sameUnknownDay.status,200);
    assert.equal(calls,afterChartCalls,'Unused unknown-time clock must not create a different paid request');
    assert.equal((await calculate(req({...birth,latitude:12},cookie))).status,429);
    assert.equal(calls,afterChartCalls,'Changed birth details must not receive the old chart or silently recalculate');
    const stored=sqlite.prepare('SELECT response_ciphertext FROM profile_generations').get();
    assert.ok(stored.response_ciphertext);
    assert.ok(!stored.response_ciphertext.includes('Meena'));
    const body = {category:'Career', question:'What should I focus on?', language:'en',
      profileId:payload.profileId, chartTicket:payload.chartTicket, birthTimeKnown:true,
      chart:{rashi:'Mesha', planets:[], yogas:[], lagna:'Simha'}};
    const response = await guide(req(body,cookie));
    assert.equal(response.status,200);
    const answer = await response.json();
    assert.equal(answer.profileId,payload.profileId);
    assert.ok(answer.evidence.some(x=>x.includes('Meena')));
    assert.ok(!answer.evidence.some(x=>x.includes('Mesha')||x.includes('Simha')));
    const count = calls;
    assert.equal((await guide(req({...body,profileId:'other'},cookie))).status,401);
    assert.equal((await guide(req(body,'nirayana_pilot_session=other'))).status,401);
    assert.equal((await guide(req({...body,chartTicket:undefined},cookie))).status,401);
    assert.equal(calls,count);
    sqlite.prepare('UPDATE profile_generations SET response_ciphertext=?').run('corrupt');
    assert.equal((await calculate(req(birth,cookie))).status,429);
    assert.equal(calls,count,'Corrupt recovery must never trigger another paid calculation');
    sqlite.prepare('UPDATE profile_generations SET response_ciphertext=?, response_expires_at=?').run(stored.response_ciphertext,Date.now()-1);
    assert.equal((await calculate(req(birth,cookie))).status,429);
    assert.equal(calls,count);
    assert.equal(sqlite.prepare('SELECT response_ciphertext FROM profile_generations').get().response_ciphertext,null);
    const exactResult = await calculate(req({...birth,birthTimeKnown:true}));
    assert.equal(exactResult.status,200);
    const exact = await exactResult.json();
    assert.equal(exact.moduleStatus.navamsa,'connected');
    assert.equal(navamsaCalls,1);
    const exactCookie = exactResult.headers.get('Set-Cookie').split(';')[0];
    const {openChartTicket} = await import(ticket);
    const protectedChart = await openChartTicket(globalThis.__chartFlowEnv.NIRAYANA_CHART_TICKET_KEY, exact.chartTicket, exactCookie.split('=')[1], exact.profileId);
    assert.equal(protectedChart.chart.navamsa.length,9);
    assert.equal((await calculate(req({...birth,birthTimeKnown:true},exactCookie))).status,200);
    assert.equal(navamsaCalls,1,'Recovered chart must not repurchase Navamsa');
    rejectNavamsa = true;
    const partial = await calculate(req({...birth,birthTimeKnown:true}));
    assert.equal(partial.status,200);
    const partialChart = await partial.json();
    assert.equal(partialChart.moduleStatus.navamsa,'unavailable');
    assert.equal(partialChart.navamsa,null);
    assert.ok(partialChart.chartTicket,'D9 failure must not destroy natal access');
    assert.equal(navamsaCalls,2,'Failed D9 request must not retry');
  } finally { globalThis.fetch=original; delete globalThis.__chartFlowEnv; sqlite.close(); }
});
