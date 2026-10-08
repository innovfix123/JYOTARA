import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash,createHmac} from 'node:crypto';
import {PostgresDatabase} from './postgres';
import {TestPayments} from './test-payments';
import {supportTickets} from './support-tickets';
test('isolated ledger: concurrent retries, ownership, capture, refund, support and erasure',async()=>{
 const url=process.env.DATABASE_URL!;if(!url?.includes('jyotara_qa_payments'))throw Error('Isolated QA database required');
 const db=new PostgresDatabase(url),token='a'.repeat(64),other='b'.repeat(64),tester='qa-payment';
 const env={JYOTARA_TEST_PAYMENTS_ENABLED:'true',RAZORPAY_MODE:'test',RAZORPAY_KEY_ID:'rzp_test_synthetic',RAZORPAY_KEY_SECRET:'synthetic'};
 let creates=0,refunded=0;
 const payment=()=>({id:'pay_test',order_id:'order_test',amount:100,currency:'INR',status:refunded?'refunded':'captured',captured:true,amount_refunded:refunded});
 const gateway=new TestPayments(db,env,async(input,options)=>{
  const path=String(input);
  if(path.endsWith('/orders')){creates++;return Response.json({id:'order_test',...JSON.parse(options!.body as string)});}
  if(path.endsWith('/payments/pay_test'))return Response.json(payment());
  if(path.endsWith('/orders/order_test/payments'))return Response.json({items:[payment()]});
  throw Error('Unexpected provider call');
 });
 const req=(path:string,body:object={},bearer=token)=>new Request('https://example.test/api/'+path,{method:'POST',headers:{authorization:'Bearer '+bearer},body:JSON.stringify(body)});
 try{
  await db.pool.query('DELETE FROM phone_login_sessions WHERE tester_key=$1',[tester]);
  await db.pool.query("DELETE FROM phone_accounts WHERE id IN ('qa-pay-a','qa-pay-b')");
  for(const [id,t]of [['qa-pay-a',token],['qa-pay-b',other]]){
   await db.pool.query('INSERT INTO phone_accounts(id,phone_hash,last_four,created_at) VALUES($1,$1,$2,$3)',[id,'0000',Date.now()]);
   await db.pool.query('INSERT INTO phone_login_sessions(token_hash,account_id,tester_key,expires_at) VALUES($1,$2,$3,$4)',[createHash('sha256').update(t).digest('hex'),id,tester,Date.now()+600000]);
  }
  const rs=await Promise.all(Array.from({length:6},()=>gateway.handle(req('payments/test/create',{requestId:'synthetic-request-0001'}),tester)));
  assert.equal(creates,1);const success=rs.find(r=>r.status===200)!;assert.ok(success);const order:any=await success.json();
  const verify={id:order.id,paymentId:'pay_test',signature:createHmac('sha256','synthetic').update('order_test|pay_test').digest('hex')};
  assert.equal((await gateway.handle(req('payments/test/verify',verify,other),tester)).status,404);
  assert.equal((await gateway.handle(req('payments/test/verify',{...verify,signature:'0'.repeat(64)}),tester)).status,400);
  const results=await Promise.all(Array.from({length:8},()=>gateway.handle(req('payments/test/verify',verify),tester)));assert.ok(results.every(r=>r.status===200));
  let history:any=await (await gateway.handle(req('payments/test/history'),tester)).json();assert.equal(history.demoCredits,1);
  refunded=100;await gateway.handle(req('payments/test/refresh',{id:order.id}),tester);
  history=await (await gateway.handle(req('payments/test/history'),tester)).json();assert.equal(history.demoCredits,0);
  refunded=0;await gateway.handle(req('payments/test/verify',verify),tester);
  history=await (await gateway.handle(req('payments/test/history'),tester)).json();assert.equal(history.demoCredits,0);
  const body={requestId:'synthetic-support-0001',consent:true,category:'payment',message:'Synthetic payment support issue'};
  for(let i=0;i<2;i++)assert.equal((await supportTickets(req('support/create',body),db,tester,'c'.repeat(64))).status,200);
  const tickets:any=await (await supportTickets(req('support/list'),db,tester,'c'.repeat(64))).json();assert.equal(tickets.tickets.length,1);
  const others:any=await (await supportTickets(req('support/list',{},other),db,tester,'c'.repeat(64))).json();assert.equal(others.tickets.length,0);
  const stored=(await db.pool.query('SELECT content_ciphertext FROM support_tickets')).rows[0];assert.ok(!stored.content_ciphertext.includes(body.message));
  await db.pool.query('DELETE FROM phone_login_sessions WHERE tester_key=$1',[tester]);await db.pool.query("DELETE FROM phone_accounts WHERE id IN ('qa-pay-a','qa-pay-b')");
  assert.equal((await db.pool.query('SELECT count(*) AS n FROM test_payment_orders')).rows[0].n,0);
  assert.equal((await db.pool.query('SELECT count(*) AS n FROM support_tickets')).rows[0].n,0);
 }finally{await db.close();}
});
