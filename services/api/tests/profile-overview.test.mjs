import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const js=ts.transpileModule(readFileSync(new URL('../lib/profile-overview.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {saturnStatus,profileOverview}=await import(`data:text/javascript;base64,${Buffer.from(js).toString('base64')}`);
const now=Date.parse('2026-09-10T00:00:00Z');
const chart=(moon,saturn)=>({rashi:'Meena',nakshatra:'Uttara Bhadrapada',planets:[{name:'Moon',position:moon}],transits:[{name:'Saturn',position:saturn}],contextCalculatedAt:new Date(now).toISOString()});
test('Saturn phases wrap correctly across Pisces and Aries for each selected profile',()=>{
 assert.equal(saturnStatus(chart(1,12),true,now).state,'rising');
 assert.equal(saturnStatus(chart(12,12),true,now).state,'middle');
 assert.equal(saturnStatus(chart(11,12),true,now).state,'setting');
 assert.equal(saturnStatus(chart(3,12),true,now).state,'inactive');
});
test('unknown birth time, missing and stale transits do not assert Saturn status',()=>{
 assert.equal(saturnStatus(chart(12,12),false,now).state,'unknown');
 assert.equal(saturnStatus({...chart(12,12),transits:[]},true,now).state,'unknown');
 assert.equal(saturnStatus(chart(12,12),true,now+3*3600000).state,'unknown');
 assert.equal(saturnStatus(chart(12,12),true,now-3600000).state,'unknown');
});
test('opening uses only selected facts and avoids provider branding and certainty',()=>{
 const a=profileOverview(chart(12,12),true,'english',now);
 const b=profileOverview({...chart(3,12),rashi:'Mithuna',nakshatra:'Ardra'},true,'english',now);
 assert.match(a,/Meena.*Uttara Bhadrapada/);assert.match(a,/middle phase/);
 assert.match(b,/Mithuna.*Ardra/);assert.doesNotMatch(b,/Meena|Uttara/);
 assert.match(profileOverview(chart(12,12),false,'tamil',now),/தோராயமான/);
 for(const style of ['english','tamil','tanglish']) assert.doesNotMatch(profileOverview(chart(12,12),true,style,now),/prokerala/i);
});
