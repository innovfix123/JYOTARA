import {openChartTicket,openBirthGuidanceTicket,openChartQuoteTicket} from '../lib/chart-ticket';
import {appConfig} from './app-config';
import {walletCheckoutPage} from './wallet-checkout';
import {createHmac,randomUUID} from 'node:crypto';
import type {PostgresDatabase} from './postgres';
import {validSignature,paymentState} from './test-payments';
import {sealReply,openReply} from '../db/guidance-requests';
import {conversationTopic,conversationHistory,conversationMemory,previousUserMessages,relationshipFollowup,relationshipResponse,responseStyle} from '../lib/guidance-language';
import {profileOverviewQuestion} from '../lib/profile-overview';
import {jsonObject} from './json-object';
import {inferIntent,type GuidanceCategory} from '../lib/astrology-evidence';
import {matchingLanguage,validBirth} from './discovery';
import {recordWalletOutcome} from './financial-tracking';
import {localConversationAcknowledgement} from '../lib/conversation-acknowledgement';

export const coinPacks=[{id:'starter',rupees:49,coins:50},{id:'regular',rupees:149,coins:200},{id:'plus',rupees:299,coins:450},{id:'premium',rupees:499,coins:800},{id:'max',rupees:999,coins:1800}];
export const minuteCoinPacks=[{id:'minuteentry',rupees:25,coins:40},{id:'minutestarter',rupees:49,coins:80},{id:'minuteregular',rupees:99,coins:170},{id:'minuteplus',rupees:199,coins:360},{id:'minutepremium',rupees:499,coins:960},{id:'minutemax',rupees:999,coins:2000}];
export const minuteRate=40;
export const coinCost=(category:string,depth:string)=>{const c=appConfig().costs;return ['Love','Relationships','Breakup','Marriage'].includes(category)?(depth==='detailed'?c.relationshipDetailed:c.relationshipStandard):(depth==='detailed'?c.generalDetailed:c.generalStandard);};
const error=(message:string,status=422)=>Response.json({error:message},{status});
const stable=(v:any):string=>JSON.stringify(v&&typeof v==='object'?(Array.isArray(v)?v.map(x=>JSON.parse(stable(x))):Object.fromEntries(Object.keys(v).sort().filter(k=>v[k]!==undefined).map(k=>[k,JSON.parse(stable(v[k]))]))):v??null);
const rid=/^[a-zA-Z0-9_-]{16,128}$/;
const trialDurationMs=60000;
class IntroTrialEnded extends Error {}
const walletError=(e:unknown,status=422)=>e instanceof IntroTrialEnded
 ?Response.json({error:'Your free trial has finished. Choose a coin pack to continue, or explore the free features.',code:'intro_trial_ended'},{status:422})
 :error(e instanceof Error?e.message:'The request could not be completed.',status);
export interface WalletGateway {
 configured():boolean|string|undefined;
 provider(path:string,body?:object):Promise<Record<string,any>>;
 account(tx:any,request:Request,tester:string):Promise<string|null>;
}
export class CoinWallet {
 constructor(private db:PostgresDatabase,private env:Record<string,string|undefined>,private gateway:WalletGateway,readonly mode:'test'|'live'='test'){}
 get ordersTable(){return this.mode==='live'?'live_wallet_orders':'wallet_orders';}
 get usageTable(){return this.mode==='live'?'live_wallet_usage':'wallet_usage';}
 get keyId(){return this.mode==='live'?this.env.RAZORPAY_LIVE_KEY_ID:this.env.RAZORPAY_KEY_ID;}
 get keySecret(){return this.mode==='live'?this.env.RAZORPAY_LIVE_KEY_SECRET:this.env.RAZORPAY_KEY_SECRET;}
 get secret(){return this.env.JYOTARA_CHART_TICKET_KEY??this.env.NIRAYANA_CHART_TICKET_KEY??'';}
 enabled(){return this.env.JYOTARA_COIN_WALLET_ENABLED==='true'&&this.gateway.configured()&&/^[a-f0-9]{64}$/i.test(this.secret);}
 hash(value:any){return createHmac('sha256',this.secret).update(stable(this.mode==='live'?['live',value]:value)).digest('hex');}
 async balance(tx:any,account:string){return Number((await tx.query(`SELECT COALESCE(sum(remaining),0) n FROM ${this.ordersTable} WHERE account_id=$1 AND status='paid'`,[account])).rows[0].n);}
 clean(action:string,input:any){
  const b={...input};delete b.coinQuote;
  if(action==='matching') {
   // Presentation fields must not create a new comparison or coin charge.
   // Keep the male/female roles and actual calculation inputs distinct.
   const person=(p:any)=>({
    datetime:p?.exactTime===false&&typeof p?.datetime==='string'
      ?p.datetime.slice(0,10)+'T12:00:00+05:30':p?.datetime,
    latitude:p?.latitude,longitude:p?.longitude,exactTime:p?.exactTime,
   });
   return {boy:person(b.boy),girl:person(b.girl),consent:b.consent};
  }
  delete b.chartTicket; // Access renewal must not turn a retry into a new purchase.
  b.depth=b.depth??'standard';return b;
 }
 catalog(request:Request){return request.headers.get('x-jyotara-wallet-catalog')==='2'?minuteCoinPacks:coinPacks;}
 async introTrial(tx:any,account:string){
  const row=(await tx.query(`SELECT t.*,m.window_until,m.pending_usage,m.ended,u.created_at AS pending_since
   FROM intro_chat_trials t LEFT JOIN minute_chat_sessions m ON m.account_id=t.account_id AND m.mode=t.mode AND m.id=t.billing_session
   LEFT JOIN ${this.usageTable} u ON u.id=m.pending_usage WHERE t.account_id=$1 AND t.mode=$2`,[account,this.mode])).rows[0];
  if(!row){
   const eligible=(await tx.query(`SELECT id FROM phone_accounts WHERE id=$1
    AND NOT EXISTS(SELECT 1 FROM ${this.ordersTable} WHERE account_id=$1 AND status='paid')
    AND NOT EXISTS(SELECT 1 FROM ${this.usageTable} WHERE account_id=$1 AND action='guidance' AND status IN ('reserved','complete'))`,[account])).rows.length>0;
   return {state:eligible?'available':'unavailable',durationMs:trialDurationMs,remainingMs:eligible?trialDurationMs:0,started:false,pending:false};
  }
  const started=Number(row.window_until??0)>0;
  // During a provider request, the remainder is measured at dispatch. Its
  // completion extends the server deadline, so network waiting is excluded.
  const reference=row.pending_usage&&started?Number(row.pending_since):Date.now();
  const remaining=started?Math.max(0,Number(row.window_until)-reference):trialDurationMs;
  const state=row.state==='active'&&(row.ended===1||(started&&remaining===0&&!row.pending_usage))?'ended':row.state;
  return {state,durationMs:trialDurationMs,remainingMs:state==='active'||state==='offered'?remaining:0,started,pending:!!row.pending_usage,billingSession:row.billing_session,guide:row.guide};
 }
 async price(tx:any,account:string,action:string,input:any,request?:Request){
  if(!['guidance','matching'].includes(action)||!input||typeof input!=='object'||Array.isArray(input))throw Error('Choose a valid reading.');
  if(action==='guidance'&&input.responseMode==='conversation'&&(input.depth==='detailed'||input.upgradeFrom!=null))throw Error('Conversational answers use the standard price and do not support paid upgrades.');
  const timed=action==='guidance'&&input.billingVersion===2;
  if(input.billingVersion!==undefined&&input.billingVersion!==2)throw Error('Unsupported chat billing.');
  if(timed&&(!/^[a-f0-9]{32}$/.test(input.billingSession??'')||input.depth!=='standard'||input.responseMode!=='conversation'||input.upgradeFrom))throw Error('Reopen chat before continuing.');
  const body=this.clean(action,input),hash=this.hash([action,body]);
  const requestId=action==='matching'?'match-'+hash:body.requestId;
  if(typeof requestId!=='string'||!rid.test(requestId))throw Error('A saved request ID is required.');
  let existing=(await tx.query(`SELECT * FROM ${this.usageTable} WHERE account_id=$1 AND request_id=$2`,[account,requestId])).rows[0];
  let legacy=false;
  if(action==='matching'&&!existing){
   const previous={...input};delete previous.coinQuote;delete previous.requestId;
   const hashes=[...new Set([previous,{...previous,language:'en'},{...previous,language:'ta'}].map(v=>this.hash([action,v])))];
   existing=(await tx.query(`SELECT * FROM ${this.usageTable} WHERE account_id=$1 AND request_id=ANY($2::text[]) AND status='complete' AND result_ciphertext IS NOT NULL ORDER BY created_at,id LIMIT 1`,[account,hashes.map(h=>'match-'+h)])).rows[0];
   legacy=!!existing&&hashes.includes(existing.payload_hash);
   if(existing&&!legacy)throw Error('Saved comparison could not be verified.');
  }
  if(existing&&!legacy&&existing.payload_hash!==hash)throw Error('This request changed. Start a new question.');
  const depth=action==='matching'?'standard':body.depth;
  if(!['standard','detailed'].includes(depth))throw Error('Choose Standard or Detailed.');
  const dialogue=conversationHistory(body.conversationHistory,body.responseMode),memory=conversationMemory(body.conversationMemory,body.responseMode),history=previousUserMessages(body.previousUserMessages);
  if(dialogue===null||memory===null||history===null||(body.responseMode!==undefined&&body.responseMode!=='conversation'))throw Error('Invalid conversation.');
  const recentUserStatements=dialogue.filter(t=>t.role==='user').map(t=>t.content);
  const priorUserStatements=[...memory,...(recentUserStatements.length?recentUserStatements:history)];
  const category=action==='matching'?'Basic matching':conversationTopic(String(body.question??''),body.category,priorUserStatements);
  const safetyQuestion=relationshipFollowup(String(body.question??''))?[...priorUserStatements,body.question].join('\n'):String(body.question??'');
  const safe=action==='guidance'&&(inferIntent(category as GuidanceCategory,safetyQuestion)==='high_stakes'||['privacy','no_contact'].includes(relationshipResponse(category,String(body.question??''),priorUserStatements,responseStyle(body.responseStyle,body.language))?.kind??''));
  const binding=this.hash([body.profileId,body.question,body.guide,body.responseStyle,body.language]);
  const costs=appConfig().costs;
  // Old APKs only accept their displayed 20-coin Matching quote.
  const matchingCost=request?.headers.get('x-jyotara-wallet-catalog')==='2'?costs.matchingV2:costs.matching;
  let cost=action==='matching'?matchingCost:coinCost(category,depth),trial=false,chargedCategory=category;
  if(body.upgradeFrom){
   const parent=(await tx.query(`SELECT * FROM ${this.usageTable} WHERE id=$1 AND account_id=$2 AND action='guidance' AND depth='standard' AND status='complete'`,[body.upgradeFrom,account])).rows[0];
   if(action!=='guidance'||depth!=='detailed'||!parent||!parent.result_ciphertext||parent.binding_hash!==binding)throw Error('Choose the same Standard answer to upgrade.');
   const parentContext:any=await openReply(this.secret,parent.id,parent.result_ciphertext);
   if(parentContext?.responseMode==='conversation')throw Error('Conversational answers use the standard price and do not support paid upgrades.');
   if((await tx.query(`SELECT id FROM ${this.usageTable} WHERE upgrade_from=$1 AND status IN ('reserved','complete') AND request_id<>$2`,[body.upgradeFrom,requestId])).rows.length)throw Error('This answer already has an upgrade. Reopen its saved Detailed answer.');
   chargedCategory=parent.category;cost=coinCost(parent.category,'detailed')-coinCost(parent.category,'standard');
  }else if(action==='guidance'&&depth==='standard'&&!existing){
   const used=(await tx.query(`SELECT count(*) n FROM ${this.usageTable} WHERE trial=1 AND status IN ('reserved','complete')`)).rows[0].n;
   const own=(await tx.query(`SELECT id FROM ${this.usageTable} WHERE account_id=$1 AND trial=1 AND status IN ('reserved','complete')`,[account])).rows.length;
   if(!own&&Number(used)<100){cost=0;trial=true;}
  }
  const personalReading=action==='guidance'&&request?.headers.get('x-jyotara-wallet-catalog')==='2'&&!body.guide&&body.responseMode===undefined&&!body.upgradeFrom;
  if(personalReading){cost=appConfig().costs.explore;trial=false;}
  let unknownTime=false;
  if(action==='guidance' && request){
   const sessionId=(request.headers.get('cookie')??'').split(';').map(s=>s.trim()).find(s=>s.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
   if(sessionId){
    const chart=await openChartTicket(this.secret,input.chartTicket,sessionId,body.profileId)??await openBirthGuidanceTicket(this.secret,input.chartTicket,sessionId,body.profileId);
    unknownTime=chart?.birthTimeKnown===false;
   }else{
    // Older wallet clients omit the chart cookie. Resolve only the signed
    // ticket's flags, then prove ownership; never trust a client time flag.
    const chart=await openChartQuoteTicket(this.secret,input.chartTicket,body.profileId);
    if(chart?.birthTimeKnown===false){
     const owned=(await tx.query(`SELECT 1 FROM phone_profile_owners o
       WHERE o.session_id=$1 AND o.account_id=$2
       AND NOT EXISTS (SELECT 1 FROM deleted_chart_sessions d WHERE d.session_id=o.session_id AND d.expires_at>$3)
       AND NOT EXISTS (SELECT 1 FROM profile_generations g WHERE g.session_id=o.session_id AND g.status='deleted')`,[chart.sessionId,account,Date.now()])).rows.length;
     unknownTime=owned>0;
    }
   }
  }
  // Only exact server-recognized acknowledgments/preferences are free. The
  // same classifier gates a local response after protected route validation.
  // A batch containing a real question still uses the normal answer price.
  if(safe||unknownTime||localConversationAcknowledgement(body)!==null){cost=0;trial=false;}
  let minute:any=null,intro:any=null;
  if(timed){
   trial=false;
   const minuteBinding=this.hash([body.profileId,body.guide]);
   intro=(await tx.query('SELECT * FROM intro_chat_trials WHERE account_id=$1 AND mode=$2 AND billing_session=$3 FOR UPDATE',[account,this.mode,body.billingSession])).rows[0];
   minute=(await tx.query('SELECT * FROM minute_chat_sessions WHERE account_id=$1 AND mode=$2 AND id=$3 FOR UPDATE',[account,this.mode,body.billingSession])).rows[0];
   if(minute&&((!intro&&minute.binding_hash!==minuteBinding)||minute.ended===1)&&!existing)throw Error('This chat has ended or changed. Reopen the guide.');
   if(minute?.pending_usage&&!existing)throw Error('Your previous question is still being answered. Retry its saved request.');
   cost=safe||unknownTime||localConversationAcknowledgement(body)!==null?0:minute?.window_until>Date.now()?0:minuteRate;
   if(!minute)minute={id:body.billingSession,binding_hash:minuteBinding,window_until:0};
   if(intro){
    if(intro.guide!==body.guide)throw Error('Reopen the guide selected for your free trial.');
    if(!existing&&(intro.state!=='active'||(Number(minute.window_until)>0&&Number(minute.window_until)<=Date.now())))throw new IntroTrialEnded();
    cost=0;trial=true;
    minute.binding_hash=minuteBinding;
   }
  }
  if(existing){cost=Number(existing.cost);trial=existing.trial===1;}
  return {requestId,hash,binding,category:chargedCategory,depth,cost,trial,existing,legacy,upgradeFrom:body.upgradeFrom??null,minute,personalReading,intro};
 }
 async handle(request:Request,tester:string){
  if(!this.enabled())return error('Coin wallet is not available.',503);
  const body:any=await jsonObject(request);if(!body)return error('Invalid request.');
  const account=await this.gateway.account(this.db.pool,request,tester);if(!account)return error('Sign in again.',401);
  const action=new URL(request.url).pathname.split('/').pop();
  if(action==='intro-trial'){
   if(request.headers.get('x-jyotara-wallet-catalog')!=='2')return error('Update the app to use the free chat trial.');
   if(!['status','offer','start','skip','finish'].includes(body.operation))return error('Choose a valid trial action.');
   return this.db.transaction(async tx=>{
    await tx.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))',[this.mode+':intro-trial:'+account]);
    let state:any=await this.introTrial(tx,account);
    if(body.operation==='status')return Response.json(state);
    if(state.state==='available'){
     await tx.query("INSERT INTO intro_chat_trials(account_id,mode,state,created_at,updated_at) VALUES($1,$2,'offered',$3,$3) ON CONFLICT DO NOTHING",[account,this.mode,Date.now()]);
     state=await this.introTrial(tx,account);
    }
    if(body.operation==='start'){
     if(state.state==='active')return Response.json(state);
     if(state.state!=='offered')return error('This account has already used or skipped its introductory trial.');
     if(!/^[a-f0-9]{32}$/.test(body.billingSession??'')||!['Meera','Nila','Janaki','Harini','Aravind','Kavya','Adithya','Raghavan','Revathi','Karthik'].includes(body.guide)||!appConfig().features.chat||appConfig().maintenance||appConfig().disabledGuides.includes(body.guide))return error('Choose an available guide.');
     // An existing paid window cannot be relabelled as a free trial.
     if((await tx.query('SELECT 1 FROM minute_chat_sessions WHERE account_id=$1 AND mode=$2 AND id=$3',[account,this.mode,body.billingSession])).rows.length)return error('Start a new introductory chat.');
     await tx.query("UPDATE intro_chat_trials SET state='active',billing_session=$1,guide=$2,updated_at=$3 WHERE account_id=$4 AND mode=$5 AND state='offered'",[body.billingSession,body.guide,Date.now(),account,this.mode]);
    }else if(body.operation==='skip'&&state.state==='offered'){
     await tx.query("UPDATE intro_chat_trials SET state='skipped',updated_at=$1 WHERE account_id=$2 AND mode=$3",[Date.now(),account,this.mode]);
    }else if(body.operation==='finish'&&['active','ended'].includes(state.state)){
     if(body.billingSession!==state.billingSession)return error('This trial belongs to another chat.',409);
     if(state.pending)return error('Your answer is still being prepared. It will finish before the trial closes.',409);
     await tx.query("UPDATE intro_chat_trials SET state='ended',updated_at=$1 WHERE account_id=$2 AND mode=$3",[Date.now(),account,this.mode]);
     await tx.query('UPDATE minute_chat_sessions SET ended=1,updated_at=$1 WHERE account_id=$2 AND mode=$3 AND id=$4',[Date.now(),account,this.mode,state.billingSession]);
    }
    return Response.json(await this.introTrial(tx,account));
   });
  }
  if(action==='status')return this.db.transaction(async tx=>Response.json({mode:this.mode,balance:await this.balance(tx,account),billing:{version:2,coinsPerMinute:minuteRate,policy:'question_started_minute'},packs:this.catalog(request).filter(p=>!appConfig().disabledPacks.includes(p.id)),
   orders:(await tx.query(`SELECT id,pack_id,amount,coins,CASE WHEN payment_method='review_grant' THEN 'complimentary' ELSE status END AS status,payment_method,refund_review,created_at,updated_at FROM ${this.ordersTable} WHERE account_id=$1 ORDER BY created_at DESC LIMIT 30`,[account])).rows,
   activity:(await tx.query(`SELECT id,action,category,depth,cost,status,trial,created_at FROM ${this.usageTable} WHERE account_id=$1 ORDER BY created_at DESC LIMIT 30`,[account])).rows}));
  if(action==='quote'){
   try{return await this.db.transaction(async tx=>{
    const p=await this.price(tx,account,String(body.action),body.payload,request),balance=await this.balance(tx,account);
    const data={account,hash:p.hash,requestId:p.requestId,cost:p.cost,trial:p.trial,expires:Date.now()+300000};
    const encoded=Buffer.from(JSON.stringify(data)).toString('base64url');
    const quote=encoded+'.'+createHmac('sha256',this.secret).update(encoded).digest('hex');
    const already=!!p.existing && !(body.action==='matching'&&p.existing.status==='failed');
    return Response.json({quote,category:p.category,depth:p.depth,cost:already?0:p.cost,originalCost:p.cost,balance,trial:p.trial,reopening:already,status:p.existing?.status??'new',canProceed:already||balance>=p.cost,mode:this.mode,...(p.minute?{billingVersion:2,coinsPerMinute:minuteRate}: {}),...(p.intro?{introTrial:await this.introTrial(tx,account)}:{})});
   });}catch(e){return walletError(e);}
  }
  if(action==='end-chat'){
   if(!/^[a-f0-9]{32}$/.test(body.billingSession??''))return error('Invalid chat.');
   await this.db.pool.query('UPDATE minute_chat_sessions SET ended=1,updated_at=$1 WHERE account_id=$2 AND mode=$3 AND id=$4',[Date.now(),account,this.mode,body.billingSession]);
   return Response.json({ended:true,balance:await this.balance(this.db.pool,account)});
  }
  if(action==='create')return this.create(request,tester,body,account);
  if(action==='verify'||action==='refresh'){
   const row=(await this.db.pool.query(`SELECT * FROM ${this.ordersTable} WHERE id=$1 AND account_id=$2`,[body.id,account])).rows[0];
   if(!row)return error('Order not found.',404);
   if(row.payment_method==='review_grant')return Response.json({mode:this.mode,balance:await this.balance(this.db.pool,account),status:'complimentary'});
   if(!row.provider_order&&!row.provider_qr)return error('Order not found.',404);
   if(row.provider_qr){
    if(action!=='refresh')return error('Refresh QR payment instead.',422);
    try{
     const list=await this.gateway.provider('payments/qr_codes/'+row.provider_qr+'/payments');
     for(const item of list.items??[])await this.recordQrPayment(await this.gateway.provider('payments/'+item.id),row.provider_qr);
     if(Number(row.qr_expires)*1000<=Date.now())await this.db.pool.query(`UPDATE ${this.ordersTable} SET status='expired' WHERE id=$1 AND status='created'`,[row.id]);
     const current=(await this.db.pool.query(`SELECT status FROM ${this.ordersTable} WHERE id=$1`,[row.id])).rows[0];
     return Response.json({mode:this.mode,balance:await this.balance(this.db.pool,account),status:current?.status,expired:Number(row.qr_expires)*1000<=Date.now()});
    }catch{return error('Confirmation pending. Do not pay again; retry checking payment.',503);}
   }
   try{
    let p:any;
    if(action==='verify'){
     if(typeof body.paymentId!=='string'||!/^pay_[A-Za-z0-9]+$/.test(body.paymentId)||!validSignature(this.keySecret!,row.provider_order+'|'+body.paymentId,body.signature))return error('Payment verification failed.',400);
     p=await this.gateway.provider('payments/'+body.paymentId);
    }else{
     const r=await this.gateway.provider('orders/'+row.provider_order+'/payments');
     p=r.items?.find((v:any)=>v.status==='captured'||v.status==='refunded')??r.items?.find((v:any)=>v.status==='authorized')??r.items?.find((v:any)=>v.status==='failed');
    }
    if(p)await this.recordPayment(p);
    return Response.json({mode:this.mode,balance:await this.balance(this.db.pool,account)});
   }catch{return error('Payment confirmation is pending. Refresh this order; do not pay again.',503);}
  }
  return error('Unknown wallet action.',404);
 }
 async create(request:Request,tester:string,body:any,account:string){
  const method=body.paymentMethod??'checkout';if(!['checkout','qr'].includes(method))return error('Choose a payment method.');
  const previous=(await this.db.pool.query(`SELECT pack_id FROM ${this.ordersTable} WHERE account_id=$1 AND request_id=$2`,[account,body.requestId??''])).rows[0];
  const pack=(previous?[...coinPacks,...minuteCoinPacks]:this.catalog(request)).find(p=>p.id===body.packId);if(!pack||typeof body.requestId!=='string'||!rid.test(body.requestId))return error('Choose a pack.');
  const reserved=await this.db.transaction(async tx=>{
   const old=(await tx.query(`SELECT * FROM ${this.ordersTable} WHERE account_id=$1 AND request_id=$2`,[account,body.requestId])).rows[0];
   if(old)return {row:old,fresh:false};
   if(Number((await tx.query(`SELECT count(*) n FROM ${this.ordersTable} WHERE account_id=$1 AND created_at>$2`,[account,Date.now()-86400000])).rows[0].n)>=20)return null;
   const row=(await tx.query(`INSERT INTO ${this.ordersTable}(id,account_id,request_id,pack_id,amount,coins,created_at,updated_at,payment_method) VALUES($1,$2,$3,$4,$5,$6,$7,$7,$8) RETURNING *`,[randomUUID(),account,body.requestId,pack.id,pack.rupees*100,pack.coins,Date.now(),method])).rows[0];return {row,fresh:true};
  });
  if(!reserved)return error('Purchase limit reached.',429);
  let row=reserved.row;if(row.pack_id!==pack.id||row.payment_method!==method)return error('This purchase already belongs to another pack.',409);
  if(method==='qr'){
   if(reserved.fresh){
    try{
     const expires=Math.floor(Date.now()/1000)+900;
     const q=await this.gateway.provider('payments/qr_codes',{type:'upi_qr',name:'Jyotara',usage:'single_use',fixed_amount:true,payment_amount:Number(row.amount),description:row.coins+' Jyotara coins',close_by:expires,notes:{wallet_purchase:row.id}});
     const u=new URL(q.image_url);
     if(!/^qr_[A-Za-z0-9]+$/.test(q.id)||q.type!=='upi_qr'||q.usage!=='single_use'||q.fixed_amount!==true||q.payment_amount!==Number(row.amount)||q.status!=='active'||u.protocol!=='https:'||!['rzp.io','rzp.in'].includes(u.hostname)||!Number.isFinite(q.close_by)||q.close_by>expires||q.close_by<=Date.now()/1000)throw Error('QR mismatch');
     row=(await this.db.pool.query(`UPDATE ${this.ordersTable} SET provider_qr=$1,qr_image=$2,qr_expires=$3,status='created',updated_at=$4 WHERE id=$5 RETURNING *`,[q.id,q.image_url,q.close_by,Date.now(),row.id])).rows[0];
    }catch{await this.db.pool.query(`UPDATE ${this.ordersTable} SET status='unconfirmed' WHERE id=$1 AND provider_qr IS NULL`,[row.id]);return error('QR creation could not be confirmed. No payment was started. Contact support before trying again.',503);}
   }
   if(row.status!=='created'||!row.provider_qr)return error('Refresh this purchase before paying again.',409);
   return Response.json({id:row.id,qrId:row.provider_qr,imageUrl:row.qr_image,expiresAt:Number(row.qr_expires)*1000,amount:Number(row.amount),coins:Number(row.coins),currency:'INR',mode:this.mode,paymentMethod:'qr'});
  }
  if(reserved.fresh){
   try{
    const p=await this.gateway.provider('orders',{amount:row.amount,currency:'INR',receipt:row.id,partial_payment:false});
    if(!/^order_[A-Za-z0-9]+$/.test(p.id)||p.amount!==row.amount||p.currency!=='INR'||p.receipt!==row.id)throw Error('Order mismatch');
    row=(await this.db.pool.query(`UPDATE ${this.ordersTable} SET provider_order=$1,status='created',updated_at=$2 WHERE id=$3 RETURNING *`,[p.id,Date.now(),row.id])).rows[0];
   }catch{
    await this.db.pool.query(`UPDATE ${this.ordersTable} SET status='unconfirmed' WHERE id=$1 AND provider_order IS NULL`,[row.id]);return error('Order creation is unconfirmed. Contact support before starting another purchase.',503);
   }
  }
  if(!row||row.status!=='created'||!row.provider_order)return error('This order is already processed or awaiting confirmation. Refresh your wallet.',409);
  return Response.json({id:row.id,orderId:row.provider_order,amount:row.amount,coins:row.coins,currency:'INR',keyId:this.keyId,mode:this.mode,checkoutUrl:this.checkoutUrl(row.id)});
 }
 checkoutUrl(id:string){
  const data=Buffer.from(JSON.stringify({id,mode:this.mode,expires:Date.now()+3600000})).toString('base64url');
  return 'https://api.jyotara.in/api/wallet-checkout/'+this.mode+'/'+data+'.'+createHmac('sha256',this.secret).update('checkout:'+data).digest('hex');
 }
 async checkout(request:Request,token:string){
  if(!this.enabled())return error('Checkout unavailable.',503);
  const [data,sig,...rest]=token.split('.');
  if(rest.length||!data||!validSignature(this.secret,'checkout:'+data,sig))return error('Invalid checkout link.',403);
  let claim:any;try{claim=JSON.parse(Buffer.from(data,'base64url').toString());}catch{return error('Invalid checkout link.',403);}
  if(claim.mode!==this.mode||typeof claim.id!=='string'||!Number.isFinite(claim.expires)||claim.expires<Date.now())return error('Checkout link expired. Reopen your package in Jyotara.',403);
  const row=(await this.db.pool.query(`SELECT * FROM ${this.ordersTable} WHERE id=$1`,[claim.id])).rows[0];
  if(!row?.provider_order)return error('Order unavailable.',404);
  if(request.method==='GET')return walletCheckoutPage(row,this.keyId!);
  if(request.method!=='POST')return error('Method not allowed.',405);
  const body:any=await jsonObject(request);if(!body)return error('Invalid request.');
  try{
   if(body.paymentId){
    if(typeof body.paymentId!=='string'||!/^pay_[A-Za-z0-9]+$/.test(body.paymentId)||!validSignature(this.keySecret!,row.provider_order+'|'+body.paymentId,body.signature))return error('Payment verification failed.',400);
    await this.recordPayment(await this.gateway.provider('payments/'+body.paymentId));
   }else if(!['paid','refunded'].includes(row.status)){
    const result=await this.gateway.provider('orders/'+row.provider_order+'/payments');
    const payment=result.items?.find((v:any)=>['captured','refunded'].includes(v.status));
    if(payment)await this.recordPayment(await this.gateway.provider('payments/'+payment.id));
   }
   const current=(await this.db.pool.query(`SELECT status FROM ${this.ordersTable} WHERE id=$1`,[row.id])).rows[0];
   return Response.json({status:current.status});
  }catch{return error('Payment confirmation pending. Do not pay again.',503);}
 }
 async recordQrPayment(p:any,qr:string){
  if(!/^qr_[A-Za-z0-9]+$/.test(qr))throw Error('Invalid QR');
  const row=(await this.db.pool.query(`SELECT id FROM ${this.ordersTable} WHERE provider_qr=$1`,[qr])).rows[0];if(!row)return;
  const list=await this.gateway.provider('payments/qr_codes/'+qr+'/payments');
  if(!list.items?.some((item:any)=>item.id===p.id))throw Error('Payment does not belong to QR');
  const state=paymentState(p,p.order_id,Number((await this.db.pool.query(`SELECT amount FROM ${this.ordersTable} WHERE id=$1`,[row.id])).rows[0].amount));
  if(!['paid','refunded'].includes(state))return;
  await this.recordPayment(p,qr);
 }
 async recordPayment(p:any,qr?:string){
  return this.db.transaction(async tx=>{
   const row=(await tx.query(`SELECT * FROM ${this.ordersTable} WHERE (provider_order=$1 AND provider_order IS NOT NULL) OR (provider_qr=$2 AND provider_qr IS NOT NULL) OR (payment_method='qr' AND provider_payment=$3) FOR UPDATE`,[p.order_id??null,qr??null,p.id])).rows[0];if(!row)return;
   const state=paymentState(p,row.payment_method==='qr'?p.order_id:row.provider_order,Number(row.amount));
   if(row.provider_payment&&row.provider_payment!==p.id&&['paid','refunded'].includes(row.status))throw Error('Different capture');
   if(row.status==='refunded'||(row.status==='paid'&&state!=='refunded'))return;
   if(state==='refunded'){
    // Remove only this purchase's unused coins. Spent or partial refunds need review;
    // never take coins from an unrelated purchase or make the wallet negative.
    const review=Number(p.amount_refunded)!==Number(row.amount)||Number(row.remaining)<Number(row.coins);
    await tx.query(`UPDATE ${this.ordersTable} SET status='refunded',remaining=0,provider_payment=$1,refund_review=$2,updated_at=$3 WHERE id=$4`,[p.id,review?1:0,Date.now(),row.id]);
   }else if(state==='paid')await tx.query(`UPDATE ${this.ordersTable} SET status='paid',remaining=coins,provider_payment=$1,updated_at=$2 WHERE id=$3`,[p.id,Date.now(),row.id]);
   else await tx.query(`UPDATE ${this.ordersTable} SET status=$1,updated_at=$2 WHERE id=$3`,[state,Date.now(),row.id]);
  });
 }
 async run(request:Request,account:string,action:string,handler:(r:Request)=>Promise<Response>){
  if(!this.enabled())return this.mode==='live'?error('Live wallet is unavailable.',503):handler(request);
  const body=await jsonObject(request.clone() as Request);if(!body)return error('Invalid request.');
  if(action==='matching'&&(body.consent!==true||!validBirth(body.boy)||!validBirth(body.girl)))return error('Confirm permission and valid birth details for both people.',400);
  if(action==='guidance'&&body.question===profileOverviewQuestion)return handler(request);
  let p:any;
  try{
   p=await this.db.transaction(async tx=>{
    const price=await this.price(tx,account,action,body,request);
    const [encoded,signature,...rest]=String(body.coinQuote??'').split('.');
    if(rest.length||!encoded||!validSignature(this.secret,encoded,signature))throw Error('Confirm the coin price before continuing.');
    const q=JSON.parse(Buffer.from(encoded,'base64url').toString());
    if(q.account!==account||q.hash!==price.hash||q.requestId!==price.requestId||q.cost!==price.cost||q.trial!==price.trial||q.expires<Date.now())throw Error('The coin quote changed or expired. Please confirm again.');
    if(price.legacy){
     // Preserve the original encrypted receipt and purchase; only its lookup key changes.
     price.existing=(await tx.query(`UPDATE ${this.usageTable} SET request_id=$1,payload_hash=$2 WHERE id=$3 AND account_id=$4 RETURNING *`,[price.requestId,price.hash,price.existing.id,account])).rows[0];
    }
    if(price.existing && !(action==='matching'&&price.existing.status==='failed'))return {...price,row:price.existing,fresh:false};
    if(price.existing)await tx.query(`UPDATE ${this.usageTable} SET request_id=$1 WHERE id=$2`,[price.requestId+'-'+randomUUID(),price.existing.id]);
    if(await this.balance(tx,account)<price.cost)throw Error('Not enough coins. Open Coin wallet to choose a pack.');
    let needed=price.cost;const allocations:{id:string;coins:number}[]=[];
    const lots=(await tx.query(`SELECT id,remaining FROM ${this.ordersTable} WHERE account_id=$1 AND status='paid' AND remaining>0 ORDER BY created_at,id FOR UPDATE`,[account])).rows;
    for(const lot of lots){const coins=Math.min(needed,Number(lot.remaining));if(!coins)break;allocations.push({id:lot.id,coins});needed-=coins;await tx.query(`UPDATE ${this.ordersTable} SET remaining=remaining-$1 WHERE id=$2`,[coins,lot.id]);}
    // Set the verified minute session at insertion, before the legacy one-free-
    // answer unique index runs. Updating it later rejects trial follow-ups.
    const row=(await tx.query(`INSERT INTO ${this.usageTable}(id,account_id,request_id,payload_hash,action,category,depth,cost,trial,upgrade_from,binding_hash,allocations,billing_session,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$14) RETURNING *`,[randomUUID(),account,price.requestId,price.hash,action,price.category,price.depth,price.cost,price.trial?1:0,price.upgradeFrom,price.binding,JSON.stringify(allocations),price.minute?body.billingSession:null,Date.now()])).rows[0];
    if(price.minute){
     await tx.query('INSERT INTO minute_chat_sessions(account_id,mode,id,binding_hash,created_at,updated_at) VALUES($1,$2,$3,$4,$5,$5) ON CONFLICT DO NOTHING',[account,this.mode,body.billingSession,price.minute.binding_hash,Date.now()]);
     await tx.query('UPDATE minute_chat_sessions SET pending_usage=$1,updated_at=$2,binding_hash=$6 WHERE account_id=$3 AND mode=$4 AND id=$5',[row.id,Date.now(),account,this.mode,body.billingSession,price.minute.binding_hash]);
    }
    if(action==='guidance')await tx.query(`UPDATE ${this.usageTable} SET session_id=$1 WHERE id=$2`,[/nirayana_pilot_session=([A-Za-z0-9_-]+)/.exec(request.headers.get('cookie')??'')?.[1]??null,row.id]);
    return {...price,row,fresh:true};
   });
  }catch(e){return walletError(e,409);}
  await recordWalletOutcome({id:p.row.id,status:p.row.status,coins:p.row.status==='complete'?Number(p.row.cost):0});
  // Saved matching results are account-bound and encrypted. Guidance recovery
  // goes through the original handler so deleted/expired profiles stay deleted.
  if(action==='matching'&&p.row.status==='complete'&&p.row.result_ciphertext){
   const result:any=await openReply(this.secret,p.row.id,p.row.result_ciphertext);
   try{return Response.json({...await matchingLanguage(result,body.language),replayed:true,wallet:this.receipt(p.row)});}
   catch{return error('Your saved comparison is safe. The selected language is unavailable right now; retry without paying again.',503);}
  }
  if(action==='matching'&&!p.fresh)return error('This comparison is pending or previously failed. Contact support; it will not be charged again.',409);
  // A confirmed, refunded minute attempt cannot later turn into an unbilled
  // provider answer. New questions get a new reservation and saved request ID.
  if((p.minute||p.personalReading)&&!p.fresh&&p.row.status==='failed')return error('This attempt was not charged. Send a new question.',422);
  let outgoing=request;let earlyResponse:Response|undefined;
  if(action==='matching')outgoing=new Request(request.url,{method:'POST',headers:request.headers,body:JSON.stringify({...this.clean(action,body),language:'en'})});
  if(action==='guidance'&&p.upgradeFrom){
   const parent=(await this.db.pool.query(`SELECT result_ciphertext FROM ${this.usageTable} WHERE id=$1 AND account_id=$2`,[p.upgradeFrom,account])).rows[0];
   if(!parent?.result_ciphertext)earlyResponse=error('The original reading context is no longer available.',410);
   else {
    const context:any=await openReply(this.secret,p.upgradeFrom,parent.result_ciphertext);
    outgoing=new Request(request.url,{method:'POST',headers:request.headers,body:JSON.stringify({...body,...context})});
   }
  }
  const response=earlyResponse??await handler(outgoing);const result:any=await response.clone().json().catch(()=>null);
  if((action==='guidance'&&response.status>=500)||response.status===409)return response; // Keep uncertain reservations for safe recovery.
  let success=response.ok&&(action==='matching'?Number.isFinite(result?.score):(result?.answerMode==='provider_reading'||(result?.answerMode==='limited_guidance'&&Number(p.cost)===0)));
  const row=await this.db.transaction(async tx=>{
   const current=(await tx.query(`SELECT * FROM ${this.usageTable} WHERE id=$1 FOR UPDATE`,[p.row.id])).rows[0];if(!current)return null;
   if(current.session_id&&(await tx.query('SELECT 1 FROM deleted_chart_sessions WHERE session_id=$1 AND expires_at>$2',[current.session_id,Date.now()])).rows.length)success=false;
   if(current.status==='reserved'){
    if(!success)for(const lot of JSON.parse(current.allocations))await tx.query(`UPDATE ${this.ordersTable} SET remaining=remaining+$1 WHERE id=$2 AND status='paid'`,[lot.coins,lot.id]);
    const context={category:body.category,conversationHistory:body.conversationHistory??[],previousUserMessages:body.previousUserMessages??[],...(body.responseMode!==undefined?{responseMode:body.responseMode}:{}),...(body.conversationMemory!==undefined?{conversationMemory:body.conversationMemory}:{})};
    const cipher=success?await sealReply(this.secret,current.id,action==='matching'?result:context):null;
    if(current.billing_session){
     // Server time, one charge per paid window. Provider latency does not consume
     // the window; no debit runs merely because time passed or the app closed.
     const minute=(await tx.query('SELECT * FROM minute_chat_sessions WHERE account_id=$1 AND mode=$2 AND id=$3 FOR UPDATE',[account,this.mode,current.billing_session])).rows[0];
     if(minute?.pending_usage===current.id){
      const trialReply=p.intro&&localConversationAcknowledgement(body)===null;
      const until=success&&((Number(current.cost)===minuteRate)||(trialReply&&Number(minute.window_until)===0))?Date.now()+60000:(success||p.intro)&&minute.window_until>Number(current.created_at)?Number(minute.window_until)+Math.max(0,Date.now()-Number(current.created_at)):Number(minute?.window_until??0);
      await tx.query('UPDATE minute_chat_sessions SET pending_usage=NULL,window_until=$1,updated_at=$2 WHERE account_id=$3 AND mode=$4 AND id=$5',[until,Date.now(),account,this.mode,current.billing_session]);
     }
    }
    return (await tx.query(`UPDATE ${this.usageTable} SET status=$1,result_ciphertext=$2,updated_at=$3 WHERE id=$4 RETURNING *`,[success?'complete':'failed',cipher,Date.now(),current.id])).rows[0];
   }return current;
  });
  if(!row)return error('Account no longer exists.',410);
  if(!response.ok)return response;
  if(action==='matching'){
   try{return Response.json({...await matchingLanguage(result,body.language),wallet:this.receipt(row)});}
   catch{return error('Your comparison was saved. The selected language is unavailable right now; retry without paying again.',503);}
  }
  return Response.json({...result,wallet:{...this.receipt(row),...(body.responseMode==='conversation'?{canUpgrade:false}:{}),...(p.minute?{billingVersion:2,coinsPerMinute:minuteRate}:{}),...(p.intro?{introTrial:await this.introTrial(this.db.pool,account)}:{}),...(result?.answerMode==='limited_guidance'?{canUpgrade:false,freeReason:'general_guidance'}:{}),question:body.question,style:body.responseStyle}},{status:response.status,headers:response.headers});
 }
 receipt(row:any){return {id:row.id,trial:row.status==='complete'&&row.trial===1,coins:row.status==='complete'?Number(row.cost):0,category:row.category,depth:row.depth,status:row.status,canUpgrade:appConfig().features.detailed&&row.status==='complete'&&row.action==='guidance'&&row.depth==='standard',upgradeCost:coinCost(row.category,'detailed')-coinCost(row.category,'standard'),mode:this.mode};}
}
