import {createHmac} from 'node:crypto';
import {openChartTicket,openBirthGuidanceTicket} from '../lib/chart-ticket';
import type {PostgresDatabase} from './postgres';
import {jsonObject} from './json-object';

/** Side-effect-free receipt lookup. A price quote never counts as received. */
export async function guidanceStatus(request:Request,db:PostgresDatabase,account:string,secret:string){
 const body=await jsonObject(request);
 if(!body||typeof body.requestId!=='string'||! /^[A-Za-z0-9_-]{16,128}$/.test(body.requestId)||typeof body.profileId!=='string'||typeof body.chartTicket!=='string')return Response.json({error:'Valid request and profile are required.'},{status:422});
 const session=/nirayana_pilot_session=([A-Za-z0-9_-]+)/.exec(request.headers.get('cookie')??'')?.[1];
 if(!session)return Response.json({error:'Reopen your protected profile.'},{status:401});
 const trusted=await openChartTicket(secret,body.chartTicket,session,body.profileId)??await openBirthGuidanceTicket(secret,body.chartTicket,session,body.profileId);
 if(!trusted)return Response.json({error:'Reopen your protected profile.'},{status:401});
 const owned=(await db.pool.query('SELECT 1 FROM phone_profile_owners WHERE session_id=$1 AND account_id=$2',[session,account])).rows.length;
 if(!owned)return Response.json({error:'This profile is unavailable.'},{status:403});
 const identity=createHmac('sha256',Buffer.from(secret,'hex')).update(JSON.stringify(['guidance-id-v1',session,body.requestId])).digest('hex');
 const rows=(await db.pool.query(`SELECT g.answer_mode,
 EXISTS(SELECT 1 FROM deleted_chart_sessions d WHERE d.session_id=$2 AND d.expires_at>$3) AS deleted,
 EXISTS(SELECT 1 FROM provider_attempts p JOIN service_requests s ON s.id=p.request_id WHERE s.account_id=$4 AND s.client_request_id=$5 AND s.profile_id=$6 AND s.feature='chat' AND p.finished_at IS NULL) AS processing,
 EXISTS(SELECT 1 FROM service_requests s WHERE s.account_id=$4 AND s.client_request_id=$5 AND s.profile_id=$6 AND s.feature='chat' AND s.delivery_uncertain=1) AS uncertain
 FROM guide_requests g WHERE g.id=$1 AND g.session_id=$2`,[identity,session,Date.now(),account,body.requestId,body.profileId])).rows;
 const row=rows[0];
 const state=!row?'absent':row.deleted||row.answer_mode==='deleted'?'deleted':row.answer_mode==='pending'?row.processing?'processing':'received':row.answer_mode==='reading_unavailable'?'failed':'complete';
 return Response.json({requestId:body.requestId,profileId:body.profileId,state,...(row?.uncertain?{deliveryUncertain:true}:{})},{headers:{'Cache-Control':'no-store'}});
}
