import { createHmac, createHash, randomInt, randomBytes, timingSafeEqual } from 'node:crypto';
import type { PostgresDatabase } from './postgres';

const digest = (value:string) => createHash('sha256').update(value).digest('hex');
const response = (body:unknown, status=200) => Response.json(body,{status,headers:{'Cache-Control':'no-store'}});
const invalid = () => response({error:'Invalid or expired code. Please try again.',code:'otp_invalid'},400);
export class PhoneAuth {
  constructor(private db:PostgresDatabase, private settings:Record<string,string|undefined>, private sendFetch:typeof fetch=fetch, private now=()=>Date.now()) {}
  configured() {return this.settings.JYOTARA_OTP_ENABLED==='true' && (this.settings.JYOTARA_PHONE_AUTH_KEY?.length ?? 0)>=32 && !!this.settings.AUTHKEY_KEY && /^\d+$/.test(this.settings.AUTHKEY_SID ?? '');}
  private hash(value:string) {return createHmac('sha256',this.settings.JYOTARA_PHONE_AUTH_KEY!).update(value).digest('hex');}
  async account(request:Request,tester:string):Promise<string|null> {
    const token=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
    if(!token)return null;
    const result=await this.db.pool.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[digest(token),tester,this.now()]);
    return result.rows[0]?.account_id ?? null;
  }
  async ownProfile(cookie:string,account:string|null,claim=false):Promise<boolean> {
    const session=cookie.split(';').map(v=>v.trim()).find(v=>v.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
    if(!session)return true;
    return this.db.transaction(async tx=>{
      if(claim && account) await tx.query('INSERT INTO phone_profile_owners(session_id,account_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[session,account]);
      const owner=await tx.query('SELECT account_id FROM phone_profile_owners WHERE session_id=$1',[session]);
      return !owner.rowCount || owner.rows[0].account_id===account;
    });
  }
  async handle(request:Request,tester:string):Promise<Response> {
    const path=new URL(request.url).pathname;
    if(path==='/api/auth/config')return response({enabled:this.configured()});
    if(!this.configured())return response({error:'Phone sign-in is being configured. Please try again later.',code:'otp_not_configured'},503);
    if(path==='/api/auth/logout') {
      const token=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
      if(token)await this.db.pool.query('DELETE FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2',[digest(token),tester]);
      return response({success:true});
    }
    if(path==='/api/auth/session') {
      const account=await this.account(request,tester);
      return account?response({authenticated:true,accountId:account}):response({error:'Please sign in again.',code:'phone_auth_required'},401);
    }
    let body:any;try{body=await request.json();}catch{return response({error:'Invalid request.'},400);}
    const mobile=typeof body?.mobile==='string'?body.mobile.trim():'';
    if(!/^[6-9]\d{9}$/.test(mobile))return response({error:'Enter a valid 10-digit Indian mobile number.'},422);
    const phone=this.hash('phone:'+mobile), now=this.now();
    if(path==='/api/auth/send') {
      const challenge=randomBytes(24).toString('hex'),code=String(randomInt(100000,1000000));
      const retryAfter=await this.db.transaction(async tx=>{
        await tx.query('DELETE FROM phone_rate_limits WHERE expires_at <= $1',[now]);
        await tx.query('DELETE FROM phone_challenges WHERE expires_at <= $1',[now]);
        await tx.query('DELETE FROM phone_login_sessions WHERE expires_at <= $1',[now]);
        const limits:[string,number,number][]=[['cool:'+phone,1,60000],['phone:'+phone,5,3600000],['tester:'+tester,20,3600000],['global',200,86400000]];
        let wait=0;
        for(const [key,limit] of limits) {
          const row=await tx.query('SELECT hits,expires_at FROM phone_rate_limits WHERE id=$1',[key]);
          if((row.rows[0]?.hits ?? 0)>=limit)wait=Math.max(wait,Math.ceil((row.rows[0].expires_at-now)/1000));
        }
        if(wait>0)return wait;
        for(const [key,,ttl] of limits)await tx.query('INSERT INTO phone_rate_limits(id,hits,expires_at) VALUES($1,1,$2) ON CONFLICT(id) DO UPDATE SET hits=phone_rate_limits.hits+1',[key,now+ttl]);
        await tx.query('DELETE FROM phone_challenges WHERE phone_hash=$1 AND tester_key=$2',[phone,tester]);
        await tx.query('INSERT INTO phone_challenges(id,phone_hash,tester_key,code_hash,expires_at,tries) VALUES($1,$2,$3,$4,$5,0)',[challenge,phone,tester,this.hash(challenge+':'+code),now+300000]);
        return 0;
      });
      if(retryAfter>0)return response({error:`Please wait ${Math.ceil(retryAfter/60)} minute${retryAfter>60?'s':''} before requesting another OTP. No SMS was sent for this attempt.`,code:'otp_rate_limit',retryAfterSeconds:retryAfter},429);
      const url=new URL('https://api.authkey.io/request');
      url.search=new URLSearchParams({authkey:this.settings.AUTHKEY_KEY!,sid:this.settings.AUTHKEY_SID!,mobile,country_code:'91',otp:code}).toString();
      try {
        const result=await this.sendFetch(url,{signal:AbortSignal.timeout(10000),redirect:'error'});
        const payload=await result.json() as {Message?:string;LogID?:unknown};
        // Operational metadata only: never log request URL, phone, code or credentials.
        console.info(JSON.stringify({event:'otp_sms_submission',accepted:result.ok && payload.Message==='Submitted Successfully',status:result.status,providerLogId:typeof payload.LogID==='string' && /^[a-zA-Z0-9_-]{1,100}$/.test(payload.LogID)?payload.LogID:undefined}));
        if(!result.ok || payload.Message!=='Submitted Successfully') {
          await this.db.pool.query('DELETE FROM phone_challenges WHERE id=$1',[challenge]);
          return response({error:'The SMS service could not accept your code. Please try again later.',code:'otp_send_failed'},503);
        }
      } catch {
        // Preserve the challenge for a delayed SMS; do not automatically resend.
        return response({challengeId:challenge,expiresIn:300,retryAfterSeconds:60,deliveryUnconfirmed:true});
      }
      return response({challengeId:challenge,expiresIn:300,retryAfterSeconds:60});
    }
    if(path==='/api/auth/verify') {
      if(typeof body.challengeId!=='string'||! /^[a-f0-9]{48}$/.test(body.challengeId)||typeof body.otp!=='string'||!/^\d{6}$/.test(body.otp))return invalid();
      const token=randomBytes(32).toString('hex'),expires=now+30*86400000;
      const account=await this.db.transaction(async tx=>{
        const found=await tx.query('SELECT * FROM phone_challenges WHERE id=$1 FOR UPDATE',[body.challengeId]);
        const rec=found.rows[0];
        if(!rec||rec.phone_hash!==phone||rec.tester_key!==tester||rec.expires_at<=this.now()||rec.tries>=5)return null;
        if(!timingSafeEqual(Buffer.from(rec.code_hash,'hex'),Buffer.from(this.hash(body.challengeId+':'+body.otp),'hex'))) {
          await tx.query('UPDATE phone_challenges SET tries=tries+1 WHERE id=$1',[body.challengeId]);return null;
        }
        await tx.query('DELETE FROM phone_challenges WHERE id=$1',[body.challengeId]);
        const user=await tx.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$2,$3,$4) ON CONFLICT(phone_hash) DO UPDATE SET last_four=EXCLUDED.last_four RETURNING id',[randomBytes(16).toString('hex'),phone,mobile.slice(-4),now]);
        const id=user.rows[0].id;
        await tx.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[digest(token),id,tester,expires]);
        return id;
      });
      return account?response({token,accountId:account,expiresAt:expires}):invalid();
    }
    return response({error:'Unknown authentication endpoint.'},404);
  }
}
