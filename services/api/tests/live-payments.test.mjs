import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {moduleFor} from './helpers/load.mjs';
const {LivePayments}=await import(moduleFor('../runtime/live-payments.ts'));
const env={JYOTARA_LIVE_PAYMENTS_ENABLED:'true',RAZORPAY_LIVE_KEY_ID:'rzp_live_synthetic',RAZORPAY_LIVE_KEY_SECRET:'synthetic-live',RAZORPAY_LIVE_WEBHOOK_SECRET:'synthetic-hook'};
test('live gateway requires separate enabled live credentials and webhook secret',()=>{
 assert.equal(!!new LivePayments({},env).configured(),true);
 for(const patch of [{JYOTARA_LIVE_PAYMENTS_ENABLED:'false'},{RAZORPAY_LIVE_KEY_ID:'rzp_test_synthetic'},{RAZORPAY_LIVE_KEY_SECRET:''},{RAZORPAY_LIVE_WEBHOOK_SECRET:''}])assert.equal(!!new LivePayments({},{...env,...patch}).configured(),false);
});
test('live webhook rejects sandbox signature and fetches authoritative payment with live credentials',async()=>{
 let calls=0,credited=0;
 const gateway=new LivePayments({},env,async(url,options)=>{
  calls++;assert.equal(url,'https://api.razorpay.com/v1/payments/pay_synthetic');
  assert.equal(options.headers.Authorization,'Basic '+Buffer.from('rzp_live_synthetic:synthetic-live').toString('base64'));
  return Response.json({id:'pay_synthetic',status:'authorized',captured:false});
 });
 const body=JSON.stringify({event:'payment.captured',payload:{payment:{entity:{id:'pay_synthetic',status:'captured'}}}});
 const req=secret=>new Request('https://example.test/api/payments/live/webhook',{method:'POST',body,headers:{'x-razorpay-signature':createHmac('sha256',secret).update(body).digest('hex')}});
 assert.equal((await gateway.webhook(req('sandbox-secret'),async()=>credited++)).status,400);assert.equal(calls,0);
 assert.equal((await gateway.webhook(req('synthetic-hook'),async p=>{assert.equal(p.status,'authorized');credited++;})).status,200);
 assert.equal(calls,1);assert.equal(credited,1);
});

test('QR credited webhook uses fetched payment and signed QR identity',async()=>{
 const gateway=new LivePayments({},env,async()=>Response.json({id:'pay_qr',status:'captured',captured:true}));
 const body=JSON.stringify({event:'qr_code.credited',payload:{payment:{entity:{id:'pay_qr'}},qr_code:{entity:{id:'qr_synthetic'}}}});
 const request=new Request('https://example.test/webhook',{method:'POST',body,headers:{'x-razorpay-signature':createHmac('sha256',env.RAZORPAY_LIVE_WEBHOOK_SECRET).update(body).digest('hex')}});
 let called=false;assert.equal((await gateway.webhook(request,async(p,qr)=>{called=true;assert.equal(qr,'qr_synthetic');assert.equal(p.id,'pay_qr');})).status,200);assert.equal(called,true);
});
