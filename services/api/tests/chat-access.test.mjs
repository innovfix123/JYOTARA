import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../runtime/tester-access.ts', import.meta.url), 'utf8'), {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {admitTesterRequest} = await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
test('chat continues past the old daily allowance but still requires the profile owner', async () => {
  const db = {transaction: fn => fn({query: async sql => {
    assert.ok(sql.startsWith('SELECT tester_key'), 'chat must not reserve a daily question allowance');
    return {rows:[{tester_key:'owner'}]};
  }})};
  for(let i=0;i<45;i++) assert.equal(await admitTesterRequest(db,'owner','/api/guidance','nirayana_pilot_session=profile-one'),200);
  assert.equal(await admitTesterRequest(db,'someone-else','/api/guidance','nirayana_pilot_session=profile-one'),403);
  assert.equal(await admitTesterRequest(db,'owner','/api/guidance',''),400);
});
