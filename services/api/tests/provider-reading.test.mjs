import {readFileSync} from 'node:fs';
import ts from 'typescript';
import test from 'node:test';
import assert from 'node:assert/strict';
const js=ts.transpileModule(readFileSync(new URL('../lib/guidance-language.ts',import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.ES2022,target:ts.ScriptTarget.ES2022}}).outputText;
const {providerReadingSources}=await import('data:text/javascript;base64,'+Buffer.from(js).toString('base64'));
test('provider retrieval selects relevant returned descriptions without inventing interpretation',()=>{
 const chart={yogas:[{name:'Career fixture',description:'Recognition at work.'},{name:'Love fixture',description:'Affection in relationships.'}]};
 assert.deepEqual(providerReadingSources(chart,'Career'),[{id:'prokerala-1',name:'Career fixture',interpretation:'Recognition at work.'}]);
 assert.equal(providerReadingSources(chart,'Love')[0].name,'Love fixture');
 assert.deepEqual(providerReadingSources(chart,'Education'),[]);
 assert.deepEqual(providerReadingSources({yogas:[{name:'Raja Yoga',description:'A relationship between planets gives recognition.'}]},'Love'),[]);
 assert.deepEqual(providerReadingSources({yogas:[{name:'Yoga',description:'Planets occupy the second house.'}]},'Property'),[]);
 assert.deepEqual(providerReadingSources({yogas:[]},'Career'),[]);
 assert.deepEqual(providerReadingSources(chart,'Breakup'),[]);
 assert.equal(providerReadingSources({yogas:[],mangalDosha:{hasDosha:false,description:'No Mangal Dosha.'}},'Marriage')[0].interpretation,'No Mangal Dosha.');
});
