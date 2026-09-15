import {createHash, createHmac} from 'node:crypto';
import {sealReply} from '../db/guidance-requests';
import type {PostgresDatabase} from './postgres';

const reasons = new Set(['harmful', 'sexual', 'hateful', 'misleading', 'privacy', 'other']);
// The selected answer is submitted deliberately; no birth details or whole
// conversation are attached. Auth and ownership are rechecked in the write
// transaction so a concurrent account deletion cannot resurrect private data.
export async function reportAnswer(request:Request, db:PostgresDatabase, secret:string|undefined, tester:string, now=Date.now()) {
  const token=/^Bearer ([a-f0-9]{64})$/.exec(request.headers.get('authorization') ?? '')?.[1];
  if(!token)return Response.json({error:'Sign in to report an answer.'},{status:401});
  const body=await request.json().catch(()=>null);
  if(!body || body.consent!==true || !reasons.has(body.reason) || typeof body.answer!=='string' || !body.answer.trim() || body.answer.length>20000 || typeof body.guide!=='string' || body.guide.length>80)
    return Response.json({error:'Choose a reason and confirm sending this answer.'},{status:422});
  if(!secret)return Response.json({error:'Reporting is temporarily unavailable. Please retry.'},{status:503});
  const tokenHash=createHash('sha256').update(token).digest('hex');
  return db.transaction(async tx=>{
    const login=await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[tokenHash,tester,now]);
    const account=login.rows[0]?.account_id;
    if(!account)return Response.json({error:'Sign in again to report this answer.'},{status:401});
    await tx.query('DELETE FROM answer_reports WHERE created_at<$1',[now-90*86400000]);
    const id=createHmac('sha256',secret).update(JSON.stringify([account,body.guide,body.answer,body.reason])).digest('hex');
    if((await tx.query('SELECT id FROM answer_reports WHERE id=$1',[id])).rowCount)
      return Response.json({reported:true});
    const count=await tx.query('SELECT count(*) AS total FROM answer_reports WHERE account_id=$1 AND created_at>$2',[account,now-86400000]);
    if(Number(count.rows[0].total)>=30)return Response.json({error:'You have sent many reports today. Please try again tomorrow.'},{status:429});
    const ciphertext=await sealReply(secret,id,{answer:body.answer,guide:body.guide});
    await tx.query('INSERT INTO answer_reports(id,account_id,reason,content_ciphertext,created_at) VALUES($1,$2,$3,$4,$5)',[id,account,body.reason,ciphertext,now]);
    return Response.json({reported:true});
  });
}
