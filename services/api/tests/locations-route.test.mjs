import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {POST}=await import(moduleFor('../app/api/locations/route.ts'));
test('birthplace index searches towns, districts and Tamil aliases without network',async()=>{
 const old=globalThis.fetch;globalThis.fetch=()=>{throw Error('Network forbidden');};
 const send=query=>POST(new Request('https://test',{method:'POST',body:JSON.stringify({query})}));
 try{
  for(const q of ['ab','a'.repeat(81),'Ero\u0000de',123])assert.equal((await send(q)).status,400);
  for(const q of ['Erode','Pollachi','Chennai','Kochi','Madurai','Coimbatore']){
   const res=await send(q);assert.equal(res.status,200);const {data,attribution}=await res.json();
   assert.ok(data.length>0&&data.length<=20,q);assert.match(attribution,/GeoNames/);
   for(const row of data){assert.equal(row[4],'IN');assert.equal(row[5],'Asia/Kolkata');assert.ok(Number.isFinite(row[6])&&Number.isFinite(row[7]));}
  }
  assert.deepEqual((await (await send('zzzzunmatchedplacezz')).json()).data,[]);
 }finally{globalThis.fetch=old;}
});
