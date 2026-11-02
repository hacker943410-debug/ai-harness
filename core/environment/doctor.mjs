import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const clients=['codex','claude','agy'];
const optionalProfiles={general:[],roblox:['rojo','stylua','selene']};
export const sha256=b=>crypto.createHash('sha256').update(b).digest('hex');

export function findExecutable(name,{envPath=process.env.PATH||'',platform=process.platform,separator=path.delimiter}={}){
  if(!/^[a-z][a-z0-9-]*$/.test(name))throw Error('INVALID_TOOL_NAME');
  const extensions=platform==='win32'?['.exe','.cmd','.bat','']:[''];
  for(const dir of envPath.split(separator).filter(Boolean)){
    try{
      const root=path.resolve(dir);
      if(!fs.statSync(root).isDirectory()||fs.lstatSync(root).isSymbolicLink())continue;
      for(const ext of extensions){
        const candidate=path.join(root,name+ext);
        if(fs.existsSync(candidate)){
          const stat=fs.lstatSync(candidate);
          if(stat.isFile()&&!stat.isSymbolicLink())return candidate;
        }
      }
    }catch{/* inaccessible PATH entry: not installed */}
  }
  return null;
}

export function inspectEnvironment({client='codex',profile='general',platform=process.platform,
 nodeVersion=process.versions.node,envPath=process.env.PATH||'',separator=path.delimiter}={}){
 if(!clients.includes(client))throw Error('UNKNOWN_CLIENT: use codex, claude or agy');
 if(!Object.hasOwn(optionalProfiles,profile))throw Error('UNKNOWN_PROFILE: use general or roblox');
 const nodeOk=Number(String(nodeVersion).replace(/^v/,'').split('.')[0])>=22;
 const paths={};
 for(const name of ['git',client,...optionalProfiles[profile]])
  paths[name]=findExecutable(name,{envPath,platform,separator});
 const steps=[
  {id:'node',required:true,observed:nodeOk?'RUNNING_COMPATIBLE_NODE':'RUNTIME_MISSING_OR_OLD',action:nodeOk?'REUSE':'APPROVAL_REQUIRED_FOR_BUNDLED_RUNTIME'},
  {id:client,required:true,observed:paths[client]?'FOUND_NOT_EXECUTED':'MISSING',action:paths[client]?'VERIFY_IN_SELECTED_CLI':'APPROVAL_REQUIRED_FOR_OFFICIAL_CLI',path:paths[client]},
  {id:'git',required:false,observed:paths.git?'FOUND_NOT_EXECUTED':'MISSING_OPTIONAL',action:paths.git?'REUSE':'DEFER_UNTIL_SOURCE_WORK',path:paths.git},
  ...optionalProfiles[profile].map(id=>({id,required:false,observed:paths[id]?'FOUND_NOT_EXECUTED':'MISSING_OPTIONAL',action:paths[id]?'VERIFY_ON_USE':'INSTALL_PLAN_WHEN_PROJECT_NEEDS_IT',path:paths[id]}))
 ];
 if(profile==='roblox')steps.push({id:'roblox-studio',required:false,observed:'NOT_CHECKED',action:'GUI_SETUP_REQUIRES_USER_APPROVAL'});
 const blocked=steps.filter(x=>x.required&&/MISSING|OLD/.test(x.observed)).map(x=>x.id);
 return {product:'J Harness Environment Bootstrap',schema:1,stage:'PHASE_1_CANDIDATE',
  state:blocked.length?'SETUP_REQUIRED':'DISCOVERED_UNVERIFIED',
  selectedClient:client,profile,nodeVersion:String(nodeVersion),platform,
  steps,blocked,unusedClients:clients.filter(x=>x!==client),
  evidence:{readonly:true,hostChanged:false,packageDownloaded:false,packageInstalled:false,
   authChanged:false,modelSessionVerified:false,supervisorEnforced:false},
  next:'Review source, version, SHA and impact; install only after separate user approval.'};
}
export function planEnvironment(inspect){
 if(inspect?.schema!==1||!Array.isArray(inspect.steps))throw Error('INVALID_INSPECTION');
 return {schema:1,kind:'J_HARNESS_BOOTSTRAP_PLAN',state:inspect.blocked.length?'NEEDS_APPROVAL_AND_COMPONENTS':'PREREQUISITES_DISCOVERED',
  selectedClient:inspect.selectedClient,profile:inspect.profile,
  actions:inspect.steps.map(x=>({component:x.id,decision:x.action,actualInstall:'NOT_RUN',approved:false})),
  installation:'NOT_IMPLEMENTED',hostChanged:false,
  requiredNext:'Build owner-pinned runtime bundle and explicit approved installer.'};
}
function noLinks(target){
 for(let p=path.resolve(target);;p=path.dirname(p)){
  if(fs.existsSync(p)&&fs.lstatSync(p).isSymbolicLink())throw Error('SYMLINK_PATH_REFUSED');
  if(path.dirname(p)===p)break;
 }
}
// Offline preparation primitive only. Not a package installer, does not execute or configure.
export function stagePinnedLocalFile({source,expectedSha256,component,fileName,managedRoot,approved}={}){
 if(approved!==true)throw Error('EXPLICIT_APPROVAL_REQUIRED');
 if(!/^[a-z][a-z0-9-]*$/.test(component||'')||!/^[a-z0-9][a-z0-9._-]*$/i.test(fileName||''))
  throw Error('INVALID_COMPONENT_OR_FILENAME');
 if(!/^[a-f0-9]{64}$/.test(expectedSha256||''))throw Error('TRUSTED_SHA256_REQUIRED');
 if(!source||!managedRoot)throw Error('PATH_REQUIRED');
 const src=path.resolve(source),root=path.resolve(managedRoot),dst=path.join(root,component);
 noLinks(src);noLinks(root);noLinks(dst);
 if(!fs.statSync(src).isFile())throw Error('REGULAR_SOURCE_REQUIRED');
 if(fs.existsSync(dst))throw Error('EXISTING_COMPONENT_PRESERVED');
 if(sha256(fs.readFileSync(src))!==expectedSha256)throw Error('SOURCE_SHA256_MISMATCH');
 fs.mkdirSync(root,{recursive:true});
 const temporary=fs.mkdtempSync(path.join(root,'.jh-stage-'));
 try{
  const target=path.join(temporary,fileName);
  fs.copyFileSync(src,target,fs.constants.COPYFILE_EXCL);
  if(sha256(fs.readFileSync(target))!==expectedSha256)throw Error('STAGED_SHA256_MISMATCH');
  if(fs.existsSync(dst))throw Error('EXISTING_COMPONENT_PRESERVED');
  fs.renameSync(temporary,dst);
  return {status:'VERIFIED_STAGED_NOT_INSTALLED',path:path.join(dst,fileName),
   sha256:expectedSha256,executed:false,hostChanged:false};
 }catch(e){fs.rmSync(temporary,{recursive:true,force:true});throw e}
}
const own=process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(own){
 const [cmd='inspect',...args]=process.argv.slice(2);
 try{
  const get=(name,fallback)=>{const pos=args.indexOf('--'+name);return pos<0?fallback:args[pos+1]};
  if(!['inspect','plan'].includes(cmd)||args.some((a,i)=>i%2===0?!['--client','--profile'].includes(a):false))throw Error('ONLY_READONLY_INSPECT_OR_PLAN');
  const result=inspectEnvironment({client:get('client','codex'),profile:get('profile','general')});
  process.stdout.write(JSON.stringify(cmd==='plan'?planEnvironment(result):result,null,2)+'\n');
  if(cmd==='inspect'&&result.blocked.length)process.exitCode=3;
 }catch(e){process.stderr.write(JSON.stringify({state:'BLOCKED',reason:e.message})+'\n');process.exitCode=2}
}
