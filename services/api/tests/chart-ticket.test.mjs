import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
import ts from 'typescript';
const compile = text => ts.transpileModule(text, {compilerOptions: {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022}}).outputText;
const url = text => `data:text/javascript;base64,${Buffer.from(text).toString('base64')}`;
const evidence = url(compile(readFileSync(new URL('../lib/astrology-evidence.ts', import.meta.url), 'utf8')));
const ticket = url(compile(readFileSync(new URL('../lib/chart-ticket.ts', import.meta.url), 'utf8')).replace('./astrology-evidence', evidence));
const { issueChartTicket, openChartTicket, openChartRenewalTicket, openChartDeletionTicket, chartProviderDataFresh } = await import(ticket);

test('renewal window cannot substitute for refreshing provider data', async () => {
  const secret = 'ab'.repeat(32), now = Date.UTC(2026,8,7), day = 86400000;
  const input = {sessionId: 'renew-owner', profileId: 'renew-profile', birthTimeKnown: false,
    chart: {rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', planets: [], yogas: []}};
  const original = await issueChartTicket(secret, input, now);
  assert.equal(await openChartTicket(secret, original, input.sessionId, input.profileId, now + 2 * day), null);
  const recovered = await openChartRenewalTicket(secret, original, input.sessionId, input.profileId, now + 2 * day);
  assert.equal(recovered.renewalUntil, now + 30 * day);
  assert.equal(chartProviderDataFresh(recovered,now+day-1),true);
  assert.equal(chartProviderDataFresh(recovered,now+day),false);
  await assert.rejects(issueChartTicket(secret, { ...input, renewalUntil: recovered.renewalUntil }, now + 2 * day));
  assert.equal((await openChartRenewalTicket(secret, original, input.sessionId, input.profileId, now + 29 * day)).renewalUntil, now + 30 * day);
  assert.equal(await openChartRenewalTicket(secret, original, input.sessionId, input.profileId, now + 30 * day), null);
  assert.ok(await openChartDeletionTicket(secret, original, input.sessionId, input.profileId, now+2*day));
  assert.equal(await openChartRenewalTicket(secret, original, 'other-owner', input.profileId, now + 2 * day), null);
});

test('legacy renewed credentials cannot make old provider data current, but still permit deletion', async () => {
  const now=Date.UTC(2026,8,7),day=86400000,secret='ab'.repeat(32);
  const payload={version:1,sessionId:'legacy-owner',profileId:'legacy-profile',issuedAt:now+2*day,expiresAt:now+3*day,
    renewalUntil:now+30*day,birthTimeKnown:false,chart:{rashi:'Meena',nakshatra:'Uttara Bhadrapada',planets:[],yogas:[]}};
  const key=await crypto.subtle.importKey('raw',Uint8Array.from(secret.match(/../g).map(x=>parseInt(x,16))),'AES-GCM',false,['encrypt']);
  const iv=new Uint8Array(12).fill(1);
  const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:new TextEncoder().encode('nirayana:anonymous-chart:v1')},key,new TextEncoder().encode(JSON.stringify(payload)));
  const encoded=`v1.${Buffer.from(iv).toString('base64url')}.${Buffer.from(encrypted).toString('base64url')}`;
  assert.equal(await openChartTicket(secret,encoded,payload.sessionId,payload.profileId,now+2*day),null);
  assert.ok(await openChartDeletionTicket(secret,encoded,payload.sessionId,payload.profileId,now+2*day));
  assert.equal(chartProviderDataFresh(payload,now+2*day),false);
});

test('encrypted chart capability binds session/profile, rejects tampering and expires', async () => {
  const secret = 'ab'.repeat(32), now = Date.UTC(2026,8,7);
  const input = {sessionId: 'device-one', profileId: 'profile-one', birthTimeKnown: false,
    chart: {rashi: 'Meena', nakshatra: 'Uttara Bhadrapada', planets: [], yogas: []}};
  const token = await issueChartTicket(secret, input, now);
  assert.ok(!token.includes('Meena'));
  assert.notEqual(token, await issueChartTicket(secret, input, now), 'fresh random nonce');
  assert.deepEqual((await openChartTicket(secret, token, input.sessionId, input.profileId, now)).chart, input.chart);
  for (const [key,t,s,p,n] of [
    [secret,token,'other',input.profileId,now], [secret,token,input.sessionId,'other',now],
    ['cd'.repeat(32),token,input.sessionId,input.profileId,now],
    [secret,token,input.sessionId,input.profileId,now-1],
    [secret,token,input.sessionId,input.profileId,now+86400000],
    [secret,token+'=',input.sessionId,input.profileId,now],
    [secret,'v2'+token.slice(2),input.sessionId,input.profileId,now],
    [secret,token.slice(0,-4)+'AAAA',input.sessionId,input.profileId,now],
  ]) assert.equal(await openChartTicket(key,t,s,p,n), null);
  await assert.rejects(issueChartTicket('', input, now));
  await assert.rejects(issueChartTicket(secret, {...input, chart: {planets: [null]}}, now));
  const location = { latitude: 11.3428, longitude: 77.7274 };
  const located = await issueChartTicket(secret, { ...input, contextLocation: location }, now);
  assert.deepEqual((await openChartTicket(secret, located, input.sessionId, input.profileId, now)).contextLocation, location);
  await assert.rejects(issueChartTicket(secret, { ...input, contextLocation: { latitude: 91, longitude: 77 } }, now));
  await assert.rejects(issueChartTicket(secret, { ...input, contextLocation: { latitude: 11, longitude: NaN } }, now));
});
