import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../app/api/locations/route.ts', import.meta.url), 'utf8'), {
  compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 },
}).outputText;
const { POST } = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
test('location route validates input, filters data and rejects redirects/errors', async () => {
  const original = globalThis.fetch;
  let calls = 0;
  const valid = [1272013, 'Erode', 'Tamil Nadu', 'India', 'IN', 'Asia/Kolkata', 11.3428, 77.7274];
  let response = () => Response.json({ data: [valid, [...valid.slice(0, 6), 999, 77], [1, 'Other', 'State', 'China', 'CN', 'Asia/Shanghai', 20, 90], null] });
  globalThis.fetch = async (url, options) => {
    calls++;
    assert.equal(url.origin, 'https://client-api.prokerala.com');
    assert.equal(url.pathname, '/v1/location/search.json');
    assert.equal(url.searchParams.get('limit'), '20');
    assert.equal(options.redirect, 'manual');
    return response();
  };
  const send = body => POST(new Request('http://localhost/api/locations', { method: 'POST', body: JSON.stringify(body) }));
  try {
    for (const body of [null, {}, {query: 'ab'}, {query: 'a'.repeat(81)}, {query: 'Ero\u0000de'}, {query: 123}]) {
      assert.equal((await send(body)).status, 400);
    }
    assert.equal(calls, 0);
    const result = await send({query: 'Erode', url: 'http://untrusted.test'});
    assert.equal(result.status, 200);
    assert.deepEqual((await result.json()).data, [valid]);
    assert.equal(result.headers.get('cache-control'), 'no-store');
    response = () => Response.json({ data: Array(30).fill(valid) });
    assert.equal((await (await send({query:'Erode'})).json()).data.length, 20);
    for (const failed of [() => new Response('', {status:302, headers:{location:'http://untrusted.test'}}), () => Response.json({bad:true}), () => {throw new TypeError('network');}]) {
      response = failed;
      const result = await send({query:'Erode'});
      assert.equal(result.status, 502);
      assert.equal('data' in await result.json(), false);
    }
  } finally { globalThis.fetch = original; }
});
