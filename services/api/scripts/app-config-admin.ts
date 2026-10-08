import {readFileSync,writeFileSync,renameSync,copyFileSync,existsSync,chmodSync} from 'node:fs';
import {validateConfig} from '../runtime/app-config';
// Run only through authenticated server-operator SSH. No HTTP admin endpoint.
const [source,target]=process.argv.slice(2);
if(!source||!target)throw Error('Usage: app-config-admin.mjs INPUT.json TARGET.json');
const raw=readFileSync(source,'utf8');if(raw.length>32000)throw Error('Config too large');
const next=validateConfig(JSON.parse(raw));
if(existsSync(target)){
 const old=validateConfig(JSON.parse(readFileSync(target,'utf8')));
 if(next.revision<=old.revision)throw Error('Increment revision, including rollbacks');
 copyFileSync(target,target+'.previous');chmodSync(target+'.previous',0o640);
}
writeFileSync(target+'.next',JSON.stringify(next,null,2)+'\n',{mode:0o640});
renameSync(target+'.next',target);
console.log(JSON.stringify({applied:true,schema:next.schema,revision:next.revision}));
