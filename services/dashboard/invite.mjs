import {Auth} from './auth.mjs';
const auth=new Auth(process.env.DASHBOARD_AUTH_DB||'/var/lib/jyotara-dashboard/auth.sqlite');
const email=process.argv[2],role=process.argv[3]||'viewer';
const token=auth.invite(email,role);console.log('https://api.jyotara.in/dashboard/#invite='+token);
