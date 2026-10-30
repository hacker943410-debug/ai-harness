import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {version,rootFor,stateFile,load,readJson,noLinks,copyTree,treeFiles,atomic,json,fileHash,hash} from './io.mjs';
import {selectedGlobal,codexVersion} from './codex.mjs';
export const sourceCore=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function bridge(cli){const literal=process.platform==='win32'?"'"+cli.replaceAll("'","''")+"'":"'"+cli.replaceAll("'","'\\''")+"'";return '\n\n<!-- J_HARNESS_CORE:BEGIN v1 -->\n# J Harness Core — collaborative development\nJ Harness is connected for this Codex home. For a development task, first run:\n`node '+literal+' status`\nIf configured OFF or broken, skip J Harness. Otherwise announce `[J Harness · 분석]`, then read the guided Skill with:\n`node '+literal+' skills read jh-guided-development`\nFollow its analyze → plan → implement → verify → handoff flow; show concise Korean progress and actual policy/Skill/check evidence. Ask only material questions; propose reversible defaults. No OS enforcement is promised. Do not load all policies or Skills. Existing project instructions and user intent still apply.\n<!-- J_HARNESS_CORE:END -->\n';}
export function install(h,{source=sourceCore}={}){
 noLinks(h);const destination=rootFor(h);if(fs.existsSync(destination))throw Error('INSTALLATION_ALREADY_EXISTS_USE_STATUS_OR_UNINSTALL');
 const observed=codexVersion({codexHome:h});if(!observed.installed)throw Error('EXISTING_CODEX_CLI_REQUIRED_NO_AUTO_INSTALL');
 const target=selectedGlobal(h);noLinks(target);const original=fs.existsSync(target)?fs.readFileSync(target):Buffer.alloc(0);
 new TextDecoder('utf-8',{fatal:true}).decode(original);
 if(original.length>24000)throw Error('EXISTING_GLOBAL_GUIDANCE_TOO_LARGE_REVIEW_CONTEXT_LIMIT');
 if(original.includes(Buffer.from('<!-- J_HARNESS_CORE:BEGIN')))throw Error('UNOWNED_EXISTING_BRIDGE_REFUSED');
 // Prepare a private staging tree first; the global instruction file is the last link.
 fs.mkdirSync(h,{recursive:true});const stage=destination+'.prepare';if(fs.existsSync(stage))throw Error('PREVIOUS_PREPARATION_REQUIRES_REVIEW');fs.mkdirSync(stage);
 let linked=false;
 try{
  const runtime=path.join(stage,'runtime'),core=path.join(runtime,'core');fs.mkdirSync(core,{recursive:true});
  for(const name of ['lib','knowledge','skills'])copyTree(path.join(source,name),path.join(core,name));
  for(const name of ['cli.mjs','package.json'])fs.copyFileSync(path.join(source,name),path.join(core,name));
  const repository=path.dirname(source);copyTree(path.join(repository,'policies'),path.join(runtime,'policies'));
  fs.mkdirSync(path.join(runtime,'knowledge'),{recursive:true});
  for(const name of ['beginner-mode.md','briefing-protocol.md','project-mode-router.md','verification-profiles.md','token-policy.md'])fs.copyFileSync(path.join(repository,'harness/runtime',name),path.join(runtime,'knowledge',name));
  fs.copyFileSync(path.join(repository,'workflows/CAPABILITY_ACQUISITION.md'),path.join(runtime,'knowledge/CAPABILITY_ACQUISITION.md'));
  // Reuse the existing canonical dashboard skill; office/external Skills remain discoverable extensions.
  copyTree(path.join(repository,'skills/dashboard-builder'),path.join(runtime,'skills/dashboard-builder'));
  const cli=path.join(destination,'runtime/core/cli.mjs'),block=bridge(cli),inventory=treeFiles(runtime);
  const backupRelative='backup/global-guidance.before.bin';atomic(path.join(stage,backupRelative),original);
  const state={schema:1,product:'J Harness Core',version,home:h,configured:'ON',target,originalExisted:fs.existsSync(target),originalSha256:hash(original),originalBytes:original.length,backupRelative,bridge:block,inventory,installedUtc:new Date().toISOString(),codexVersion:observed.version,verificationScope:'INSTRUCTIONS_CONNECTION_NOT_OS_ENFORCEMENT'};
  fs.mkdirSync(path.join(stage,'bin'));fs.writeFileSync(path.join(stage,'install.json'),json(state));
  // ASCII launchers keep Unicode/spaces in the installation path via %~dp0/$PSScriptRoot.
  fs.writeFileSync(path.join(stage,'bin/jh.cmd'),'@echo off\r\n"'+process.execPath+'" "%~dp0..\\runtime\\core\\cli.mjs" --codex-home "%~dp0..\\.." %*\r\nexit /b %ERRORLEVEL%\r\n');
  fs.writeFileSync(path.join(stage,'bin/jh.ps1'),'& '+"'"+process.execPath.replaceAll("'","''")+"'"+' ([IO.Path]::Combine($PSScriptRoot,\'..\',\'runtime\',\'core\',\'cli.mjs\')) --codex-home ([IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot,\'..\',\'..\'))) @args\r\nexit $LASTEXITCODE\r\n');
  fs.renameSync(stage,destination);
  const latest=fs.existsSync(target)?fs.readFileSync(target):Buffer.alloc(0);if(!latest.equals(original))throw Error('GLOBAL_GUIDANCE_CHANGED_DURING_PREPARATION_PRESERVED');
  atomic(target,Buffer.concat([original,Buffer.from(block)]));linked=true;
  return status(h);
 }catch(error){
  // Preserve a failed private preparation for diagnosis; never recursively remove user paths.
  if(linked)atomic(target,original);throw error;
 }
}
export function integrity(h,s=load(h)){const base=path.join(rootFor(h),'runtime');const issues=[];for(const row of s.inventory){const file=path.join(base,row.path);try{noLinks(file);if(fileHash(file)!==row.sha256)issues.push(row.path);}catch{issues.push(row.path);}}return issues;}
export function status(h,{checkRuntime=true}={}){
 let s;try{s=load(h);}catch{return{product:'J Harness Core',home:h,configured:'NOT_INSTALLED',effective:'NOT_CONNECTED',modelApplication:'NOT_OBSERVED'};}
 const selected=selectedGlobal(h),bytes=fs.existsSync(s.target)?fs.readFileSync(s.target):Buffer.alloc(0),block=Buffer.from(s.bridge),first=bytes.indexOf(block),last=bytes.lastIndexOf(block);
 const linked=first>=0&&first===last&&selected===s.target,drift=checkRuntime?integrity(h,s):[];
 const backup=s.backupRelative?path.join(rootFor(h),s.backupRelative):null;let backupStatus='NOT_AVAILABLE_PREVIOUS_BUILD';if(backup){try{noLinks(backup);backupStatus=fileHash(backup)===s.originalSha256?'MATCH':'CHANGED';}catch{backupStatus='MISSING';}}
 return{product:s.product,version:s.version,home:h,configured:s.configured,effective:drift.length?'BROKEN_RUNTIME':s.configured==='OFF'?(first<0?'OFF_FOR_NEW_SESSIONS':'BROKEN_OFF_LINK'):linked?'CONNECTED_FOR_NEW_SESSIONS':'NOT_CONNECTED',instructionTarget:s.target,selectedGlobal:selected,bridgePresent:first>=0,runtimeDrift:drift,backupStatus,modelApplication:'NOT_OBSERVED_USE_REAL_CODEX_SESSION',existingSessions:'RESTART_REQUIRED_AFTER_TOGGLE',codexVersion:s.codexVersion,securityScope:'COOPERATIVE_INSTRUCTIONS_NOT_OS_ENFORCEMENT'};
}
export function requireOn(h){const observed=status(h);if(observed.configured!=='ON'||observed.effective!=='CONNECTED_FOR_NEW_SESSIONS')throw Error('HARNESS_NOT_CONNECTED: '+observed.effective);return load(h);}
export function toggle(h,mode){if(!['ON','OFF'].includes(mode))throw Error('ON_OR_OFF_ONLY');const s=load(h);noLinks(s.target);const current=fs.existsSync(s.target)?fs.readFileSync(s.target):Buffer.alloc(0),block=Buffer.from(s.bridge),index=current.indexOf(block);
 if(current.includes(Buffer.from('<!-- J_HARNESS_CORE:BEGIN'))&&index<0)throw Error('MANAGED_BLOCK_EDITED_PRESERVED_REVIEW_REQUIRED');
 if(index>=0&&current.indexOf(block,index+1)>=0)throw Error('DUPLICATE_BRIDGE_REFUSED');
 if(mode==='ON'){
  if(integrity(h,s).length)throw Error('RUNTIME_CHANGED_REINSTALL_REVIEW_REQUIRED');if(selectedGlobal(h)!==s.target)throw Error('GLOBAL_OVERRIDE_CHANGED_REVIEW_REQUIRED');
  if(index<0)atomic(s.target,Buffer.concat([current,block]));
 }else if(index>=0){const remaining=Buffer.concat([current.subarray(0,index),current.subarray(index+block.length)]);if(!s.originalExisted&&remaining.length===0)fs.unlinkSync(s.target);else atomic(s.target,remaining);}
 s.configured=mode;atomic(stateFile(h),json(s));return status(h);
}
export function uninstall(h){const s=load(h);toggle(h,'OFF');const exactOriginalRestored=s.originalSha256?(!s.originalExisted?!fs.existsSync(s.target):fs.existsSync(s.target)&&fileHash(s.target)===s.originalSha256):null;const disabled=rootFor(h)+'.uninstalled-'+Date.now();fs.renameSync(rootFor(h),disabled);return{product:s.product,result:'UNLINKED',archive:disabled,exactOriginalRestored,backupRetained:s.backupRelative?path.join(disabled,s.backupRelative):null,existingCliConfigurationChanged:false,credentialsTouched:false,note:'Private runtime and original guidance backup retained. Later user edits outside our block are preserved, not overwritten with an old backup.'};}
