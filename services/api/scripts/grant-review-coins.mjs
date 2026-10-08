import {Pool} from 'pg';
import {createHmac,randomUUID} from 'node:crypto';
// Server operator only. No public API and no provider payment is created.
const [phone,coinsText,grantId,reason]=process.argv.slice(2);
const coins=Number(coinsText);
if(!/^[6-9]\d{9}$/.test(phone??'')||!Number.isSafeInteger(coins)||coins<1||coins>5000||!/^review-[a-z0-9-]{8,100}$/.test(grantId??'')||!reason||reason.length>300)throw Error('Expected Indian phone, 1–5000 coins, stable review-grant ID and reason');
const db=new Pool({connectionString:process.env.DATABASE_URL,max:1});
const tx=await db.connect();
try{
 await tx.query('BEGIN');
 const hash=createHmac('sha256',process.env.JYOTARA_PHONE_AUTH_KEY).update('phone:'+phone).digest('hex');
 const account=(await tx.query('SELECT id FROM phone_accounts WHERE phone_hash=$1 FOR UPDATE',[hash])).rows[0];
 if(!account)throw Error('Account must sign in first');
 const prior=(await tx.query('SELECT * FROM live_wallet_orders WHERE account_id=$1 AND request_id=$2',[account.id,grantId])).rows[0];
 if(prior&&(Number(prior.coins)!==coins||Number(prior.amount)!==0||prior.payment_method!=='review_grant'))throw Error('Grant ID already used for different details');
 if(!prior){
  const id=randomUUID(),now=Date.now();
  await tx.query("INSERT INTO live_wallet_orders(id,account_id,request_id,pack_id,amount,coins,remaining,status,payment_method,created_at,updated_at) VALUES($1,$2,$3,'review',0,$4,$4,'paid','review_grant',$5,$5)",[id,account.id,grantId,coins,now]);
  await tx.query('INSERT INTO live_wallet_review_grants(order_id,reason,created_at) VALUES($1,$2,$3)',[id,reason,now]);
 }
 const balance=(await tx.query("SELECT COALESCE(sum(remaining),0) balance FROM live_wallet_orders WHERE account_id=$1 AND status='paid'",[account.id])).rows[0].balance;
 await tx.query('COMMIT');
 console.log(JSON.stringify({phoneEnding:phone.slice(-4),granted:!prior,reviewCoins:coins,balance:Number(balance)}));
}catch(e){await tx.query('ROLLBACK');throw e;}finally{tx.release();await db.end();}
