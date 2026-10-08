import test from 'node:test';
import assert from 'node:assert/strict';
import {moduleFor} from './helpers/load.mjs';
const {supportTickets}=await import(moduleFor('../runtime/support-tickets.ts'));
const {sealReply}=await import(moduleFor('../db/guidance-requests.ts'));
const secret='a3'.repeat(32);
test('ticket details require authentication and return only the authenticated account with decrypted replies',async()=>{
 const ticket={id:'ticket-one',category:'app',status:'in_progress',created_at:10,content_ciphertext:await sealReply(secret,'ticket-one',{message:'Original issue',replies:[{message:'Team response',createdAt:20}]})};
 let reads=0;
 const db={transaction:fn=>fn({query:async(sql,args)=>{
  if(sql.includes('phone_login_sessions'))return {rows:[{account_id:'owner-one'}]};
  reads++;assert.equal(args[0],'owner-one');assert.match(sql,/WHERE account_id=\$1/);return {rows:[ticket]};
 }})};
 const req=auth=>new Request('https://test/api/support/list',{method:'POST',headers:auth?{authorization:'Bearer '+'a'.repeat(64)}:{},body:'{}'});
 assert.equal((await supportTickets(req(false),db,'test',secret)).status,401);
 assert.equal(reads,0);
 const data=await (await supportTickets(req(true),db,'test',secret)).json();
 assert.equal(data.tickets[0].message,'Original issue');
 assert.deepEqual(data.tickets[0].replies,[{message:'Team response',createdAt:20}]);
 assert.equal('content_ciphertext' in data.tickets[0],false);
});
