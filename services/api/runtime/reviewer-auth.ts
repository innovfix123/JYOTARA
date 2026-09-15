import {createHash, createHmac, randomBytes, timingSafeEqual} from 'node:crypto';
import type {PostgresDatabase} from './postgres';

const digest = (value:string) => createHash('sha256').update(value).digest('hex');
const reply = (value:unknown,status=200) => Response.json(value,{status,headers:{'Cache-Control':'no-store'}});

// An isolated demo identity, never an OTP override for a customer's phone.
export async function reviewerLogin(request:Request,db:PostgresDatabase,settings:Record<string,string|undefined>,tester:string,now=Date.now()) {
  const expected=settings.JYOTARA_REVIEW_PASSWORD_SHA256;
  const secret=settings.JYOTARA_PHONE_AUTH_KEY;
  if(tester!=='public-v1' || !expected || !/^[a-f0-9]{64}$/.test(expected) || !secret || secret.length<32) return reply({error:'Review access is unavailable.'},503);
  const body=await request.json().catch(()=>null);
  if(typeof body?.password!=='string' || body.password.length>256) return reply({error:'Invalid review credentials.'},401);
  const limited=await db.transaction(async tx=>{
    await tx.query('DELETE FROM phone_rate_limits WHERE expires_at <= $1',[now]);
    const row=await tx.query('SELECT hits FROM phone_rate_limits WHERE id=$1',['review-login']);
    if((row.rows[0]?.hits ?? 0)>=30)return true;
    await tx.query('INSERT INTO phone_rate_limits(id,hits,expires_at) VALUES($1,1,$2) ON CONFLICT(id) DO UPDATE SET hits=phone_rate_limits.hits+1',['review-login',now+60000]);
    return false;
  });
  if(limited)return reply({error:'Please wait a minute before trying review access again.'},429);
  if(body.username!=='jyotara-review' || !timingSafeEqual(Buffer.from(digest(body.password),'hex'),Buffer.from(expected,'hex'))) return reply({error:'Invalid review credentials.'},401);
  const phoneHash=createHmac('sha256',secret).update('review-account:play-console:v1').digest('hex');
  const token=randomBytes(32).toString('hex'),expiresAt=now+30*86400000;
  const accountId=await db.transaction(async tx=>{
    const user=await tx.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$2,$3,$4) ON CONFLICT(phone_hash) DO UPDATE SET last_four=EXCLUDED.last_four RETURNING id',[randomBytes(16).toString('hex'),phoneHash,'DEMO',now]);
    const id=user.rows[0].id;
    await tx.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[digest(token),id,tester,expiresAt]);
    return id;
  });
  return reply({token,accountId,expiresAt});
}
