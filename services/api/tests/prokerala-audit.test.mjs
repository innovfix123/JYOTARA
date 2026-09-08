import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';

const source = readFileSync(new URL('../lib/prokerala-audit.ts', import.meta.url), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
const { runAudit, sha256 } = await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const token = 'a'.repeat(64);
const body = { datetime: '2000-01-01T12:00:00+05:30', latitude: 10, longitude: 78 };
const config = { id: 'test', tokenHash: await sha256(token), profileHash: await sha256(JSON.stringify(Object.values(body))), expiresAt: 10000 };
const request = (value = body, credential = token) => new Request('https://example.test/api/internal/prokerala-audit', { method: 'POST', headers: { authorization: `Bearer ${credential}` }, body: JSON.stringify(value) });
function fixture() {
  const calls = [];
  let claimed = false;
  const deps = {
    now: () => 1000, production: true, clientId: 'test-id', clientSecret: 'test-secret',
    claim: async () => { if (claimed) return false; claimed = true; return true; },
    finish: async () => {},
    fetch: async (url, options) => {
      calls.push({ url: String(url), options });
      return Response.json(String(url).endsWith('/token') ? { access_token: 'test-access' } : { status: 'ok', data: { sample: true } });
    },
  };
  return { deps, calls };
}
test('unauthorised request makes no provider call', async () => {
  const { deps, calls } = fixture();
  assert.equal((await runAudit(request(body, 'b'.repeat(64)), deps, config)).status, 404);
  assert.equal(calls.length, 0);
});
test('expired, non-production and different-profile requests do not spend', async () => {
  const { deps, calls } = fixture();
  assert.equal((await runAudit(request(), deps, { ...config, expiresAt: 1 })).status, 410);
  assert.equal((await runAudit(request(), { ...deps, production: false }, config)).status, 503);
  assert.equal((await runAudit(request({ ...body, latitude: 11 }), deps, config)).status, 400);
  assert.equal(calls.length, 0);
});
test('only two fixed Tamil calculations; no retries or secret in response', async () => {
  const { deps, calls } = fixture();
  const res = await runAudit(request(), deps, config);
  assert.equal(res.status, 200);
  assert.match(res.headers.get('cache-control'), /no-store/);
  const text = await res.text();
  assert.ok(!text.includes('test-secret') && !text.includes('test-access'));
  assert.equal(calls.length, 3);
  assert.deepEqual(calls.slice(1).map(c => new URL(c.url).pathname), ['/v2/astrology/kundli/advanced', '/v2/astrology/yoga']);
  assert.ok(calls.slice(1).every(c => new URL(c.url).searchParams.get('la') === 'ta'));
  assert.equal((await runAudit(request(), deps, config)).status, 409);
  assert.equal(calls.length, 3);
});
test('concurrent requests share single-use guard', async () => {
  const { deps, calls } = fixture();
  const responses = await Promise.all([runAudit(request(), deps, config), runAudit(request(), deps, config)]);
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 409]);
  assert.equal(calls.length, 3);
});
test('provider authentication failure performs no calculations or retries', async () => {
  const { deps, calls } = fixture();
  deps.fetch = async (url) => { calls.push({url}); return new Response('', {status:401}); };
  assert.equal((await runAudit(request(), deps, config)).status, 502);
  assert.equal((await runAudit(request(), deps, config)).status, 409);
  assert.equal(calls.length, 1);
});
