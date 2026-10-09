import {Pool} from 'pg';
if(!process.env.DATABASE_URL)throw Error('Protected database configuration required');
const from=process.argv[2]??new Date(Date.now()-30*86400000).toISOString().slice(0,10);
if(!/^\d{4}-\d{2}-\d{2}$/.test(from))throw Error('Expected YYYY-MM-DD');
const db=new Pool({connectionString:process.env.DATABASE_URL,max:1,statement_timeout:5000});
const client=await db.connect();
try{
 await client.query('BEGIN READ ONLY');
 const rows=(await client.query(`SELECT feature,provider,model,sum(attempt_count) AS attempts,sum(finished_count) AS finished,sum(failed_count) AS failed,sum(uncertain_count) AS uncertain,sum(known_usd_count) AS with_reported_usd,sum(known_credit_count) AS with_reported_credits,sum(attempt_count)-sum(known_usd_count) AS unknown_usd_count,sum(attempt_count)-sum(known_credit_count) AS unknown_credit_count,CASE WHEN sum(known_usd_count)>0 THEN sum(reported_cost_usd) ELSE NULL END AS reported_cost_usd,CASE WHEN sum(known_credit_count)>0 THEN sum(charged_credits) ELSE NULL END AS charged_credits FROM service_cost_daily_totals WHERE day_key >= $1 GROUP BY feature,provider,model ORDER BY feature,provider,model`,[from])).rows;
 console.log(JSON.stringify({fromUtcDay:from,scope:'Known provider-reported sums only; missing reports are unknown. These totals are not complete expense or profit. Failed counts describe provider attempts.',rows}));await client.query('ROLLBACK');
}catch{await client.query('ROLLBACK').catch(()=>{});console.error('Cost summary unavailable');process.exitCode=1;}
finally{client.release();await db.end();}
