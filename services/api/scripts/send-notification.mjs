// Operator-only FCM test sender. The token and service-account key stay in files.
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';
const [credentialFile, messageFile] = process.argv.slice(2);
if (!credentialFile || !messageFile) throw new Error('Usage: send-notification.mjs <credential-file> <message-file>');
const key = JSON.parse(readFileSync(credentialFile, 'utf8'));
const message = JSON.parse(readFileSync(messageFile, 'utf8'));
if (key.project_id !== 'jyotra-db0f4' || !message.token || message.topic || message.condition) throw new Error('A single device token is required');
const now = Math.floor(Date.now() / 1000);
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const payload = encode({alg: 'RS256', typ: 'JWT'}) + '.' + encode({iss: key.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600});
const assertion = payload + '.' + createSign('RSA-SHA256').update(payload).sign(key.private_key, 'base64url');
const auth = await fetch('https://oauth2.googleapis.com/token', {method: 'POST', headers: {'content-type': 'application/x-www-form-urlencoded'}, body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}), signal: AbortSignal.timeout(15000)});
const token = await auth.json();
if (!auth.ok || !token.access_token) throw new Error('FCM authentication failed');
const response = await fetch(`https://fcm.googleapis.com/v1/projects/${key.project_id}/messages:send`, {method: 'POST', headers: {authorization: `Bearer ${token.access_token}`, 'content-type': 'application/json'}, body: JSON.stringify({message}), signal: AbortSignal.timeout(15000)});
const result = await response.json();
console.log(JSON.stringify({accepted: response.ok, status: response.status, messageId: response.ok ? result.name : undefined, error: result.error?.status}));
if (!response.ok) process.exitCode = 1;
