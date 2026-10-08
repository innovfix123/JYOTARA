import {createHash, createHmac, randomUUID, timingSafeEqual} from 'node:crypto';
import type {PostgresDatabase} from './postgres';
import {jsonObject} from './json-object';

const json=(error:string,status=422)=>Response.json({error},{status});
export function validSignature(secret:string, message:string, signature:unknown) {
 if(typeof signature!=='string'||!/^[a-f0-9]{64}$/.test(signature))return false;
 const expected=createHmac('sha256',secret).update(message).digest();
 return timingSafeEqual(expected,Buffer.from(signature,'hex'));
}
export function paymentState(p:Record<string,unknown>, order:string, amount:number) {
 if(p.order_id!==order||p.amount!==amount||p.currency!=='INR'||typeof p.id!=='string'||!/^pay_[A-Za-z0-9]+$/.test(p.id))throw Error('Payment mismatch');
 if(p.status==='refunded'||(typeof p.amount_refunded==='number'&&p.amount_refunded>0))return 'refunded';
 if(p.status==='captured'&&p.captured===true)return 'paid';
 if(p.status==='failed')return 'failed';
 return 'pending';
}
export class TestPayments {
 constructor(private db:PostgresDatabase, private env:Record<string,string|undefined>, private fetcher:typeof fetch=fetch){}
 configured(){return this.env.JYOTARA_TEST_PAYMENTS_ENABLED==='true'&&this.env.RAZORPAY_MODE==='test'&&/^rzp_test_[A-Za-z0-9]+$/.test(this.env.RAZORPAY_KEY_ID??'')&&!!this.env.RAZORPAY_KEY_SECRET;}
 async provider(path:string,body?:object):Promise<Record<string,any>> {
  if(!this.configured())throw Error('Test payments unavailable');
  const r=await this.fetcher('https://api.razorpay.com/v1/'+path,{method:body?'POST':'GET',headers:{Authorization:'Basic '+Buffer.from(this.env.RAZORPAY_KEY_ID+':'+this.env.RAZORPAY_KEY_SECRET).toString('base64'),'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
  if(!r.ok)throw Error('Payment provider unavailable');
  return await r.json() as Record<string,any>;
 }
 async account(tx:any,request:Request,tester:string):Promise<string|null>{
  const token=/^Bearer ([a-f0-9]{64})$/.exec(request.headers.get('authorization')??'')?.[1];
  if(!token)return null;
  return (await tx.query('SELECT account_id FROM phone_login_sessions WHERE token_hash=$1 AND tester_key=$2 AND expires_at>$3',[createHash('sha256').update(token).digest('hex'),tester,Date.now()])).rows[0]?.account_id??null;
 }
 async handle(request:Request,tester:string){
  if(!this.configured())return json('Test payments are unavailable.',503);
  const body=await jsonObject(request);if(!body)return json('Invalid request.');
  const action=new URL(request.url).pathname.split('/').pop();
  if(action==='history')return this.db.transaction(async tx=>{
   const account=await this.account(tx,request,tester);if(!account)return json('Sign in again.',401);
   const rows=(await tx.query('SELECT id,provider_order,amount,status,created_at FROM test_payment_orders WHERE account_id=$1 ORDER BY created_at DESC LIMIT 30',[account])).rows;
   const credits=Number((await tx.query("SELECT count(*) AS n FROM test_payment_orders WHERE account_id=$1 AND status='paid'",[account])).rows[0].n);
   return Response.json({mode:'test',demoCredits:credits,orders:rows});
  });
  if(action==='create'){
   if(typeof body.requestId!=='string'||!/^[-a-zA-Z0-9]{16,80}$/.test(body.requestId))return json('Invalid request ID.');
   const reserved=await this.db.transaction(async tx=>{
    const account=await this.account(tx,request,tester);if(!account)return null;
    const existing=(await tx.query('SELECT * FROM test_payment_orders WHERE account_id=$1 AND request_id=$2',[account,body.requestId])).rows[0];
    if(existing)return {row:existing,fresh:false};
    if(Number((await tx.query('SELECT count(*) AS n FROM test_payment_orders WHERE account_id=$1 AND created_at>$2',[account,Date.now()-86400000])).rows[0].n)>=20)return {limited:true};
    const row={id:randomUUID(),account_id:account,amount:100,status:'creating'};
    await tx.query('INSERT INTO test_payment_orders(id,account_id,request_id,amount,created_at,updated_at) VALUES($1,$2,$3,100,$4,$4)',[row.id,account,body.requestId,Date.now()]);
    return {row,fresh:true};
   });
   if(!reserved)return json('Sign in again.',401);if('limited' in reserved)return json('Test payment limit reached.',429);
   let row:any=reserved.row;
   if(reserved.fresh){
    try{
     const p=await this.provider('orders',{amount:100,currency:'INR',receipt:row.id,partial_payment:false});
     if(typeof p.id!=='string'||!/^order_[A-Za-z0-9]+$/.test(p.id)||p.amount!==100||p.currency!=='INR'||p.receipt!==row.id)throw Error('Invalid order');
     const saved=await this.db.pool.query("UPDATE test_payment_orders SET provider_order=$1,status='created',updated_at=$2 WHERE id=$3 RETURNING *",[p.id,Date.now(),row.id]);
     if(!saved.rows[0])return json('Account or order no longer exists.',409);
     row=saved.rows[0];
    }catch{
     await this.db.pool.query("UPDATE test_payment_orders SET status='unconfirmed',updated_at=$1 WHERE id=$2 AND provider_order IS NULL",[Date.now(),row.id]);
     return json('Order creation could not be confirmed. No payment was started. Contact support before trying a new order.',503);
    }
   }
   if(!row.provider_order)return json('This order is still unconfirmed. Contact support.',409);
   if(row.status!=='created')return json('This order has already been processed. Refresh payment history.',409);
   return Response.json({id:row.id,orderId:row.provider_order,amount:100,currency:'INR',keyId:this.env.RAZORPAY_KEY_ID,mode:'test'});
  }
  if(action==='verify'||action==='refresh'){
   if(typeof body.id!=='string')return json('Order required.');
   const row=await this.db.transaction(async tx=>{
    const account=await this.account(tx,request,tester);if(!account)return null;
    return (await tx.query('SELECT * FROM test_payment_orders WHERE id=$1 AND account_id=$2',[body.id,account])).rows[0];
   });
   if(!row?.provider_order)return json('Order not found.',404);
   try{
    if(action==='verify'){
     if(typeof body.paymentId!=='string'||!/^pay_[A-Za-z0-9]+$/.test(body.paymentId)||!validSignature(this.env.RAZORPAY_KEY_SECRET!,row.provider_order+'|'+body.paymentId,body.signature))return json('Payment verification failed.',400);
     const p=await this.provider('payments/'+body.paymentId);
     const status=await this.record(row,p);return Response.json({status,mode:'test'});
    }
    const result=await this.provider('orders/'+row.provider_order+'/payments');
    if(!Array.isArray(result.items))throw Error('Invalid payment list');
    // One full payment per order; failed attempts must not overwrite capture.
    const candidate=result.items.find((p:any)=>p.status==='captured'||p.status==='refunded')??result.items.find((p:any)=>p.status==='authorized');
    if(!candidate)return Response.json({status:row.status,mode:'test'});
    return Response.json({status:await this.record(row,candidate),mode:'test'});
   }catch{return json('Payment is not confirmed yet. Refresh history; do not pay again.',503);}
  }
  return json('Unknown payment action.',404);
 }
 async record(row:any,p:Record<string,unknown>){
  const status=paymentState(p,row.provider_order,row.amount);
  return this.db.transaction(async tx=>{
   const current=(await tx.query('SELECT * FROM test_payment_orders WHERE id=$1 FOR UPDATE',[row.id])).rows[0];
   if(!current)throw Error('Order removed');
   if(current.provider_payment&&current.provider_payment!==p.id)throw Error('Different payment');
   if(current.status==='refunded'||(current.status==='paid'&&status!=='refunded'))return current.status;
   await tx.query('UPDATE test_payment_orders SET provider_payment=$1,status=$2,updated_at=$3 WHERE id=$4',[p.id,status,Date.now(),row.id]);
   return status;
  });
 }
 async webhook(request:Request, onPayment?: (p:Record<string,any>)=>Promise<unknown>){
  if(!this.configured()||!this.env.RAZORPAY_TEST_WEBHOOK_SECRET)return json('Webhook unavailable.',503);
  const raw=await request.text();
  if(!validSignature(this.env.RAZORPAY_TEST_WEBHOOK_SECRET,raw,request.headers.get('x-razorpay-signature')))return json('Invalid signature.',400);
  try{
   const event=JSON.parse(raw);const entity=event.payload?.payment?.entity;
   const id=entity?.id??event.payload?.refund?.entity?.payment_id;
   if(typeof id!=='string'||!/^pay_[A-Za-z0-9]+$/.test(id))return Response.json({received:true});
   const p=await this.provider('payments/'+id);
   const row=(await this.db.pool.query('SELECT * FROM test_payment_orders WHERE provider_order=$1',[p.order_id])).rows[0];
   if(row)await this.record(row,p);
   if(onPayment)await onPayment(p);
   return Response.json({received:true});
  }catch{return json('Retry webhook later.',503);}
 }
}
