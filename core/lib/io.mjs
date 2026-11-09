import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';
export const version='8.0.0-core-beta.1';
export const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
export const fileHash=file=>hash(fs.readFileSync(file));
export const json=value=>JSON.stringify(value,null,2)+'\n';
export const home=explicit=>path.resolve(explicit??process.env.CODEX_HOME??path.join(os.homedir(),'.codex'));
export const rootFor=h=>path.join(h,'j-harness-core');
export function noLinks(target){let cursor=path.resolve(target);while(true){if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error('LINK_PATH_REFUSED: '+cursor);const p=path.dirname(cursor);if(p===cursor)break;cursor=p;}}
export function atomic(file,bytes){noLinks(file);fs.mkdirSync(path.dirname(file),{recursive:true});const tmp=file+'.tmp-'+crypto.randomUUID();try{fs.writeFileSync(tmp,bytes,{flag:'wx',mode:0o600});fs.renameSync(tmp,file);}finally{if(fs.existsSync(tmp))fs.unlinkSync(tmp);}}
export function readJson(file,fallback=null){if(!fs.existsSync(file))return fallback;noLinks(file);return JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));}
export function safeText(text){if(typeof text!=='string'||!text.trim()||text.length>12000)throw Error('BOUNDED_TEXT_REQUIRED');if(/-----BEGIN .*PRIVATE KEY|\b(?:sk-|gh[pousr]_)[A-Za-z0-9_-]{20,}|(?:api_key|access_token|refresh_token|password)\s*[=:]\s*\S+/i.test(text))throw Error('SECRET_LIKE_TEXT_REFUSED');return text;}
export function copyTree(source,dest){noLinks(source);noLinks(dest);if(!fs.statSync(source).isDirectory())throw Error('DIRECTORY_REQUIRED');fs.mkdirSync(dest,{recursive:true});for(const item of fs.readdirSync(source,{withFileTypes:true})){const a=path.join(source,item.name),b=path.join(dest,item.name);if(item.isSymbolicLink())throw Error('SKILL_OR_RUNTIME_LINK_REFUSED');if(item.isDirectory())copyTree(a,b);else if(item.isFile())fs.copyFileSync(a,b);}}
export function treeFiles(root,exclude=new Set()){const rows=[];function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){if(exclude.has(item.name))continue;const file=path.join(dir,item.name);if(item.isSymbolicLink())throw Error('LINK_IN_RUNTIME');if(item.isDirectory())walk(file);else if(item.isFile())rows.push({path:path.relative(root,file).replaceAll('\\','/'),sha256:fileHash(file)});}}walk(root);return rows.sort((a,b)=>a.path.localeCompare(b.path,'en'));}
export const stateFile=h=>path.join(rootFor(h),'install.json');
export function load(h){const s=readJson(stateFile(h));if(!s||s.product!=='J Harness Core'||s.schema!==1||s.home!==h)throw Error('CORE_NOT_INSTALLED_FOR_THIS_CODEX_HOME');return s;}
export function projectSlot(h,project){noLinks(project);const real=fs.realpathSync(path.resolve(project));const slot=path.join(real,'.jh-artifacts','j-harness-core');noLinks(slot);return slot;}
// Historical records are read-only compatibility input; never migrate/delete implicitly.
export function legacyProjectSlot(h,project){const real=fs.realpathSync(path.resolve(project));const slot=path.join(rootFor(h),'projects',hash(real).slice(0,24));noLinks(slot);return slot;}
