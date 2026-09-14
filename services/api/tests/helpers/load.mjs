import fs from 'node:fs';
import path from 'node:path';
import ts from 'typescript';
export function moduleFor(file,env='__divineTestEnv',cache=new Map()) {
 const root=path.resolve('tests');file=path.resolve(root,file);
 if(cache.has(file))return cache.get(file);
 let code=file.endsWith('.json')?'export default '+fs.readFileSync(file,'utf8'):ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
 code=code.replace(/import \{ env \} from ['"]cloudflare:workers['"];?/g,`const env=globalThis.${env};`);
 code=code.replace(/from ['"](@\/[^'"]+|\.[^'"]+)['"]/g,(_,specifier)=>{
  let target=specifier.startsWith('@/')?path.resolve('..', 'api',specifier.slice(2)):path.resolve(path.dirname(file),specifier);
  if(!path.extname(target))target+='.ts';
  return 'from '+JSON.stringify(moduleFor(target,env,cache));
 });
 const result='data:text/javascript;base64,'+Buffer.from(code).toString('base64');cache.set(file,result);return result;
}
