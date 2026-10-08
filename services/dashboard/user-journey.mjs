/** Owner-only, read-only activity timeline. No payload contents or credentials. */
export async function journeyDashboard(request, pool, user, now=Date.now()) {
 if(!user)return Response.json({error:'Sign in required'},{status:401});
 if(user.role!=='owner')return Response.json({error:'Owner access required'},{status:403});
 const url=new URL(request.url);
 const days=Number(url.searchParams.get('days')||7);
 if(![1,7,30,90].includes(days))return Response.json({error:'Invalid time range'},{status:400});
 const since=now-days*86400000;
 if(url.pathname.endsWith('/users')){
  const result=await pool.query(`SELECT j.account_id AS account,a.last_four AS "lastFour",count(*)::int AS events,count(DISTINCT j.app_session_id)::int AS sessions,max(j.received_at) AS "lastSeen",count(*) FILTER(WHERE j.metadata_json::jsonb->>'outcome'='failed')::int AS failures FROM user_journey_events j JOIN phone_accounts a ON a.id=j.account_id WHERE j.received_at>=$1 GROUP BY j.account_id,a.last_four ORDER BY max(j.received_at) DESC LIMIT 100`,[since]);
  return Response.json({users:result.rows,days,retentionDays:90});
 }
 if(url.pathname.endsWith('/timeline')){
  const account=url.searchParams.get('account')||'';
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(account))return Response.json({error:'Choose an account'},{status:400});
  const before=Number(url.searchParams.get('before')||Number.MAX_SAFE_INTEGER);
  if(!Number.isSafeInteger(before)||before<0)return Response.json({error:'Invalid cursor'},{status:400});
  const result=await pool.query(`SELECT event_id AS id,app_session_id AS session,sequence,server_sequence AS "serverSequence",event_name AS name,screen,occurred_at AS "deviceAt",received_at AS "serverAt",metadata_json AS metadata FROM user_journey_events WHERE account_id=$1 AND received_at>=$2 AND server_sequence<$3 ORDER BY server_sequence DESC LIMIT 200`,[account,since,before]);
  const events=result.rows.map(row=>({...row,metadata:JSON.parse(row.metadata)}));
  const last=events.at(-1);
  return Response.json({account,events,hasMore:events.length===200,next:last?{before:last.serverSequence}:null});
 }
 return Response.json({error:'Not found'},{status:404});
}
