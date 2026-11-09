#!/usr/bin/env node
import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath,pathToFileURL} from 'node:url';
import {install,status,toggle,uninstall,integrity,sourceCore} from './lib/install.mjs';
import {home,rootFor,copyTree,treeFiles,json,noLinks,version} from './lib/io.mjs';
const args=process.argv.slice(2),action=args.shift(),h=home(),root=rootFor(h);
function save(file,value){fs.writeFileSync(file,json(value));}
function diagnose(){
 const result=spawnSync(process.execPath,[path.join(root,'runtime/core/cli.mjs'),'doctor'],{env:process.env,encoding:'utf8',windowsHide:true,timeout:15000});
 if(result.status!==0)throw Error('INSTALLED_DOCTOR_FAILED: '+result.stderr);
 const observed=JSON.parse(result.stdout);
 if(!['CONNECTED_FOR_NEW_SESSIONS','OFF_FOR_NEW_SESSIONS'].includes(observed.effective)||observed.backupStatus!=='MATCH')throw Error('INSTALLED_CONNECTION_OR_BACKUP_FAILED');
 return observed;
}
function ensureSimplePathManagement(){
 if(fs.existsSync(path.join(root,'path-registration.json')))throw Error('USER_PATH_REGISTERED: Use the verified core/Uninstall-JHarnessCore.ps1 first; this portable setup never changes persistent PATH.');
}
function carry(from){
 for(const name of ['registered','projects'])if(fs.existsSync(path.join(from,name))){if(fs.existsSync(path.join(root,name)))throw Error('CARRY_CONFLICT_'+name);copyTree(path.join(from,name),path.join(root,name));}
 for(const name of ['skills-registry.json','lessons.json'])if(fs.existsSync(path.join(from,name))){if(fs.existsSync(path.join(root,name)))throw Error('CARRY_CONFLICT_'+name);fs.copyFileSync(path.join(from,name),path.join(root,name));}
}
async function update(){
 ensureSimplePathManagement();const before=status(h);if(!['CONNECTED_FOR_NEW_SESSIONS','OFF_FOR_NEW_SESSIONS'].includes(before.effective)||integrity(h).length)throw Error('EXISTING_INSTALL_REQUIRES_REVIEW_BEFORE_UPDATE');
 if(before.version===version)return{result:'ALREADY_CURRENT',...diagnose()};
 const allowed=new Set(['runtime','bin','backup','install.json','session-path.json','registered','projects','skills-registry.json','lessons.json']);
 const unknown=fs.readdirSync(root).filter(name=>!allowed.has(name));if(unknown.length)throw Error('UNRECOGNIZED_FILES_PRESERVED_REVIEW_REQUIRED: '+unknown.join(', '));
 const original=JSON.parse(fs.readFileSync(path.join(root,'install.json'),'utf8')),backup=root+'.backup-before-update-'+Date.now();
 noLinks(backup);copyTree(root,backup);
 const guidance=fs.existsSync(original.target)?fs.readFileSync(original.target):null;
 const backupManifest={product:'J Harness Core',home:h,version:before.version,configured:before.configured,files:treeFiles(backup)};
 save(backup+'.manifest.json',backupManifest);
 const old=await import(pathToFileURL(path.join(root,'runtime/core/lib/install.mjs')));
 let archive;
 try{
  archive=old.uninstall(h).archive;
  install(h,{source:sourceCore});carry(archive);
  if(original.configured==='OFF')toggle(h,'OFF');
  return{result:'UPDATED',previousVersion:before.version,backup,archive,...diagnose()};
 }catch(error){
  let rollback;
  try{
   if(fs.existsSync(root)){try{uninstall(h);}catch{fs.renameSync(root,root+'.failed-'+Date.now());}}
   if(fs.existsSync(root+'.prepare'))fs.renameSync(root+'.prepare',root+'.prepare.failed-'+Date.now());
   copyTree(backup,root);
   const restored=await import(pathToFileURL(path.join(root,'runtime/core/lib/install.mjs'))+'?rollback='+Date.now());
   restored.toggle(h,original.configured);
   const now=fs.existsSync(original.target)?fs.readFileSync(original.target):null;
   rollback={result:'RESTORED',status:restored.status(h),guidanceExact:guidance===null?now===null:now?.equals(guidance)};
  }catch(failure){rollback={result:'MANUAL_RECOVERY_REQUIRED',error:failure.message,backup};}
  throw Error(JSON.stringify({failure:error.message,rollback}));
 }
}
try{
 if(Number(process.versions.node.split('.')[0])<22)throw Error('NODE_22_OR_LATER_REQUIRED_NO_AUTO_INSTALL');
 if(args.length&&action!=='run')throw Error('Setup accepts install, update, uninstall, or run [jh arguments]. It uses CODEX_HOME or the existing default Codex profile.');
 let result;
 if(action==='install'){result=install(h);result={result:'INSTALLED',...result,doctor:diagnose()};}
 else if(action==='update')result=await update();
 else if(action==='uninstall'){ensureSimplePathManagement();result=uninstall(h);}
 else if(action==='run'){
  const file=path.join(root,'runtime/core/cli.mjs');if(!fs.existsSync(file))throw Error('CORE_NOT_INSTALLED_RUN_INSTALL_FIRST');
  const p=spawnSync(process.execPath,[file,...args],{env:process.env,stdio:'inherit',windowsHide:false});process.exitCode=p.status??1;
 }else throw Error('Usage: node core/setup.mjs install|update|uninstall|run [jh arguments]');
 if(result){console.log(json(result));if(action==='install'||action==='update')console.error('J Harness linked to the existing Codex profile. Keep its current login/model settings and start a new Codex session.');}
}catch(error){console.error(json({product:'J Harness Core',result:'ERROR',reason:error.message}));process.exitCode=1;}
