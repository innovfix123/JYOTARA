import {createHash} from 'node:crypto';
import {sealReply,openReply} from '../db/guidance-requests';
import {openChartDeletionTicket} from '../lib/chart-ticket';
import type {PostgresDatabase} from './postgres';

const keys=['version','origin','session','profileKey','nickname','preferredChatLanguage','relationshipStatus','profession','gender','birthplaceLabel','raw','birthTimeKnown','calculatedAt'];
export function profileBackupRecord(input:any) {
 if(!input || input.version!==1 || input.deletionRequested===true || typeof input.session!=='string' || !/^nirayana_pilot_session=[A-Za-z0-9_-]{1,128}$/.test(input.session) || typeof input.profileKey!=='string' || typeof input.birthTimeKnown!=='boolean' || !input.raw || typeof input.raw!=='object' || Array.isArray(input.raw))throw Error('Invalid profile');
 const parts=input.profileKey.split('|');
 if(parts.length!==4 || !Number.isFinite(Date.parse(parts[0])) || !Number.isFinite(Number(parts[1])) || Math.abs(Number(parts[1]))>90 || !Number.isFinite(Number(parts[2])) || Math.abs(Number(parts[2]))>180 || parts[3]!==String(input.birthTimeKnown) || typeof input.origin!=='string' || !/^https:\/\/api\.jyotara\.in\/?$/.test(input.origin) || typeof input.calculatedAt!=='string' || !Number.isFinite(Date.parse(input.calculatedAt)))throw Error('Invalid profile');
 for(const [field,max] of [['nickname',60],['birthplaceLabel',160],['preferredChatLanguage',20],['relationshipStatus',60],['profession',60],['gender',30]] as const)if(input[field]!=null && (typeof input[field]!=='string' || input[field].length>max || /[\x00-\x1f]/.test(input[field])))throw Error('Invalid profile');
 const value=Object.fromEntries(keys.filter(k=>input[k]!==undefined).map(k=>[k,input[k]]));
 if(Buffer.byteLength(JSON.stringify(value),'utf8')>200000)throw Error('Profile too large');
 return value;
}
export async function accountProfileBackup(request:Request,db:PostgresDatabase,secret:string|undefined,tester:string) {
 const token=request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
 if(!token || !secret)return Response.json({error:'Sign in to restore your profile.'},{status:401});
 const now=Date.now(),hash=createHash('sha256').update(token).digest('hex');
 return db.transaction(async tx=>{
  const login=(await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[hash,tester,now])).rows[0];
  if(!login)return Response.json({error:'Sign in to restore your profile.'},{status:401});
  const account=login.account_id;
  const body:any=await request.json().catch(()=>null);
  if(body?.action==='load'){
   const row=(await tx.query('SELECT session_id,payload_ciphertext,updated_at FROM account_profile_backups WHERE account_id=$1',[account])).rows[0];
   if(!row)return Response.json({profile:null});
   if((await tx.query('SELECT 1 FROM deleted_chart_sessions WHERE session_id=$1 AND expires_at>$2',[row.session_id,now])).rows.length){await tx.query('DELETE FROM account_profile_backups WHERE account_id=$1',[account]);return Response.json({profile:null});}
   try{return Response.json({profile:await openReply(secret,'birth-profile:'+account,row.payload_ciphertext,200000),updatedAt:Number(row.updated_at)});}
   catch{return Response.json({error:'Your saved profile could not be restored. Please retry.'},{status:503});}
  }
  if(body?.action==='save') {
   let value:any;try{value=profileBackupRecord(body.profile);}catch{return Response.json({error:'Invalid birth profile backup.'},{status:422});}
   const session=value.session.slice('nirayana_pilot_session='.length);
   const owned=(await tx.query('SELECT 1 FROM phone_profile_owners WHERE session_id=$1 AND account_id=$2',[session,account])).rows.length;
   if(!owned || (await tx.query("SELECT 1 FROM deleted_chart_sessions WHERE session_id=$1 AND expires_at>$2 UNION ALL SELECT 1 FROM profile_generations WHERE session_id=$1 AND status='deleted'",[session,now])).rows.length)return Response.json({error:'This profile is unavailable.'},{status:403});
   const ticket=await openChartDeletionTicket(secret,value.raw.chartTicket,session,value.raw.profileId,now);
   if(!ticket || ticket.birthTimeKnown!==value.birthTimeKnown)return Response.json({error:'Protected profile data is required.'},{status:422});
   const parts=value.profileKey.split('|');
   if((ticket.birthDatetime && Date.parse(ticket.birthDatetime)!==Date.parse(parts[0])) || (ticket.contextLocation && (ticket.contextLocation.latitude!==Number(parts[1]) || ticket.contextLocation.longitude!==Number(parts[2]))))return Response.json({error:'Birth details do not match the protected chart.'},{status:422});
   const cipher=await sealReply(secret,'birth-profile:'+account,value,200000);
   await tx.query('INSERT INTO account_profile_backups(account_id,session_id,payload_ciphertext,updated_at) VALUES($1,$2,$3,$4) ON CONFLICT(account_id) DO UPDATE SET session_id=EXCLUDED.session_id,payload_ciphertext=EXCLUDED.payload_ciphertext,updated_at=EXCLUDED.updated_at',[account,session,cipher,now]);
   return Response.json({saved:true,updatedAt:now});
  }
  return Response.json({error:'Choose a profile backup action.'},{status:422});
 });
}
