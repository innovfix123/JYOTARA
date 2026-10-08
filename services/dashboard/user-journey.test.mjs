import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {journeyDashboard} from './user-journey.mjs';
const request=(path)=>new Request('https://example.test'+path);
const owner={role:'owner'}, viewer={role:'viewer'};
test('activity access requires owner, not a regular dashboard team login',async()=>{
 const db={query(){throw Error('Database must not be accessed');}};
 assert.equal((await journeyDashboard(request('/api/journey/users'),db,null)).status,401);
 assert.equal((await journeyDashboard(request('/api/journey/users'),db,viewer)).status,403);
});
test('user list displays opaque account and existing last four only',async()=>{
 const calls=[];const db={query:async(sql,args)=>{calls.push({sql,args});return {rows:[{account:'opaque',lastFour:'0000',events:5,sessions:1,lastSeen:100,failures:0}]};}};
 const response=await journeyDashboard(request('/api/journey/users?days=1'),db,owner,86400001);
 assert.equal(response.status,200);assert.equal((await response.json()).users[0].lastFour,'0000');
 assert.deepEqual(calls[0].args,[1]);assert(!calls[0].sql.includes('phone_hash'));assert.match(calls[0].sql,/LIMIT 100/);
});
test('timeline binds identity, orders by server sequence and pages without timestamp ties',async()=>{
 const calls=[];const db={query:async(sql,args)=>{calls.push({sql,args});return {rows:[{id:'a'.repeat(32),session:'b'.repeat(32),sequence:1,serverSequence:2,name:'chat.answer',screen:'chat',deviceAt:90,serverAt:100,metadata:'{"outcome":"success"}'}]};}};
 const response=await journeyDashboard(request('/api/journey/timeline?account=opaque&days=7&before=3'),db,owner,7*86400000);
 assert.equal(response.status,200);const body=await response.json();assert.deepEqual(body.next,{before:2});assert.deepEqual(body.events[0].metadata,{outcome:'success'});
 assert.deepEqual(calls[0].args,['opaque',0,3]);assert.match(calls[0].sql,/ORDER BY server_sequence DESC LIMIT 200/);
});
test('invalid account, time range or cursor never reaches database',async()=>{
 const db={query(){throw Error('Database must not be accessed');}};
 for(const path of ['/api/journey/users?days=1000','/api/journey/timeline?account=a%27b','/api/journey/timeline?account=opaque&before=-1','/api/journey/timeline?account=opaque&before=no'])assert.equal((await journeyDashboard(request(path),db,owner)).status,400);
});
test('timeline renders values as text rather than injected HTML',()=>{
 const html=readFileSync(new URL('./user-journey.html',import.meta.url),'utf8');
 assert(!html.includes('innerHTML'));assert.match(html,/textContent/);assert.match(html,/Account ID or last 4 digits/);
});
