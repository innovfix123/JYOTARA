import { test } from 'node:test';
import assert from 'node:assert/strict';
import { plainDailySections } from './daily-copy.mjs';
const source = [{title:'General',text:'Source.',details:'A gentle pace may help you today.'}];
const response = value => async () => Response.json({output_text:JSON.stringify(value)});
test('source-based short reading retains topic and creates short points', async () => {
 const value = await plainDailySections(source, {key:'test', request:response([{title:'General',summary:'You may find a slower pace helpful today.',points:['Give yourself time to settle.','A gentle pace may help.']}])});
 assert.equal(value[0].presentation,'plain-language'); assert.match(value[0].details,/gentle pace/);
});
test('errors, wrong topics and invented numbers preserve original readings', async () => {
 for(const request of [async()=>{throw Error('offline');},response([{title:'Other',summary:'Stay calm.',points:['Take time.','Be patient.']}]),response([{title:'General',summary:'You will win 100 coins.',points:['Take time.','Be patient.']}])]) assert.deepEqual(await plainDailySections(source,{key:'test',request}),source);
});
