import {createHash} from 'node:crypto';
import type {PostgresDatabase} from './postgres';

/** First-party operational diagnostics, never forwarded to marketing SDKs.
 * Values are closed vocabularies: no names, input values, questions or replies. */
export const journeyEvents = new Set([
 'app.open','app.foreground','app.background','app.exit','screen.view','screen.leave',
 'interaction.tap','interaction.scroll','navigation.back','navigation.tab',
 'auth.send','auth.verify','auth.restore','auth.logout','auth.delete',
 'profile.create','profile.update','profile.restore','profile.delete',
 'chat.start','chat.send','chat.answer','chat.end','chat.back','chat.settings',
 'matching.start','matching.complete','matching.add','matching.delete','matching.share',
 'daily.open','daily.expand','explore.open','explore.reading',
 'payment.start','payment.verify','payment.refresh','payment.checkout',
 'settings.change','notification.open','notification.permission','support.send',
 'api.request','api.result','app.error',
]);
export const journeyScreens = new Set([
 'entry','welcome','login','otp','onboarding','birth_details','home','daily','explore',
 'ask','chat','profile','matching','matching_result','matching_studio','wallet',
 'checkout','settings','notifications','support','birth_chart','reading','dialog',
 'other',
]);
const outcomes=new Set(['started','success','failed','cancelled','pending','unavailable','restored','resumed','blocked']);
const features=new Set(['auth','profile','chat','matching','daily','explore','wallet','settings','notification','support','birth_chart','location','other']);
const controls=new Set(['primary','back','close','tab','menu','login','otp','resend','save','edit','delete','add_person','select_person','match','share','send','end_chat','language','guide','category','recharge','payment_refresh','consent','notification','support','other']);
const errorCodes=new Set(['network','timeout','unauthorized','validation','unavailable','provider','payment','storage','unknown']);
const metadataKeys=new Set(['outcome','feature','control','language','error','status','durationMs','count','source']);
export type JourneyEvent={id:string;sessionId:string;sequence:number;name:string;screen:string;at:number;metadata:Record<string,string|number>};
export function parseJourneyEvents(input:unknown,now=Date.now()):JourneyEvent[] {
 if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>k!=='events'))throw Error('Invalid event batch');
 const items=(input as {events?:unknown}).events;
 if(!Array.isArray(items)||items.length<1||items.length>50)throw Error('Invalid event batch');
 const seen=new Set<string>();
 return items.map(item=>{
  if(!item||typeof item!=='object'||Array.isArray(item)||Object.keys(item).some(k=>!['id','sessionId','sequence','name','screen','at','metadata'].includes(k)))throw Error('Invalid event');
  const {id,sessionId,sequence,name,screen,at,metadata={}}=item;
  // The server's received_at is authoritative. A wrong phone clock must not
  // reject a whole batch; keep its client timestamp only as diagnostic context.
  if(typeof id!=='string'||! /^[a-f0-9]{32}$/.test(id)||seen.has(id)||typeof sessionId!=='string'||! /^[a-f0-9]{32}$/.test(sessionId)||!Number.isSafeInteger(sequence)||sequence<1||sequence>10000000||!journeyEvents.has(name)||!journeyScreens.has(screen)||!Number.isSafeInteger(at)||at<=0||at>253402300799999)throw Error('Invalid event');
  if(!metadata||typeof metadata!=='object'||Array.isArray(metadata)||Object.keys(metadata).some(k=>!metadataKeys.has(k)))throw Error('Invalid metadata');
  const valid:Record<string,string|number>={};
  for(const [key,value] of Object.entries(metadata)){
   const allowed=key==='outcome'?outcomes:key==='feature'?features:key==='control'?controls:key==='language'?new Set(['en','ta','tanglish']):key==='error'?errorCodes:key==='source'?new Set(['touch','keyboard','system','api','app','push']):null;
   if(allowed){if(typeof value!=='string'||!allowed.has(value))throw Error('Invalid metadata');}
   else if(!Number.isSafeInteger(value)||Number(value)<0||Number(value)>(key==='status'?599:key==='durationMs'?86400000:1000000))throw Error('Invalid metadata');
   valid[key]=value as string|number;
  }
  seen.add(id);return {id,sessionId,sequence,name,screen,at,metadata:valid};
 });
}

export async function userJourney(request:Request,db:PostgresDatabase,tester:string,now=Date.now()) {
 const token=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
 if(!token)return Response.json({error:'Sign in required.'},{status:401});
 const raw=await request.text();
 if(Buffer.byteLength(raw,'utf8')>48000)return Response.json({error:'Event batch too large.'},{status:413});
 let events:JourneyEvent[];
 try{events=parseJourneyEvents(JSON.parse(raw),now);}catch{return Response.json({error:'Invalid activity metadata.'},{status:422});}
 const hash=createHash('sha256').update(token).digest('hex');
 return db.transaction(async tx=>{
  const login=(await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[hash,tester,now])).rows[0];
  if(!login)return Response.json({error:'Sign in required.'},{status:401});
  const account=login.account_id;
  // Explicit account lock also protects standalone transaction adapters; the
  // shared PostgresDatabase lock currently serializes application writes too.
  await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',['journey:'+account]);
  const existing=new Set((await tx.query('SELECT event_id FROM user_journey_events WHERE account_id=$1 AND event_id=ANY($2::text[])',[account,events.map(e=>e.id)])).rows.map(row=>row.event_id));
  const fresh=events.filter(event=>!existing.has(event.id));
  if(!fresh.length)return Response.json({accepted:events.map(e=>e.id)});
  // Diagnostics must not crowd out interactive service or grow without bounds.
  const hour=(await tx.query('SELECT count(*)::int count FROM user_journey_events WHERE account_id=$1 AND received_at>$2',[account,now-3600000])).rows[0]?.count??0;
  if(hour+fresh.length>6000)return Response.json({error:'Activity limit reached.'},{status:429,headers:{'Retry-After':'3600'}});
  let order=Number((await tx.query('SELECT coalesce(max(server_sequence),0) AS sequence FROM user_journey_events WHERE account_id=$1',[account])).rows[0]?.sequence??0);
  for(const event of fresh)await tx.query('INSERT INTO user_journey_events(account_id,event_id,app_session_id,sequence,event_name,screen,occurred_at,received_at,metadata_json,server_sequence) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) ON CONFLICT(account_id,event_id) DO NOTHING',[account,event.id,event.sessionId,event.sequence,event.name,event.screen,event.at,now,JSON.stringify(event.metadata),++order]);
  return Response.json({accepted:events.map(e=>e.id)});
 });
}
