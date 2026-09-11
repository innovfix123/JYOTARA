import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const helperUrl = url(compile(readFileSync(new URL('../lib/birth-request.ts', import.meta.url), 'utf8')));
const { validBirthDatetime, validChartSession, calculationBirthDatetime, isEligibleBirthDate } = await import(helperUrl);
const invalidDates = [
  '2002-02-29T05:00:00+05:30', '2000-02-30T05:00:00+05:30',
  '2002-04-31T05:00:00+05:30', '2002-13-01T05:00:00+05:30',
  '2002-07-29T24:00:00+05:30', '2002-07-29T05:60:00+05:30',
  '2002-07-29T05:00:60+05:30', '2002-07-29T05:00:00+14:30',
  '2002-07-29T05:00:00+25:00', '2002-07-29T05:00:00',
  'July 29 2002 05:00:00Z', '2002-07-29', '2999-01-01T00:00:00Z',
  null, {}, 1027947600,
];
test('birth datetime rejects calendar normalization and invalid clocks/offsets', () => {
  const now = Date.parse('2026-09-07T00:00:00Z');
  for (const value of invalidDates) assert.equal(validBirthDatetime(value, now), false, String(value));
  for (const value of ['2000-02-29T05:00:00+05:30', '2002-07-29T05:00:00.123+05:30', '2002-07-28T23:30:00Z', '2002-07-29T05:00:00-04:00']) {
    assert.equal(validBirthDatetime(value, now), true, value);
  }
  assert.equal(validBirthDatetime('2026-09-07T00:00:00Z', now), true);
  assert.equal(validBirthDatetime('2026-09-07T00:00:00.001Z', now), false);
  assert.equal(validChartSession('valid-session_01'), true);
  for (const value of ['', 'a'.repeat(129), 'bad%20session', 'bad/session', 'bad session']) assert.equal(validChartSession(value), false);
});

test('actual chart route rejects invalid date/session before metering or provider work', async () => {
  let touched = 0;
  const originalFetch = globalThis.fetch;
  globalThis.__birthRequestEnv = {
    NIRAYANA_CHART_TICKET_KEY: 'test-configured',
    DB: { prepare() { touched++; throw Error('DB must not be reached'); }, batch() { touched++; throw Error('DB must not be reached'); } },
  };
  globalThis.fetch = async () => { touched++; throw Error('Network must not be reached'); };
  const source = readFileSync(new URL('../app/api/astrology/kundli/route.ts', import.meta.url), 'utf8');
  const code = compile(source).replace(/^import .*;$/gm, '');
  const prelude = `import { validBirthDatetime, validChartSession, calculationBirthDatetime, isEligibleBirthDate } from '${helperUrl}';
    const env = globalThis.__birthRequestEnv;
    const chartTicketConfigured = value => Boolean(value);
    const issueChartTicket = () => { throw Error('Unexpected ticket issuance'); };
    const normalizeProviderChart = () => { throw Error('Unexpected normalization'); };
    const currentContext = () => { throw Error('Unexpected context'); };
    const prokeralaJson = () => { throw Error('Unexpected provider'); };
    const prokeralaToken = () => { throw Error('Unexpected token'); };`;
  try {
    const { POST } = await import(url(prelude + code));
    const base = { datetime: '2002-07-29T05:00:00+05:30', latitude: 11.34, longitude: 77.72, birthTimeKnown: true };
    const send = (body, cookie = 'nirayana_pilot_session=valid-session') => POST(new Request('https://example.test/api/astrology/kundli', {
      method: 'POST', headers: { Cookie: cookie, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    }));
    for (const datetime of invalidDates) assert.equal((await send({ ...base, datetime })).status, 400, String(datetime));
    for (const id of ['', 'bad%20session', 'bad/session', 'a'.repeat(129)]) {
      const response = await send(base, `nirayana_pilot_session=${id}`);
      assert.equal(response.status, 400);
      assert.equal(response.headers.get('set-cookie'), null, 'Invalid cookies must not reset usage identity');
    }
    assert.equal(touched, 0);
    assert.equal((await send({...base, datetime:'2020-01-01T05:00:00+05:30'})).status,400);
    assert.equal(touched,0,'Underage profile rejected before metering or provider work');
    globalThis.__birthRequestEnv.NIRAYANA_CHART_TICKET_KEY = '';
    assert.equal((await send(base)).status, 503, 'Valid input reaches the configuration check');
    assert.equal(touched, 0);
  } finally {
    globalThis.fetch = originalFetch;
    delete globalThis.__birthRequestEnv;
  }
});
test('13+ profile cutoff uses India birthday, including midnight and leap-day boundaries', () => {
  const now=Date.parse('2026-09-06T18:30:00Z');
  assert.equal(isEligibleBirthDate('2013-09-07T23:00:00+05:30',now),true);
  assert.equal(isEligibleBirthDate('2013-09-08T00:00:00+05:30',now),false);
  assert.equal(isEligibleBirthDate('1940-01-01T05:00:00+05:30',now),true);
  assert.equal(isEligibleBirthDate('2011-03-01T05:00:00+05:30',Date.parse('2024-02-29T12:00:00+05:30')),false);
});
test('unknown birth time uses noon on the India date, while exact time is unchanged', () => {
  assert.equal(calculationBirthDatetime('2002-07-29T05:00:00+05:30', false), '2002-07-29T12:00:00+05:30');
  assert.equal(calculationBirthDatetime('2002-07-28T23:30:00Z', false), '2002-07-29T12:00:00+05:30');
  assert.equal(calculationBirthDatetime('2002-07-29T05:00:00+05:30', true), '2002-07-29T05:00:00+05:30');
});
