import {Auth,sessionCookie} from './auth.mjs';
import {journeyDashboard} from './user-journey.mjs';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {performance} from 'node:perf_hooks';
const require=createRequire(process.env.DASHBOARD_PG_BASE || new URL('../api/package.json',import.meta.url));
const {Pool}=require('pg');
const pool=new Pool({connectionString:process.env.DATABASE_URL,max:2,connectionTimeoutMillis:4000,statement_timeout:5000});
const port=Number(process.env.DASHBOARD_PORT||8788);
const cache=new Map();const pending=new Map();
const dateSql="to_char(to_timestamp(created_at/1000.0) AT TIME ZONE 'Asia/Kolkata','YYYY-MM-DD')";
const real="account_id NOT LIKE 'office_demo_%'";
export async function collect(days){
 const now=Date.now(),since=days===1?Math.floor((now+19800000)/3600000)*3600000-19800000-23*3600000:now-days*86400000,tx=await pool.connect();
 const query=async(sql,args=[]) => (await tx.query(sql,args)).rows;
 try{
  await tx.query('BEGIN READ ONLY');await tx.query("SET LOCAL statement_timeout='5s'");
  const accounts=(await query(`SELECT count(*)::int total,count(*) FILTER(WHERE created_at >= $1)::int new FROM phone_accounts WHERE id NOT LIKE 'office_demo_%'`,[since]))[0];
  const buyers=(await query(`SELECT count(DISTINCT account_id)::int total FROM live_wallet_orders WHERE ${real} AND status='paid' AND amount>0 AND provider_payment IS NOT NULL`))[0];
  const money=(await query(`SELECT count(*) FILTER(WHERE status='paid' AND amount>0 AND provider_payment IS NOT NULL)::int purchases,coalesce(sum(amount) FILTER(WHERE status='paid' AND amount>0 AND provider_payment IS NOT NULL),0)::float8 paidPaise,count(DISTINCT account_id) FILTER(WHERE status='paid' AND amount>0 AND provider_payment IS NOT NULL)::int buyers,count(*) FILTER(WHERE status='failed' AND amount>0)::int failed,count(*) FILTER(WHERE status IN ('created','creating') AND amount>0)::int pending,count(*) FILTER(WHERE status='refunded')::int refunded,count(*) FILTER(WHERE refund_review=1)::int refundReview,coalesce(sum(coins) FILTER(WHERE payment_method='review_grant' AND status='paid'),0)::float8 grants FROM live_wallet_orders WHERE ${real} AND created_at >= $1`,[since]))[0];
  const usage=(await query(`SELECT count(*)::int attempts,count(*) FILTER(WHERE status='complete')::int completed,count(*) FILTER(WHERE status='failed')::int failed,count(*) FILTER(WHERE status='reserved')::int pending,count(DISTINCT account_id)::int active,coalesce(sum(cost) FILTER(WHERE status='complete'),0)::float8 coins FROM live_wallet_usage WHERE ${real} AND created_at >= $1`,[since]))[0];
  const dailyUsers=await query(`SELECT ${dateSql} AS "day",count(*)::int value FROM phone_accounts WHERE id NOT LIKE 'office_demo_%' AND created_at >= $1 GROUP BY 1 ORDER BY 1`,[since]);
  const dailyRevenue=await query(`SELECT ${dateSql} AS "day",coalesce(sum(amount),0)::float8 value FROM live_wallet_orders WHERE ${real} AND created_at >= $1 AND status='paid' AND amount>0 AND provider_payment IS NOT NULL GROUP BY 1 ORDER BY 1`,[since]);
  const activity=await query(`SELECT action,category,depth,status,count(*)::int count FROM live_wallet_usage WHERE ${real} AND created_at >= $1 GROUP BY action,category,depth,status ORDER BY count DESC LIMIT 40`,[since]);
  const payments=await query(`SELECT to_char(to_timestamp(created_at/1000.0) AT TIME ZONE 'Asia/Kolkata','DD Mon HH24:MI') time,amount::float8 amount,coins::int coins,status,payment_method method FROM live_wallet_orders WHERE ${real} AND created_at >= $1 AND amount>0 ORDER BY created_at DESC LIMIT 12`,[since]);
  const bucket="floor((created_at-$1)/3600000)::int";
  const hourlyUsers=days===1?await query(`SELECT ${bucket} bucket,count(*)::int value FROM phone_accounts WHERE id NOT LIKE 'office_demo_%' AND created_at >= $1 AND created_at <= $2 GROUP BY 1 ORDER BY 1`,[since,now]):[];
  const hourlyMoney=days===1?await query(`SELECT ${bucket} bucket,count(*) FILTER(WHERE status='paid' AND amount>0 AND provider_payment IS NOT NULL)::int purchases,coalesce(sum(amount) FILTER(WHERE status='paid' AND amount>0 AND provider_payment IS NOT NULL),0)::float8 value FROM live_wallet_orders WHERE ${real} AND created_at >= $1 AND created_at <= $2 GROUP BY 1 ORDER BY 1`,[since,now]):[];
  const hourlyUsage=days===1?await query(`SELECT ${bucket} bucket,count(DISTINCT account_id)::int users,count(*) FILTER(WHERE status='complete')::int completed,count(*) FILTER(WHERE status='failed')::int failed FROM live_wallet_usage WHERE ${real} AND created_at >= $1 AND created_at <= $2 GROUP BY 1 ORDER BY 1`,[since,now]):[];
  const dailyPurchases=await query(`SELECT ${dateSql} AS "day",count(*)::int value FROM live_wallet_orders WHERE ${real} AND created_at >= $1 AND status='paid' AND amount>0 AND provider_payment IS NOT NULL GROUP BY 1 ORDER BY 1`,[since]);
  const dailyUsage=await query(`SELECT ${dateSql} AS "day",count(DISTINCT account_id)::int value FROM live_wallet_usage WHERE ${real} AND created_at >= $1 GROUP BY 1 ORDER BY 1`,[since]);
  const tickets=(await query("SELECT count(*)::int count FROM support_tickets WHERE status='open'"))[0];
  await tx.query('COMMIT');
  const start=performance.now();let health;
  try{const r=await fetch(process.env.DASHBOARD_HEALTH_URL||'http://127.0.0.1:3000/healthz',{signal:AbortSignal.timeout(4000)});health={ok:r.ok,latencyMs:Math.round(performance.now()-start)};}catch{health={ok:false,latencyMs:null}}
  return {generatedAt:new Date(now).toISOString(),days,windowStart:new Date(since).toISOString(),hourlyUsers,hourlyMoney,hourlyUsage,dailyPurchases,dailyUsage,accounts,buyers,money,usage,dailyUsers,dailyRevenue,activity,payments,tickets,health,downloads:{connected:false},sources:{database:'Production PostgreSQL, read-only aggregation',timezone:'Asia/Kolkata',refreshSeconds:60}};
 }catch(e){await tx.query('ROLLBACK').catch(()=>{});throw e}finally{tx.release()}
}
async function snapshot(days){const c=cache.get(days);if(c&&Date.now()-c.at<60000)return c.data;if(pending.has(days))return pending.get(days);const job=collect(days).then(data=>{cache.set(days,{at:Date.now(),data});return data}).finally(()=>pending.delete(days));pending.set(days,job);return job;}
const auth=new Auth(process.env.DASHBOARD_AUTH_DB||'/var/lib/jyotara-dashboard/auth.sqlite');
const login=await readFile(new URL('./login.html',import.meta.url));
const html=await readFile(new URL('./index.html',import.meta.url));
const journeyHtml=await readFile(new URL('./user-journey.html',import.meta.url));
const server=createServer(async(req,res)=>{
 res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
 res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
 const host=req.headers.host||'';
 const allowedHost=process.env.DASHBOARD_HOST||'api.jyotara.in';
 if(host!==allowedHost&&!/^(127\.0\.0\.1|localhost):\d+$/.test(host)){res.writeHead(403);res.end();return;}
 const u=new URL(req.url,'http://localhost');const user=auth.user(req.headers.cookie);
 if(req.method==='GET'&&u.pathname==='/'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(user?html:login);return;}
 if(req.method==='GET'&&u.pathname==='/user-journey'){
  if(!user){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(login);return;}
  if(user.role!=='owner'){res.writeHead(403);res.end('Owner access required');return;}
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(journeyHtml);return;
 }
 if(req.method==='POST'){
  if(req.headers.origin!=='https://'+allowedHost){res.writeHead(403);res.end();return;}
  let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>4096){res.writeHead(413);res.end();return;}}
  const json=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body));};
  try{
   const body=JSON.parse(raw||'{}');
   if(u.pathname==='/api/login'||u.pathname==='/api/accept'){
    const token=u.pathname.endsWith('accept')?auth.accept(body.token,body.password):auth.login(body.email,body.password,String(req.headers['x-real-ip']||req.socket.remoteAddress));
    if(!token){json(401,{error:'Email or password is incorrect'});return;}res.setHeader('Set-Cookie',sessionCookie(token));json(200,{ok:true});return;
   }
   if(!user){json(401,{error:'Sign in required'});return;}
   if(u.pathname==='/api/logout'){auth.logout(req.headers.cookie);res.setHeader('Set-Cookie','jyotara_dashboard=; HttpOnly; Secure; SameSite=Strict; Path=/dashboard/; Max-Age=0');json(200,{ok:true});return;}
   if(u.pathname==='/api/invites'){
    if(user.role!=='owner'){json(403,{error:'Owner access required'});return;}
    const token=auth.invite(body.email);json(200,{url:'https://'+allowedHost+'/dashboard/#invite='+token});return;
   }
   json(404,{error:'Not found'});
  }catch(e){json(400,{error:['Use a password of 12–128 characters','Invitation expired or already used','Too many attempts. Try again in 15 minutes.','Account already exists','Invalid email'].includes(e.message)?e.message:'Request could not be completed'});}return;
 }
 if(req.method!=='GET'){res.writeHead(405);res.end();return;}
 if(!user){res.writeHead(401,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'Sign in required'}));return;}
 if(u.pathname==='/api/me'){res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(user));return;}
 if(u.pathname==='/api/journey/users'||u.pathname==='/api/journey/timeline'){
  try{const response=await journeyDashboard(new Request('http://localhost'+u.pathname+u.search),pool,user);res.writeHead(response.status,{'Content-Type':'application/json'});res.end(await response.text());}
  catch{res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'User activity unavailable.'}));}return;
 }
 if(u.pathname==='/api/metrics'){
  const days=Number(u.searchParams.get('days')||1);if(![1,7,30,90].includes(days)){res.writeHead(400);res.end();return;}
  try{const data=await snapshot(days);res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(data));}
  catch{res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'Live metrics unavailable. Check the server connection.'}));}return;
 }
 res.writeHead(404);res.end();
});
if(process.env.DASHBOARD_NO_LISTEN!=='true')server.listen(port,'127.0.0.1',()=>console.log('Private Jyotara dashboard ready on loopback:'+port));
process.on('SIGTERM',()=>server.close(()=>pool.end().then(()=>process.exit(0))));
