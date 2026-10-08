import {userJourney} from './user-journey';
import {accountProfileBackup} from './account-profile-backup';
import {appConfig,blockedRequest} from './app-config';
import {LivePayments} from './live-payments';
import {CoinWallet} from './coin-wallet';
import {TestPayments} from './test-payments';
import {supportTickets} from './support-tickets';
import {cleanDivineSessions} from './divine-cleanup';
import { PhoneAuth } from './phone-auth';
import { reportAnswer } from './answer-reports';
import {publicPage} from './public-pages';
import { discardPending } from './discard-pending';
import { daily, matching } from './discovery';
import { panchang } from './explore';
import { createServer } from 'node:http';
import { database } from './env';
import { testerIdentity, officeTesterIdentity, admitTesterRequest } from './tester-access';
import { POST as kundli } from '../app/api/astrology/kundli/route';
import { POST as guidance } from '../app/api/guidance/route';
import { POST as locations } from '../app/api/locations/route';
import { POST as events, DELETE as eraseEvents } from '../app/api/pilot/events/route';
import { POST as renew } from '../app/api/profile/renew/route';
import { POST as deleteProfile } from '../app/api/profile/delete/route';

const routes: Record<string, (request: Request) => Promise<Response>> = {
  'POST /api/astrology/kundli': kundli,
  'POST /api/horoscope/daily': daily,
  'POST /api/explore/panchang': panchang,
  'POST /api/kundli/matching': matching,
  'POST /api/guidance': guidance,
  'POST /api/locations': locations,
  'POST /api/pilot/events': events,
  'DELETE /api/pilot/events': eraseEvents,
  'POST /api/profile/renew': renew,
  'POST /api/profile/delete': deleteProfile,
  'POST /api/profile/discard': discardPending,
};
const publicAccess=process.env.JYOTARA_PUBLIC_ACCESS==='true';
if (!publicAccess && (!process.env.JYOTARA_TESTER_CODES_SHA256 || !process.env.JYOTARA_TESTER_EXPIRES_AT)) {
  throw new Error('Tester access configuration is required');
}
const phoneAuth = new PhoneAuth(database, process.env);
const testPayments = new TestPayments(database, process.env);
const testCoinWallet = new CoinWallet(database,process.env,testPayments);
const livePayments = new LivePayments(database,process.env);
const liveCoinWallet = new CoinWallet(database,process.env,livePayments,'live');
if(publicAccess && !phoneAuth.configured())throw new Error('Public access requires configured phone authentication');
const authPaths = new Set(['/api/auth/config', '/api/auth/reviewer', '/api/auth/reviewer-delete', '/api/auth/send', '/api/auth/verify', '/api/auth/verify-deletion', '/api/auth/session', '/api/auth/logout', '/api/auth/delete-account']);
export const server = createServer(async (incoming, outgoing) => {
  outgoing.setHeader('X-Content-Type-Options', 'nosniff');
  outgoing.setHeader('Cache-Control', 'no-store');
  try {
    const path = new URL(incoming.url ?? '/', 'http://localhost').pathname;
    if(incoming.method==='GET' && path==='/api/app-config'){outgoing.writeHead(200,{'Content-Type':'application/json'});outgoing.end(JSON.stringify(appConfig()));return;}
    const page=incoming.method==='GET'?publicPage(path):null;
    if(page) {
      outgoing.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'",'Referrer-Policy':'no-referrer'});
      outgoing.end(page);return;
    }
    if (incoming.method === 'GET' && path === '/healthz') {
      await database.pool.query('SELECT session_id FROM tester_sessions LIMIT 0');
      outgoing.writeHead(200, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ status: 'ok', service: 'jyotara-api' }));
      return;
    }
    if(incoming.method==='POST' && ['/api/payments/test/webhook','/api/payments/live/webhook'].includes(path)) {
      const chunks:Buffer[]=[];let size=0;
      for await(const chunk of incoming){size+=chunk.length;if(size>256000){outgoing.writeHead(413);outgoing.end();return;}chunks.push(chunk);}
      const live=path==='/api/payments/live/webhook';
      const response=await (live?livePayments:testPayments).webhook(new Request('http://localhost'+path,{method:'POST',headers:{'x-razorpay-signature':String(incoming.headers['x-razorpay-signature']??'')},body:Buffer.concat(chunks)}),(p,qr?:string)=>qr&&live?liveCoinWallet.recordQrPayment(p,qr):(live?liveCoinWallet:testCoinWallet).recordPayment(p));
      outgoing.writeHead(response.status,{'Content-Type':'application/json'});outgoing.end(await response.text());return;
    }
    const checkoutMatch=/^\/api\/wallet-checkout\/(live|test)\/([A-Za-z0-9_.-]{1,1024})$/.exec(path);
    if(checkoutMatch){
      const chunks:Buffer[]=[];let size=0;
      for await(const chunk of incoming){size+=chunk.length;if(size>4096){outgoing.writeHead(413);outgoing.end();return;}chunks.push(chunk);}
      const method=incoming.method??'GET';
      const request=new Request('https://api.jyotara.in'+path,{method,headers:{'content-type':'application/json'},...(['GET','HEAD'].includes(method)?{}:{body:Buffer.concat(chunks)})});
      const response=await (checkoutMatch[1]==='live'?liveCoinWallet:testCoinWallet).checkout(request,checkoutMatch[2]);
      outgoing.writeHead(response.status,Object.fromEntries(response.headers.entries()));outgoing.end(await response.text());return;
    }
    const testerCode=typeof incoming.headers['x-jyotara-tester-code']==='string' ? incoming.headers['x-jyotara-tester-code'] : undefined;
    const publicRequest=publicAccess && !testerCode;
    const samsungTester = officeTesterIdentity(testerCode, process.env, path);
    const tester = publicRequest ? 'public-v1' : samsungTester ?? testerIdentity(
      testerCode,process.env.JYOTARA_TESTER_CODES_SHA256 ?? '', process.env.JYOTARA_TESTER_EXPIRES_AT ?? '', path);
    if (!tester) {
      outgoing.writeHead(401, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ error: 'Enter a valid tester access code. It may have expired.', code: 'tester_access_required' }));
      return;
    }
    if (!publicRequest && incoming.method === 'POST' && path === '/api/tester/check') {
      outgoing.writeHead(200, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ access: 'granted', expiresAt: samsungTester ? process.env.JYOTARA_SAMSUNG_TESTER_EXPIRES_AT : process.env.JYOTARA_TESTER_EXPIRES_AT }));
      return;
    }
    const isJourney = incoming.method === 'POST' && path === '/api/user-journey';
    const liveWalletRequested=publicRequest || incoming.headers['x-jyotara-wallet-mode']==='live';
    let coinWallet=liveWalletRequested?liveCoinWallet:testCoinWallet;
    // Public installations use the same phone-authenticated live wallet; legacy office builds remain supported.
    if(!isJourney && liveWalletRequested && ((!samsungTester && !publicRequest) || !liveCoinWallet.enabled())){outgoing.writeHead(503,{'Content-Type':'application/json'});outgoing.end(JSON.stringify({error:'Live payments are not available for this installation.'}));return;}
    const isAuth = incoming.method === 'POST' && authPaths.has(path);
    const isBackup = incoming.method === 'POST' && path === '/api/account/profile';
    const isReport = incoming.method === 'POST' && path === '/api/answers/report';
    const isPayment=incoming.method==='POST' && ['/api/payments/test/create','/api/payments/test/verify','/api/payments/test/refresh','/api/payments/test/history'].includes(path);
    const isWallet=incoming.method==='POST' && ['/api/wallet/status','/api/wallet/quote','/api/wallet/create','/api/wallet/verify','/api/wallet/refresh'].includes(path);
    const isSupport=incoming.method==='POST' && ['/api/support/create','/api/support/list'].includes(path);
    if((isPayment&&!samsungTester)||((isWallet||isSupport||path==='/api/explore/panchang')&&!samsungTester&&!publicRequest)){outgoing.writeHead(404);outgoing.end();return;}
    const handler = isJourney ? (request:Request)=>userJourney(request,database,tester) : isBackup ? (request:Request)=>accountProfileBackup(request,database,process.env.JYOTARA_CHART_TICKET_KEY ?? process.env.NIRAYANA_CHART_TICKET_KEY,tester) : isWallet ? (request:Request)=>coinWallet.handle(request,tester) : isPayment ? (request:Request)=>testPayments.handle(request,tester) : isSupport ? (request:Request)=>supportTickets(request,database,tester,process.env.JYOTARA_CHART_TICKET_KEY ?? process.env.NIRAYANA_CHART_TICKET_KEY) : isReport ? (request:Request) => reportAnswer(request,database,process.env.JYOTARA_CHART_TICKET_KEY ?? process.env.NIRAYANA_CHART_TICKET_KEY,tester) : isAuth ? (request: Request) => phoneAuth.handle(request, tester) : routes[`${incoming.method} ${path}`];
    if (!handler) { outgoing.writeHead(404); outgoing.end(); return; }
    // Authenticate before creating ownership or consuming paid-request budgets.
    const probe=new Request('http://localhost'+path,{headers:typeof incoming.headers.authorization==='string'?{authorization:incoming.headers.authorization}:{}});
    const account=!isAuth ? await phoneAuth.account(probe,tester) : null;
    // Shared demo OTP identities can never operate a live-money wallet.
    if(account?.startsWith('office_demo_'))coinWallet=testCoinWallet;
    const requiresPhone=isJourney || !!samsungTester || isWallet || isPayment || isSupport || publicRequest || typeof incoming.headers.authorization==='string' || incoming.headers['x-jyotara-phone-auth']==='required';
    if(!isAuth && requiresPhone && !account) {
      outgoing.writeHead(401,{'Content-Type':'application/json'});
      outgoing.end(JSON.stringify({error:'Phone sign-in expired. Please sign in again.',code:'phone_auth_required'}));
      return;
    }
    if(!isAuth && !isJourney && !isBackup && !isReport && !isWallet && !isPayment && !isSupport && phoneAuth.configured() && !await phoneAuth.ownProfile(incoming.headers.cookie ?? '',account,!!account)) {
      outgoing.writeHead(403,{'Content-Type':'application/json'});
      outgoing.end(JSON.stringify({error:'Sign in with the phone account that owns this profile.',code:'phone_auth_required'}));
      return;
    }
    // Block paid chat before admission, provider calls or answer recovery.
    if (publicRequest && incoming.method === 'POST' && path === '/api/guidance'
        && process.env.JYOTARA_PUBLIC_CHAT_ENABLED !== 'true') {
      outgoing.writeHead(403, {'Content-Type': 'application/json'});
      outgoing.end(JSON.stringify({code:'chat_not_available',error:'AI chat is temporarily unavailable while we prepare paid access. Free horoscopes, Kundli and matching remain available.'}));
      return;
    }
    // Authenticated wallet matching is metered by its verified coin quote and
    // transactional wallet, not the legacy shared five-per-day trial counter.
    // Never grant this exemption from a client header alone.
    const walletMeteredMatching = !!((samsungTester || publicRequest) && account && incoming.method === 'POST'
      && path === '/api/kundli/matching' && coinWallet.enabled());
    const admission = isAuth || isJourney || isBackup || isReport || isWallet || isPayment || isSupport ? 200 : await admitTesterRequest(database, tester, path, incoming.headers.cookie ?? '',Date.now(),(publicRequest || path === '/api/horoscope/daily' || path === '/api/explore/panchang') ? account ?? undefined : undefined,walletMeteredMatching);
    if (admission !== 200) {
      outgoing.writeHead(admission, { 'Content-Type': 'application/json' });
      outgoing.end(JSON.stringify({ error: admission === 429
        ? 'The daily calculation limit has been reached. Please try again tomorrow. No calculation or answer was requested.'
        : 'This profile does not belong to the current tester session.' }));
      return;
    }
    const chunks: Buffer[] = []; let length = 0;
    for await (const chunk of incoming) {
      length += chunk.length;
      if (length > (['/api/guidance','/api/wallet/quote'].includes(path) ? 640_000 : 256_000)) { outgoing.writeHead(413); outgoing.end(); return; }
      chunks.push(chunk);
    }
    const headers = new Headers();
    for (const [key, value] of Object.entries(incoming.headers)) {
      if (Array.isArray(value)) value.forEach(v => headers.append(key, v));
      else if (value !== undefined) headers.set(key, value);
    }
    const request = new Request(`http://localhost${path}`, {
      method: incoming.method, headers,
      body: length ? Buffer.concat(chunks) : undefined,
    });
    const rawBody=Buffer.concat(chunks);
    let configBody:any={};try{configBody=JSON.parse(rawBody.toString()||'{}');}catch{}
    if(blockedRequest(path,configBody)){outgoing.writeHead(503,{'Content-Type':'application/json'});outgoing.end(JSON.stringify({code:'feature_unavailable',error:appConfig().message}));return;}
    const paidAction=path==='/api/guidance'?'guidance':path==='/api/kundli/matching'?'matching':null;
    const response = (samsungTester || publicRequest) && account && paidAction ? await coinWallet.run(request,account,paidAction,handler) : await handler(request);
    response.headers.forEach((value, key) => { if (key !== 'set-cookie') outgoing.setHeader(key, value); });
    const cookies = response.headers.getSetCookie();
    if (cookies.length) outgoing.setHeader('Set-Cookie', cookies);
    outgoing.writeHead(response.status);
    outgoing.end(Buffer.from(await response.arrayBuffer()));
  } catch (failure) {
    // Only diagnostic types/schema identifiers; never credentials or payloads.
    const e = failure as any;
    console.error('Request failed', JSON.stringify({type:e?.name,code:e?.code,table:e?.table,column:e?.column,constraint:e?.constraint,undefinedSymbol:e?.name==='ReferenceError' && /^[A-Za-z_$][\w$]* is not defined$/.test(e.message) ? e.message : undefined}));
    if (!outgoing.headersSent) outgoing.writeHead(503, { 'Content-Type': 'application/json' });
    outgoing.end(JSON.stringify({ error: 'Jyotara is temporarily unavailable.' }));
  }
});
const cleanupTimer=setInterval(()=>{
  void cleanDivineSessions().catch(()=>console.warn('Provider cleanup unavailable'));
  void database.pool.query('DELETE FROM user_journey_events WHERE received_at<$1',[Date.now()-90*86400000]).catch(()=>console.warn('Journey retention cleanup unavailable'));
  void database.pool.query('DELETE FROM answer_reports WHERE created_at<$1',[Date.now()-90*86400000]).catch(()=>console.warn('Report retention cleanup unavailable'));
},3600000);
cleanupTimer.unref();
server.requestTimeout = 30000;
server.headersTimeout = 10000;
server.keepAliveTimeout = 5000;
server.listen(Number(process.env.PORT ?? 3000), '127.0.0.1', () => console.log('Jyotara API listening on loopback'));
for (const signal of ['SIGTERM', 'SIGINT']) process.once(signal, () => {
  server.close(() => { void database.close().finally(() => process.exit(0)); });
  setTimeout(() => process.exit(1), 30000).unref();
});
