import {readFileSync} from 'node:fs';
export const defaults = {
 schema:1, revision:1,
 features:{chat:true,detailed:false,daily:true,matching:true,explore:true,purchases:true},
 maintenance:false, message:'This feature is temporarily unavailable. Please try again later.',
 announcement:'', disabledGuides:[] as string[], disabledPacks:[] as string[],
 languages:['english','tamil','tanglish'],
 guideDescriptions:{} as Record<string,string>,
 exploreCards:[] as {title:string;body:string}[],
 supportEmail:'jyotara29@gmail.com',
 welcome:{english:'',tamil:'',tanglish:''},
 costs:{generalStandard:10,generalDetailed:20,relationshipStandard:15,relationshipDetailed:30,matching:20},
};
export type AppConfig=typeof defaults;
const object=(v:unknown):v is Record<string,any>=>!!v&&typeof v==='object'&&!Array.isArray(v);
export function validateConfig(v:unknown):AppConfig {
 if(!object(v)||v.schema!==1||!Number.isSafeInteger(v.revision)||v.revision<1)throw Error('Invalid config schema/revision');
 const allowed=Object.keys(defaults);if(Object.keys(v).some(k=>!allowed.includes(k)))throw Error('Unknown config field');
 const c:AppConfig=JSON.parse(JSON.stringify(defaults));c.revision=v.revision;
 if(v.features!==undefined){if(!object(v.features))throw Error('Invalid features');for(const [k,x] of Object.entries(v.features)){if(!(k in c.features)||typeof x!=='boolean')throw Error('Invalid feature');(c.features as any)[k]=x;}}
 if(v.maintenance!==undefined){if(typeof v.maintenance!=='boolean')throw Error('Invalid maintenance');c.maintenance=v.maintenance;}
 for(const k of ['message','announcement','supportEmail'] as const){if(v[k]!==undefined){if(typeof v[k]!=='string'||v[k].length>300)throw Error('Invalid text');c[k]=v[k];}}
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(c.supportEmail))throw Error('Invalid support email');
 for(const k of ['disabledGuides','disabledPacks','languages'] as const){if(v[k]!==undefined){if(!Array.isArray(v[k])||v[k].length>30||v[k].some((x:unknown)=>typeof x!=='string'||!/^[a-zA-Z][a-zA-Z -]{0,59}$/.test(x)))throw Error('Invalid list');c[k]=v[k];}}
 if(!c.languages.length||c.languages.some(x=>!['english','tamil','tanglish'].includes(x)))throw Error('Invalid languages');
 if(v.guideDescriptions!==undefined){if(!object(v.guideDescriptions)||Object.keys(v.guideDescriptions).length>30)throw Error('Invalid guides');for(const [k,x] of Object.entries(v.guideDescriptions)){if(!/^[A-Za-z -]{1,60}$/.test(k)||typeof x!=='string'||x.length>250)throw Error('Invalid guide description');c.guideDescriptions[k]=x;}}
 if(v.exploreCards!==undefined){if(!Array.isArray(v.exploreCards)||v.exploreCards.length>20)throw Error('Invalid cards');c.exploreCards=v.exploreCards.map((x:unknown)=>{if(!object(x)||typeof x.title!=='string'||typeof x.body!=='string'||x.title.length>80||x.body.length>2000)throw Error('Invalid card');return {title:x.title,body:x.body};});}
 if(v.welcome!==undefined){if(!object(v.welcome))throw Error('Invalid welcome');for(const [k,x] of Object.entries(v.welcome)){if(!(k in c.welcome)||typeof x!=='string'||x.length>300)throw Error('Invalid welcome');(c.welcome as any)[k]=x;}}
 if(v.costs!==undefined){if(!object(v.costs))throw Error('Invalid costs');for(const [k,x] of Object.entries(v.costs)){if(!(k in c.costs)||!Number.isSafeInteger(x)||x<1||x>500)throw Error('Invalid cost');(c.costs as any)[k]=x;}if(c.costs.generalDetailed<c.costs.generalStandard||c.costs.relationshipDetailed<c.costs.relationshipStandard)throw Error('Invalid upgrade cost');}
 return c;
}
let last:AppConfig=validateConfig(defaults),checked=0;
export function appConfig():AppConfig {
 const path=process.env.JYOTARA_APP_CONFIG_PATH;
 if(!path)return validateConfig(defaults);
 if(Date.now()-checked<5000)return last;
 checked=Date.now();
 try{const raw=readFileSync(path,'utf8');if(raw.length>32000)throw Error('Too large');last=validateConfig(JSON.parse(raw));}catch{console.warn('App configuration invalid; retaining last valid settings');}
 return last;
}
// Never pause authentication, payment callbacks, verification, refunds or recovery.
export function blockedRequest(path:string,body:any,c=appConfig()):boolean {
 if(['/api/wallet/verify','/api/wallet/refresh','/api/wallet/status'].includes(path))return false;
 const feature=path==='/api/guidance'?'chat':path==='/api/kundli/matching'?'matching':path==='/api/horoscope/daily'?'daily':path==='/api/explore/panchang'?'explore':path==='/api/wallet/create'?'purchases':null;
 if(feature&&(c.maintenance||!c.features[feature]))return true;
 if(path==='/api/guidance')return (body?.depth==='detailed'&&!c.features.detailed)||c.disabledGuides.includes(body?.guide)||!c.languages.includes((['english','tamil','tanglish'].includes(body?.responseStyle)?body.responseStyle:body?.language==='ta'?'tamil':'english'));
 if(path==='/api/wallet/create')return c.disabledPacks.includes(body?.packId);
 if(path==='/api/wallet/quote')return blockedRequest(body?.action==='matching'?'/api/kundli/matching':'/api/guidance',body?.payload,c);
 return false;
}
