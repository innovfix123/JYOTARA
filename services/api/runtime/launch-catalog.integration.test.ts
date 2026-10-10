import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {PostgresDatabase} from './postgres';
import {CoinWallet} from './coin-wallet';
import {LivePayments} from './live-payments';
import {TestPayments} from './test-payments';

for(const mode of ['test','live'] as const)test(mode+' launch catalog: new purchases, immutable old orders, capture/refund and ownership',async()=>{
 if(!process.env.DATABASE_URL?.includes('jyotara_qa_payments146_launch'))throw Error('Isolated QA database required');
 const db=new PostgresDatabase(process.env.DATABASE_URL),owner='launch-catalog-'+mode,tester='catalog-qa-'+mode,token='a'.repeat(64);
 const env={JYOTARA_COIN_WALLET_ENABLED:'true',JYOTARA_CHART_TICKET_KEY:'e'.repeat(64),JYOTARA_LIVE_PAYMENTS_ENABLED:'true',RAZORPAY_LIVE_KEY_ID:'rzp_live_synthetic',RAZORPAY_LIVE_KEY_SECRET:'synthetic-secret',RAZORPAY_LIVE_WEBHOOK_SECRET:'synthetic-hook',JYOTARA_TEST_PAYMENTS_ENABLED:'true',RAZORPAY_MODE:'test',RAZORPAY_KEY_ID:'rzp_test_synthetic',RAZORPAY_KEY_SECRET:'synthetic-secret'};
 const calls:any[]=[];
 const gateway=new (mode==='live'?LivePayments:TestPayments)(db,env,async(input,options)=>{
  assert.ok(String(input).endsWith('/orders'),'Only synthetic order creation is allowed');
  const body=JSON.parse(options!.body as string);calls.push(body);
  return Response.json({id:'order_catalog'+calls.length,...body});
 });
 const wallet=new CoinWallet(db,env,gateway,mode);
 const req=(action:string,body:any={},catalog='2',bearer=token)=>new Request('https://example.test/api/wallet/'+action,{method:'POST',headers:{authorization:'Bearer '+bearer,'x-jyotara-wallet-catalog':catalog},body:JSON.stringify(body)});
 const status=async(catalog='2')=>await (await wallet.handle(req('status',{},catalog),tester)).json() as any;
 const create=async(body:any)=>{const r=await wallet.handle(req('create',body),tester);assert.equal(r.status,200,await r.clone().text());return await r.json() as any;};
 const payment=(order:any,id:string)=>({id,order_id:order.orderId,amount:order.amount,currency:'INR',status:'captured',captured:true,amount_refunded:0});
 try{
  await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[owner,'0000',Date.now()]);
  await db.pool.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[createHash('sha256').update(token).digest('hex'),owner,tester,Date.now()+600000]);
  assert.equal((await wallet.handle(req('status',{},'2','b'.repeat(64)),tester)).status,401);
  const expected=[['minuteentry',25,100],['minutestarter',49,200],['minuteregular',99,440],['minuteplus',199,920],['minutepremium',499,2400],['minutemax',999,5000]];
  const current=await status();assert.deepEqual(current.packs.map((p:any)=>[p.id,p.rupees,p.coins]),expected);assert.equal(current.billing.coinsPerMinute,40);
  assert.deepEqual((await status('1')).packs.map((p:any)=>[p.rupees,p.coins]),[[49,50],[149,200],[299,450],[499,800],[999,1800]]);
  // These rows predate the launch catalog. A retry or late capture must use their stored values.
  await db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,provider_order,created_at,updated_at) VALUES($1,$2,$3,'minutestarter',4900,80,80,'paid','order_priorPaid',1,1)`,[owner+'-paid',owner,'catalog-prior-paid']);
  await db.pool.query(`INSERT INTO ${wallet.ordersTable}(id,account_id,request_id,pack_id,amount,coins,remaining,status,provider_order,created_at,updated_at) VALUES($1,$2,$3,'minuteentry',2500,40,0,'created','order_priorPending',1,1)`,[owner+'-pending',owner,'catalog-prior-pending']);
  const pending=await create({requestId:'catalog-prior-pending',packId:'minuteentry'});
  assert.equal(pending.amount,2500);assert.equal(pending.coins,40);assert.equal(calls.length,0);
  assert.equal((await wallet.handle(req('create',{requestId:'catalog-prior-pending',packId:'minutestarter'}),tester)).status,409);
  const priorPayment=payment(pending,'pay_priorPending');await wallet.recordPayment(priorPayment);await wallet.recordPayment(priorPayment);
  let balance=120;assert.equal((await status()).balance,balance);
  const orders:any[]=[];
  for(const [id,rupees,coins] of expected){
   const body={requestId:'catalog-purchase-'+id,packId:id,coins:999999,amount:1};
   const order=await create(body);orders.push(order);
   assert.equal(order.amount,Number(rupees)*100);assert.equal(order.coins,coins);
   assert.equal(calls.at(-1).amount,order.amount);
   const count:number=calls.length;const again=await create(body);assert.equal(again.id,order.id);assert.equal(calls.length,count);
   const p=payment(order,'pay_'+id);await assert.rejects(()=>wallet.recordPayment({...p,amount:1}));assert.equal((await status()).balance,balance);
   await Promise.all([wallet.recordPayment(p),wallet.recordPayment(p)]);balance+=Number(coins);assert.equal((await status()).balance,balance);
  }
  const first=payment(orders[0],'pay_minuteentry');await wallet.recordPayment({...first,status:'refunded',amount_refunded:first.amount});balance-=100;
  await wallet.recordPayment(first);assert.equal((await status()).balance,balance);
  const stored=(await db.pool.query(`SELECT amount,coins,remaining FROM ${wallet.ordersTable} WHERE id=$1`,[owner+'-paid'])).rows[0];
  assert.deepEqual(stored,{amount:4900,coins:80,remaining:80});
 }finally{
  await db.pool.query('DELETE FROM phone_login_sessions WHERE account_id=$1',[owner]);
  await db.pool.query('DELETE FROM phone_accounts WHERE id=$1',[owner]);await db.close();
 }
});
