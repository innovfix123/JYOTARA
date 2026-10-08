import {readFileSync} from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../runtime/json-object.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {jsonObject}=await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
test('request bodies reject malformed JSON, null, arrays and scalar values',async()=>{
 for(const body of ['{','null','[]','"confirm"','true','42'])
  assert.equal(await jsonObject(new Request('https://example.test',{method:'POST',body})),null);
 assert.deepEqual(await jsonObject(new Request('https://example.test',{method:'POST',body:'{"confirm":true}'})),{confirm:true});
});
