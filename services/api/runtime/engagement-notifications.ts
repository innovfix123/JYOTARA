import {createHash,createSign,randomBytes} from 'node:crypto';
import {readFileSync} from 'node:fs';
import type {PostgresDatabase} from './postgres';
import {sealReply,openReply} from '../db/guidance-requests';
import {jsonObject} from './json-object';

const digest=(value:string)=>createHash('sha256').update(value).digest('hex');
const dayMs=86400000;
export function notificationClock(now:number){
 const india=new Date(now+19800000);
 return {day:india.toISOString().slice(0,10),hour:india.getUTCHours()};
}
export function chooseReminder(state:{created:number;opened:number;used:number;foreground:number;daily:number;matching:number;chat:number;count:number;lastSent:number;kinds:string[]},now:number){
 const {hour}=notificationClock(now);
 if(hour<9||hour>=21||state.count>=2||!state.opened||now-state.opened<300000)return null;
 // A five-minute nudge is suppressed as soon as the person uses a feature.
 if(now-state.opened>=300000&&now-state.opened<dayMs&&state.used<state.opened&&!state.kinds.includes('inactivity'))return {kind:'inactivity',feature:state.created>now-7*dayMs?'welcome':'daily'};
 if(state.foreground>now-180000||state.used>now-3600000||state.lastSent>now-6*3600000)return null;
 const kind=hour>=18?'evening':hour>=10?'morning':null;
 if(!kind||state.kinds.includes(kind))return null;
 const feature=state.daily<now-7*dayMs?'daily':state.matching<now-7*dayMs?'matching':state.chat<now-7*dayMs?'chat':'daily';
 return {kind,feature};
}
export function reminderCopy(feature:string,language:string){
 const en:Record<string,[string,string]>={welcome:['Welcome to Jyotara','Your daily guidance is ready. Take a look when you have a moment.'],daily:['A moment for your day','Open Daily for today’s guidance and timings.'],matching:['Discover your connection','Explore Matching with a saved profile whenever you’re ready.'],chat:['What’s on your mind?','Your astrology guide is here when you want to ask a question.']};
 const ta:Record<string,[string,string]>={welcome:['Jyotara உங்களை வரவேற்கிறது','இன்றைய வழிகாட்டல் தயார். நேரம் கிடைக்கும்போது பாருங்கள்.'],daily:['உங்கள் நாளுக்கான வழிகாட்டல்','இன்றைய வழிகாட்டலையும் நேரங்களையும் Daily பகுதியில் பாருங்கள்.'],matching:['உங்கள் இணக்கத்தை அறியுங்கள்','சேமித்த விவரங்களுடன் Matching பகுதியைப் பாருங்கள்.'],chat:['உங்கள் மனதில் என்ன இருக்கிறது?','கேள்வி கேட்க விரும்பும்போது உங்கள் ஜோதிட வழிகாட்டியை அணுகலாம்.']};
 const [title,body]=(language==='ta'?ta:en)[feature]??en.daily;
 return {title,body};
}

export class EngagementNotifications {
 constructor(private db:PostgresDatabase,private env:Record<string,string|undefined>,private sendFetch:typeof fetch=fetch){}
 get secret(){return this.env.JYOTARA_CHART_TICKET_KEY??this.env.NIRAYANA_CHART_TICKET_KEY??'';}
 async handle(request:Request,account:string){
  const body:any=await jsonObject(request);if(!body)return Response.json({error:'Invalid notification request.'},{status:422});
  const login=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
  if(!login)return Response.json({error:'Sign in required.'},{status:401});
  const path=new URL(request.url).pathname;
  if(path.endsWith('/event')){
   if(!/^[a-f0-9]{32}$/.test(body.id??'')||!['received','opened'].includes(body.event))return Response.json({error:'Invalid notification event.'},{status:422});
   const column=body.event==='opened'?'opened_at':'received_at';
   const receipt=await this.db.pool.query(`UPDATE notification_campaigns SET ${column}=COALESCE(${column},$1) WHERE id=$2 AND account_id=$3`,[Date.now(),body.id,account]);
   return Response.json({accepted:receipt.rowCount===1});
  }
  if(path.endsWith('/disable')){
   await this.db.pool.query('UPDATE notification_devices SET enabled=0,updated_at=$1 WHERE account_id=$2 AND login_hash=$3',[Date.now(),account,digest(login)]);
   return Response.json({disabled:true});
  }
  if(typeof body.token!=='string'||! /^[A-Za-z0-9:_-]{50,4096}$/.test(body.token)||!['en','ta','tanglish'].includes(body.language)||!Number.isSafeInteger(body.build)||body.build<1||body.build>100000)return Response.json({error:'Invalid device registration.'},{status:422});
  const hash=digest(body.token),now=Date.now();
  return this.db.transaction(async tx=>{
   const prior=(await tx.query('SELECT account_id,enabled FROM notification_devices WHERE token_hash=$1 FOR UPDATE',[hash])).rows[0];
   if(prior?.enabled===1&&prior.account_id!==account)return Response.json({error:'Sign out of the previous account first.'},{status:409});
   await tx.query('UPDATE notification_devices SET enabled=0,updated_at=$1 WHERE account_id=$2 AND login_hash=$3 AND token_hash<>$4',[now,account,digest(login),hash]);
   const cipher=await sealReply(this.secret,hash,{token:body.token});
   await tx.query('INSERT INTO notification_devices(token_hash,account_id,login_hash,token_ciphertext,language,build,registered_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$7) ON CONFLICT(token_hash) DO UPDATE SET account_id=$2,login_hash=$3,token_ciphertext=$4,language=$5,build=$6,enabled=1,updated_at=$7',[hash,account,digest(login),cipher,body.language,body.build,now]);
   return Response.json({registered:true});
  });
 }
 private auth:{value:string;expires:number}|null=null;
 private async accessToken(){
  if(this.auth&&this.auth.expires>Date.now()+60000)return this.auth.value;
  const key=JSON.parse(readFileSync(this.env.JYOTARA_FCM_CREDENTIAL_FILE??'','utf8'));
  if(key.project_id!=='jyotra-db0f4'||!key.private_key||!key.client_email)throw Error('Invalid FCM configuration');
  const encode=(v:unknown)=>Buffer.from(JSON.stringify(v)).toString('base64url'),now=Math.floor(Date.now()/1000);
  const payload=encode({alg:'RS256',typ:'JWT'})+'.'+encode({iss:key.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600});
  const assertion=payload+'.'+createSign('RSA-SHA256').update(payload).sign(key.private_key,'base64url');
  const response=await this.sendFetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(15000)});
  const data:any=await response.json();if(!response.ok||typeof data.access_token!=='string')throw Error('FCM authentication failed');
  this.auth={value:data.access_token,expires:Date.now()+Math.min(Number(data.expires_in)||3600,3600)*1000};return this.auth.value;
 }
 private running=false;
 private cursor='';
 async tick(now=Date.now()){
  if(this.running||this.env.JYOTARA_ENGAGEMENT_NOTIFICATIONS!=='true')return;
  const {hour,day}=notificationClock(now);if(hour<9||hour>=21)return;
  this.running=true;
  try{
   const candidates=(await this.db.pool.query(`SELECT DISTINCT ON(d.account_id) d.*,a.created_at AS account_created FROM notification_devices d JOIN phone_accounts a ON a.id=d.account_id JOIN phone_login_sessions l ON l.token_hash=d.login_hash AND l.account_id=d.account_id AND l.expires_at>$1 WHERE d.enabled=1 AND d.account_id>$2 ORDER BY d.account_id,d.updated_at DESC LIMIT 500`,[now,this.cursor])).rows;
   this.cursor=candidates.length===500?candidates[candidates.length-1].account_id:'';
   for(const device of candidates){
    const job=await this.db.transaction(async tx=>{
     const latest=(await tx.query('SELECT enabled FROM notification_devices WHERE token_hash=$1 AND account_id=$2',[device.token_hash,device.account_id])).rows[0];if(latest?.enabled!==1)return null;
     const rows=(await tx.query('SELECT kind,created_at FROM notification_campaigns WHERE account_id=$1 AND day=$2',[device.account_id,day])).rows;
     const activity=(await tx.query(`SELECT COALESCE(max(received_at) FILTER(WHERE event_name IN ('app.open','app.foreground','auth.verify','auth.restore')),0) opened,
      COALESCE(max(received_at) FILTER(WHERE (event_name='daily.open' OR (event_name IN ('chat.answer','matching.complete','explore.reading','profile.create','profile.update') AND metadata_json::jsonb->>'outcome'='success'))),0) used,
      COALESCE(max(received_at) FILTER(WHERE event_name IN ('interaction.tap','interaction.scroll','app.foreground')),0) foreground,
      COALESCE(max(received_at) FILTER(WHERE event_name='daily.open'),0) daily,
      COALESCE(max(received_at) FILTER(WHERE event_name='matching.complete'),0) matching,
      COALESCE(max(received_at) FILTER(WHERE event_name='chat.answer' AND metadata_json::jsonb->>'outcome'='success'),0) chat
      FROM user_journey_events WHERE account_id=$1 AND received_at>$2`,[device.account_id,now-30*dayMs])).rows[0];
     const reminder=chooseReminder({...activity,created:Number(device.account_created),count:rows.length,lastSent:Math.max(0,...rows.map(r=>Number(r.created_at))),kinds:rows.map(r=>r.kind)},now);
     if(!reminder)return null;
     const id=randomBytes(16).toString('hex');
     await tx.query("INSERT INTO notification_campaigns(id,account_id,token_hash,day,kind,feature,status,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,'sending',$7,$7)",[id,device.account_id,device.token_hash,day,reminder.kind,reminder.feature,now]);
     return {id,...reminder};
    });
    if(!job)continue;
    try{
     const access=await this.accessToken();
     const active=(await this.db.pool.query('SELECT 1 FROM notification_devices d JOIN phone_login_sessions l ON l.token_hash=d.login_hash AND l.account_id=d.account_id WHERE d.token_hash=$1 AND d.account_id=$2 AND d.enabled=1 AND l.expires_at>$3',[device.token_hash,device.account_id,Date.now()])).rows.length;
     if(!active){await this.finish(job.id,'cancelled','disabled');continue;}
     const token:any=await openReply(this.secret,device.token_hash,device.token_ciphertext);
     const response=await this.sendFetch('https://fcm.googleapis.com/v1/projects/jyotra-db0f4/messages:send',{method:'POST',headers:{authorization:'Bearer '+access,'content-type':'application/json'},body:JSON.stringify({message:{token:token.token,notification:reminderCopy(job.feature,device.language),data:{campaignId:job.id,feature:job.feature},android:{ttl:'300s',collapse_key:'jyotara-engagement',notification:{channel_id:'jyotara_updates'}}}}),signal:AbortSignal.timeout(15000)});
     const data:any=await response.json();const code=response.ok?'accepted':data.error?.details?.find((d:any)=>d.errorCode)?.errorCode??data.error?.status??'rejected';
     await this.finish(job.id,response.ok?'accepted':'failed',/^[A-Z_a-z]{1,40}$/.test(code)?code:'rejected');
     if(code==='UNREGISTERED')await this.db.pool.query('UPDATE notification_devices SET enabled=0 WHERE token_hash=$1',[device.token_hash]);
    }catch{await this.finish(job.id,'uncertain','unavailable');} // Never resend an ambiguous push.
   }
  }finally{this.running=false;}
 }
 private async finish(id:string,status:string,code:string){await this.db.pool.query('UPDATE notification_campaigns SET status=$1,provider_code=$2,updated_at=$3 WHERE id=$4',[status,code,Date.now(),id]);}
}
