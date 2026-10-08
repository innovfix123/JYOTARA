import {randomUUID,createHash} from 'node:crypto';
import {sealReply,openReply} from '../db/guidance-requests';
import {jsonObject} from './json-object';
import type {PostgresDatabase} from './postgres';
export async function supportTickets(request:Request,db:PostgresDatabase,tester:string,secret:string|undefined){
 const token=/^Bearer ([a-f0-9]{64})$/.exec(request.headers.get('authorization')??'')?.[1];
 if(!token)return Response.json({error:'Sign in to contact support.'},{status:401});
 const body=await jsonObject(request);if(!body||!secret)return Response.json({error:'Support is temporarily unavailable.'},{status:503});
 const listing=new URL(request.url).pathname.endsWith('/list');
 if(!listing&&(body.consent!==true||!['app','payment','account','other'].includes(String(body.category))||typeof body.message!=='string'||body.message.trim().length<5||body.message.length>3000||typeof body.requestId!=='string'||!/^[-a-zA-Z0-9]{16,80}$/.test(body.requestId)))return Response.json({error:'Choose a category, describe the problem and confirm sending it.'},{status:422});
 return db.transaction(async tx=>{
  const account=(await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[createHash('sha256').update(token).digest('hex'),tester,Date.now()])).rows[0]?.account_id;
  if(!account)return Response.json({error:'Sign in again.'},{status:401});
  if(listing){
    const rows=(await tx.query('SELECT id,category,status,created_at,content_ciphertext FROM support_tickets WHERE account_id=$1 ORDER BY created_at DESC LIMIT 30',[account])).rows;
    const tickets=await Promise.all(rows.map(async (row:any)=>{let message='';let replies: {message:string,createdAt:number}[]=[];try{const content=await openReply(secret,row.id,row.content_ciphertext) as {message?:string,replies?:unknown};message=typeof content.message==='string'?content.message:'';if(Array.isArray(content.replies))replies=content.replies.filter((r:any)=>r&&typeof r.message==='string'&&r.message.length<=3000&&Number.isSafeInteger(r.createdAt)).slice(-30).map((r:any)=>({message:r.message,createdAt:r.createdAt}));}catch{}const {content_ciphertext,...publicRow}=row;return {...publicRow,message,replies};}));
    return Response.json({tickets});
  }
  const prior=(await tx.query('SELECT id FROM support_tickets WHERE account_id=$1 AND request_id=$2',[account,body.requestId])).rows[0];
  if(prior)return Response.json({id:prior.id,status:'submitted'});
  const count=(await tx.query('SELECT count(*) AS n FROM support_tickets WHERE account_id=$1 AND created_at>$2',[account,Date.now()-86400000])).rows[0].n;
  if(Number(count)>=10)return Response.json({error:'Daily support request limit reached. Please email support.'},{status:429});
  const id=randomUUID(),cipher=await sealReply(secret,id,{message:body.message});
  await tx.query('INSERT INTO support_tickets(id,account_id,request_id,category,content_ciphertext,created_at) VALUES($1,$2,$3,$4,$5,$6)',[id,account,body.requestId,body.category,cipher,Date.now()]);
  return Response.json({id,status:'submitted'});
 });
}
