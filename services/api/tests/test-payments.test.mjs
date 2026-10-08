import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {moduleFor} from './helpers/load.mjs';
const {validSignature,paymentState,TestPayments}=await import(moduleFor('../runtime/test-payments.ts'));
test('signature rejects tampering and malformed values',()=>{
 const sign=createHmac('sha256','secret').update('order_x|pay_x').digest('hex');
 assert.equal(validSignature('secret','order_x|pay_x',sign),true);
 for(const bad of [undefined,'',sign.slice(1),'z'.repeat(64)])assert.equal(validSignature('secret','order_x|pay_x',bad),false);
 assert.equal(validSignature('secret','order_other|pay_x',sign),false);
});
test('credit requires captured payment for exact amount currency and order',()=>{
 const p={id:'pay_x',order_id:'order_x',amount:100,currency:'INR',status:'captured',captured:true,amount_refunded:0};
 assert.equal(paymentState(p,'order_x',100),'paid');
 for(const bad of [{order_id:'order_other'},{amount:1},{currency:'USD'}])assert.throws(()=>paymentState({...p,...bad},'order_x',100));
 assert.equal(paymentState({...p,status:'authorized',captured:false},'order_x',100),'pending');
 assert.equal(paymentState({...p,amount_refunded:1},'order_x',100),'refunded');
});
test('test gateway rejects live credentials and disabled configuration',()=>{
 const env={JYOTARA_TEST_PAYMENTS_ENABLED:'true',RAZORPAY_MODE:'test',RAZORPAY_KEY_ID:'rzp_test_synthetic',RAZORPAY_KEY_SECRET:'synthetic'};
 assert.equal(!!new TestPayments({},env).configured(),true);
 for(const patch of [{RAZORPAY_MODE:'live'},{RAZORPAY_KEY_ID:'rzp_live_x'},{JYOTARA_TEST_PAYMENTS_ENABLED:'false'},{RAZORPAY_KEY_SECRET:''}])assert.equal(!!new TestPayments({},{...env,...patch}).configured(),false);
});
