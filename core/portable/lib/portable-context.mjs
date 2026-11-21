import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

let context=null;
export const portableContext=()=>context;
export const sha256=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
export function noLinks(target){let cursor=path.resolve(target);for(;;){if(fs.lstatSync(cursor,{throwIfNoEntry:false})?.isSymbolicLink())throw Error('LINK_PATH_REFUSED: '+cursor);const parent=path.dirname(cursor);if(parent===cursor)return;cursor=parent;}}
function canonicalPath(target){noLinks(target);return fs.realpathSync.native(target);}
function sameDirectory(left,right){const a=canonicalPath(left),b=canonicalPath(right);if(a===b)return true;if(process.platform!=='win32')return false;const x=fs.statSync(a,{bigint:true}),y=fs.statSync(b,{bigint:true});return x.isDirectory()&&y.isDirectory()&&x.dev===y.dev&&x.ino===y.ino;}
export function contained(root,relative){if(typeof relative!=='string'||!relative||path.isAbsolute(relative)||/^[A-Za-z]:/.test(relative)||relative.split(/[\\/]/).some(p=>!p||p==='.'||p==='..'))throw Error('INVALID_RELATIVE_PATH: '+relative);const full=path.resolve(root,relative);if(!full.startsWith(path.resolve(root)+path.sep))throw Error('PATH_ESCAPE');noLinks(full);return full;}
export function manifestFiles(root){const rows=[];function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,item.name),relative=path.relative(root,full).replaceAll('\\','/');if(relative==='tests'||relative==='PORTABLE.md'||relative==='manifest.json')continue;noLinks(full);if(item.isDirectory())walk(full);else if(item.isFile())rows.push({path:relative,sha256:sha256(fs.readFileSync(full))});}}walk(root);return rows.sort((a,b)=>a.path.localeCompare(b.path,'en'));}
export function buildManifest(root){const pkg=JSON.parse(fs.readFileSync(path.join(root,'runtime/core/package.json'),'utf8'));return{schema:1,product:'J Harness Core',version:pkg.version,mode:'PROJECT_PORTABLE',adapterVersion:'1.0.0',files:manifestFiles(root)};}
export function validateRuntime(root,project){
 noLinks(root);noLinks(project);
 const manifestFile=path.join(root,'manifest.json');
 noLinks(manifestFile);
 const bytes=fs.readFileSync(manifestFile),manifest={...JSON.parse(bytes),manifestSha256:sha256(bytes)};
 if(manifest.schema!==1||manifest.product!=='J Harness Core'||manifest.mode!=='PROJECT_PORTABLE'
  ||manifest.adapterVersion!=='1.0.0'||!Array.isArray(manifest.files)||!manifest.files.length)throw Error('INVALID_PORTABLE_MANIFEST');
 const seen=new Set(),key=full=>process.platform==='win32'?full.toLowerCase():full;
 for(const row of manifest.files){
  const full=contained(root,row.path);
  if(seen.has(key(full)))throw Error('DUPLICATE_MANIFEST_PATH');
  seen.add(key(full));
  if(!/^[a-f0-9]{64}$/.test(row.sha256)||!fs.statSync(full).isFile()||sha256(fs.readFileSync(full))!==row.sha256)throw Error('RUNTIME_HASH_DRIFT: '+row.path);
 }
 const actual=manifestFiles(root);
 if(actual.length!==manifest.files.length||actual.some(row=>!seen.has(key(path.resolve(root,row.path)))))throw Error('INCOMPLETE_RUNTIME_MANIFEST');
 const pkg=JSON.parse(fs.readFileSync(path.join(root,'runtime/core/package.json'),'utf8'));
 if(pkg.version!==manifest.version)throw Error('RUNTIME_VERSION_MISMATCH');
 const bindingFile=path.join(project,'.ai/harness-project.json');
 noLinks(bindingFile);
 if(!fs.existsSync(bindingFile))return {...manifest,projectBinding:'UNBOUND'};
 const binding=JSON.parse(fs.readFileSync(bindingFile,'utf8').replace(/^\uFEFF/,''));
 const harness=binding.binding?.harness??binding.harness;
 if(harness?.product!=='J Harness Core')return {...manifest,projectBinding:harness?'DIFFERENT_HARNESS':'UNBOUND'};
 const boundRoot=harness.root??harness.runtime_root;
 if(typeof boundRoot!=='string'||!fs.existsSync(path.resolve(project,boundRoot))||!sameDirectory(path.resolve(project,boundRoot),root))throw Error('BOUND_RUNTIME_MISMATCH');
 if(harness.version!==manifest.version)throw Error('BOUND_VERSION_MISMATCH');
 const pin=harness.manifest_sha256??harness.manifestSha256;
 if(typeof pin!=='string'||pin!==manifest.manifestSha256)throw Error('BOUND_MANIFEST_HASH_MISMATCH');
 return {...manifest,projectBinding:'BOUND_VERIFIED'};
}
export function configurePortable(root,project){
 if(context)throw Error('PORTABLE_CONTEXT_ALREADY_CONFIGURED');
 const manifest=validateRuntime(root,project);
 context=Object.freeze({root:canonicalPath(root),project:canonicalPath(project),version:manifest.version,
  distributionVersion:manifest.distributionVersion??null,manifestSha256:manifest.manifestSha256,
  projectBinding:manifest.projectBinding,mode:'PROJECT_PORTABLE'});
 globalThis[Symbol.for('j-harness.portable.v1')]={context,portableStatus,mutableRoot,scopedFingerprint};
 return context;
}
export function mutableRoot(){if(!context)throw Error('PORTABLE_CONTEXT_REQUIRED');return path.join(context.project,'.jh-artifacts/j-harness-core');}
export function portableStatus(){
 if(!context)throw Error('PORTABLE_CONTEXT_REQUIRED');
 return {product:'J Harness Core',version:context.version,distributionVersion:context.distributionVersion,
  mode:context.mode,project:context.project,projectBinding:context.projectBinding,
  configured:'ON',effective:'READY_LOCAL',globalConnectionRequired:false,
  globalConnection:'NOT_REQUIRED_NOT_OBSERVED',modelApplication:'NOT_OBSERVED'};
}

export function scopedFingerprint(project,credentialPathName){
 const file=path.join(project,'.ai/harness-project.json');
 noLinks(file);if(!fs.existsSync(file))return null;
 const scope=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'')).verification_scope;
 if(scope===undefined)return null;
 if(!scope||!Array.isArray(scope.include)||!scope.include.length||!Array.isArray(scope.exclude??[])
  ||scope.include.some(x=>typeof x!=='string')||(scope.exclude??[]).some(x=>typeof x!=='string'))throw Error('INVALID_VERIFICATION_SCOPE');
 const root=fs.realpathSync(project);
 const excluded=(scope.exclude??[]).map(item=>{contained(root,item);return item.replaceAll('\\','/');});
 const rows=new Map();
 function walk(full){
  const relative=path.relative(root,full).replaceAll('\\','/');
  if(credentialPathName(path.basename(full))||excluded.some(item=>relative===item||relative.startsWith(item+'/')))return;
  noLinks(full);
  const stat=fs.statSync(full);
  if(stat.isDirectory()){for(const name of fs.readdirSync(full))walk(path.join(full,name));}
  else if(stat.isFile())rows.set(relative,sha256(fs.readFileSync(full)));
  else throw Error('UNSUPPORTED_SCOPE_FILE');
 }
 for(const item of scope.include){
  if(item.split(/[\\/]/).some(credentialPathName))throw Error('CREDENTIAL_PATH_NOT_ALLOWED_IN_VERIFICATION_SCOPE');
  const full=contained(root,item);
  if(!fs.existsSync(full))throw Error('MISSING_SCOPE_INPUT: '+item);
  walk(full);
 }
 if(!rows.size)throw Error('EMPTY_VERIFICATION_SCOPE');
 const entries=[...rows].sort((a,b)=>a[0].localeCompare(b[0],'en'));
 return {sha256:sha256(JSON.stringify({scope,entries})),files:entries.length,
  scope:JSON.parse(JSON.stringify(scope)),exclusions:excluded,credentialFilenamesExcluded:true};
}
