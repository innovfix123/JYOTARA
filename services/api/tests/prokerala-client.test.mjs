import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import ts from 'typescript';
const code=ts.transpileModule(readFileSync(new URL('../lib/prokerala-client.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {prokeralaJson}=await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);
const input={datetime:'2002-07-29T05:00:00+05:30',latitude:11.34,longitude:77.72,language:'ta'};
const credentials=id=>({PROKERALA_CLIENT_ID:id,PROKERALA_CLIENT_SECRET:'SYNTHETIC-SECRET'});
test('provider requests share token, carry bounded signals and never follow redirects',async()=>{
  const original=globalThis.fetch; const calls=[];
  globalThis.fetch=async(address,options)=>{
    calls.push({address:String(address),options});
    assert.equal(options.redirect,'manual');
    assert.ok(options.signal instanceof AbortSignal);
    if(String(address).endsWith('/token'))return Response.json({access_token:'SYNTHETIC',expires_in:3600});
    const url=new URL(address);
    assert.equal(url.searchParams.get('coordinates'),'11.34,77.72');
    assert.equal(url.searchParams.get('datetime'),input.datetime);
    assert.equal(url.searchParams.get('la'),'ta');
    return Response.json({data:{}});
  };
  try{
    await Promise.all(['/astrology/kundli','/astrology/planet-position'].map(path=>prokeralaJson(credentials('coalesce'),path,input)));
    assert.equal(calls.filter(c=>c.address.endsWith('/token')).length,1);
    assert.equal(calls.length,3);
  }finally{globalThis.fetch=original;}
});
test('bad provider responses and redirects fail without retry',async()=>{
  const original=globalThis.fetch;let calls=0;let result;
  globalThis.fetch=async address=>{
    if(String(address).endsWith('/token'))return Response.json({access_token:'SYNTHETIC',expires_in:3600});
    calls++;return result();
  };
  try{
    const cases=[()=>new Response('',{status:302,headers:{Location:'https://elsewhere.invalid'}}),()=>new Response('',{status:503}),()=>new Response('bad json'),()=>Response.json(null),()=>Response.json({status:'error',data:{}}),()=>Response.json({data:null})];
    for(const [index,response] of cases.entries()){
      result=response;
      await assert.rejects(prokeralaJson(credentials('errors'),'/astrology/kundli',input));
      assert.equal(calls,index+1);
    }
  }finally{globalThis.fetch=original;}
});
test('aborted module settles once without automatic resubmission',async()=>{
  const original=globalThis.fetch;const timeout=AbortSignal.timeout;let calls=0;const durations=[];
  AbortSignal.timeout=ms=>{durations.push(ms);const controller=new AbortController();setTimeout(()=>controller.abort(new DOMException('Synthetic timeout','TimeoutError')),1);return controller.signal;};
  globalThis.fetch=async(address,options)=>{
    if(String(address).endsWith('/token'))return Response.json({access_token:'SYNTHETIC',expires_in:3600});
    calls++;return new Promise((resolve,reject)=>options.signal.addEventListener('abort',()=>reject(options.signal.reason),{once:true}));
  };
  try{
    await assert.rejects(prokeralaJson(credentials('timeout'),'/astrology/kundli',input),{name:'TimeoutError'});
    assert.equal(calls,1);assert.deepEqual(durations,[10000,12000]);
  }finally{globalThis.fetch=original;AbortSignal.timeout=timeout;}
});
test('authentication redirect cannot reach a paid module',async()=>{
  const original=globalThis.fetch;let calls=0;
  globalThis.fetch=async(address,options)=>{
    calls++;assert.equal(String(address),'https://api.prokerala.com/token');
    assert.equal(options.redirect,'manual');
    return new Response('',{status:307,headers:{Location:'https://elsewhere.invalid'}});
  };
  try{
    await assert.rejects(prokeralaJson(credentials('auth-redirect'),'/astrology/kundli',input),/authentication failed/);
    assert.equal(calls,1);
  }finally{globalThis.fetch=original;}
});
