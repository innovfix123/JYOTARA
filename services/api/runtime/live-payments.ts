import type {PostgresDatabase} from './postgres';
import {TestPayments,validSignature} from './test-payments';

/** Dedicated live credentials; the existing sandbox gateway remains unchanged. */
export class LivePayments {
 private identity:TestPayments;
 constructor(db:PostgresDatabase,private env:Record<string,string|undefined>,private fetcher:typeof fetch=fetch){this.identity=new TestPayments(db,env);}
 configured(){return this.env.JYOTARA_LIVE_PAYMENTS_ENABLED==='true'&&/^rzp_live_[A-Za-z0-9]+$/.test(this.env.RAZORPAY_LIVE_KEY_ID??'')&&!!this.env.RAZORPAY_LIVE_KEY_SECRET&&!!this.env.RAZORPAY_LIVE_WEBHOOK_SECRET;}
 account(tx:any,request:Request,tester:string){return this.identity.account(tx,request,tester);}
 async provider(path:string,body?:object):Promise<Record<string,any>>{
  if(!this.configured())throw Error('Live payments unavailable');
  const r=await this.fetcher('https://api.razorpay.com/v1/'+path,{method:body?'POST':'GET',headers:{Authorization:'Basic '+Buffer.from(this.env.RAZORPAY_LIVE_KEY_ID+':'+this.env.RAZORPAY_LIVE_KEY_SECRET).toString('base64'),'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
  if(!r.ok)throw Error('Payment provider unavailable');
  return await r.json() as Record<string,any>;
 }
 async webhook(request:Request,onPayment:(p:Record<string,any>,qr?:string)=>Promise<unknown>){
  if(!this.configured())return Response.json({error:'Webhook unavailable.'},{status:503});
  const raw=await request.text();
  if(!validSignature(this.env.RAZORPAY_LIVE_WEBHOOK_SECRET!,raw,request.headers.get('x-razorpay-signature')))return Response.json({error:'Invalid signature.'},{status:400});
  try{
   const event=JSON.parse(raw);
   if(!['payment.captured','payment.failed','refund.processed','qr_code.credited'].includes(event.event))return Response.json({received:true});
   const id=event.payload?.payment?.entity?.id??event.payload?.refund?.entity?.payment_id;
   if(typeof id!=='string'||!/^pay_[A-Za-z0-9]+$/.test(id))return Response.json({error:'Invalid payment.'},{status:400});
   // Never credit a signed payload alone: re-fetch using this account's live key.
   await onPayment(await this.provider('payments/'+id),event.event==='qr_code.credited'?event.payload?.qr_code?.entity?.id:undefined);
   return Response.json({received:true});
  }catch{return Response.json({error:'Retry webhook later.'},{status:503});}
 }
}
