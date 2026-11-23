#!/usr/bin/env node
// Add a relative project bridge; no global profile, account or CLI configuration is touched.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {bridgeStart as start,bridgeEnd as end,projectBridge} from './lib/project-bridge.mjs';

const runtime=path.dirname(fileURLToPath(import.meta.url));
const args=process.argv.slice(2);
const digest=data=>crypto.createHash('sha256').update(data).digest('hex');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
const ensurePlain=file=>{for(let cursor=path.resolve(file);;cursor=path.dirname(cursor)){if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error('LINK_PATH_REQUIRES_REVIEW');if(path.dirname(cursor)===cursor)break;}};
try {
  if(args.length!==2||args[0]!=='--project')throw Error('Usage: setup.mjs --project <folder>');
  const project=fs.realpathSync(path.resolve(args[1]));
  ensurePlain(project);ensurePlain(runtime);
  const relative=path.relative(project,runtime).replaceAll('\\','/');
  if(!relative||relative.startsWith('../')||path.isAbsolute(relative))throw Error('EXTRACT_RUNTIME_INSIDE_THE_PROJECT_FIRST');
  const checked=spawnSync(process.execPath,[path.join(runtime,'portable.mjs'),'--project',project,'status'],{encoding:'utf8',windowsHide:true});
  if(checked.status!==0)throw Error('RUNTIME_VALIDATION_FAILED: '+checked.stderr.trim());
  const status=JSON.parse(checked.stdout);
  if(status.effective!=='READY_LOCAL')throw Error('PORTABLE_RUNTIME_NOT_READY');
  const configFile=path.join(project,'.ai/harness-project.json'),agents=path.join(project,'AGENTS.md');
  for(const file of [configFile,agents])ensurePlain(file);
  const existing=fs.existsSync(configFile)?read(configFile):null;
  if(existing&&existing.harness?.product!=='J Harness Core')throw Error('EXISTING_HARNESS_MIGRATION_REQUIRES_REVIEW: current files preserved');
  if(!existing&&['.ai/harness.yaml','.ai/HARNESS.md'].some(file=>fs.existsSync(path.join(project,file))))throw Error('EXISTING_HARNESS_MIGRATION_REQUIRES_REVIEW: current files preserved');
  const originalExisted=fs.existsSync(agents);
  const original=originalExisted?fs.readFileSync(agents):Buffer.alloc(0);
  const text=new TextDecoder('utf-8',{fatal:true}).decode(original);
  const count=(value,needle)=>value.split(needle).length-1;
  if(count(text,start)!==count(text,end)||count(text,start)>1)throw Error('MANAGED_PROJECT_BRIDGE_REQUIRES_REVIEW');
  const manifestPath=path.join(runtime,'manifest.json'),manifest=read(manifestPath),manifestSha=digest(fs.readFileSync(manifestPath));
  const bridge='\n\n'+projectBridge(relative,manifest.version,fs.existsSync(path.join(runtime,'vendor/win-x64/node.exe')))+'\n';
  if(text.includes(start)) {
    if(!existing||text.indexOf(end)<text.indexOf(start)||text.slice(text.indexOf(start),text.indexOf(end)+end.length)!==bridge.trim())throw Error('MANAGED_PROJECT_BRIDGE_REQUIRES_REVIEW: binding or bridge mismatch; current files preserved');
    console.log(JSON.stringify({status:'READY_LOCAL',version:manifest.version,changed:false,globalConnectionRequired:false}));
    process.exit(0);
  }
  if(text.includes('<!-- AI-HARNESS:START -->'))throw Error('EXISTING_PROJECT_RULE_MIGRATION_REQUIRES_REVIEW: current files preserved');
  const config=existing??{schema_version:4,beginner_mode:true,harness:{product:'J Harness Core',version:manifest.version,mode:'PROJECT_PORTABLE',root:relative,manifest_sha256:manifestSha,source_hash:manifestSha,fallback:'NONE'}};
  const backupDir=path.join(project,'.jh-artifacts/j-harness-core/setup',crypto.randomUUID());
  ensurePlain(backupDir);fs.mkdirSync(backupDir,{recursive:true});
  fs.writeFileSync(path.join(backupDir,'AGENTS.before.bin'),original,{flag:'wx'});
  const beforeConfig=fs.existsSync(configFile)?fs.readFileSync(configFile):null;
  if(beforeConfig)fs.writeFileSync(path.join(backupDir,'binding.before.json'),beforeConfig,{flag:'wx'});
  const expected=fs.existsSync(agents)?fs.readFileSync(agents):Buffer.alloc(0);
  if(!expected.equals(original))throw Error('PROJECT_GUIDANCE_CHANGED_DURING_SETUP');
  const combined=Buffer.concat([original,Buffer.from(bridge)]);
  const temp=agents+'.tmp-'+crypto.randomUUID();
  fs.writeFileSync(temp,combined,{flag:'wx'});
  let guidanceWritten=false,bindingWritten=false;
  try {
    if(!existing){fs.mkdirSync(path.dirname(configFile),{recursive:true});fs.writeFileSync(configFile,JSON.stringify(config,null,2)+'\n',{flag:'wx'});bindingWritten=true;}
    fs.renameSync(temp,agents);guidanceWritten=true;
    fs.writeFileSync(path.join(backupDir,'receipt.json'),JSON.stringify({version:manifest.version,originalSha256:digest(original),newSha256:digest(combined),newBinding:bindingWritten,globalFilesTouched:false},null,2),{flag:'wx'});
  } catch(error) {
    if(guidanceWritten&&fs.readFileSync(agents).equals(combined)){if(originalExisted)fs.writeFileSync(agents,original);else fs.unlinkSync(agents);}
    if(bindingWritten&&digest(fs.readFileSync(configFile))===digest(Buffer.from(JSON.stringify(config,null,2)+'\n')))fs.unlinkSync(configFile);
    if(fs.existsSync(temp))fs.unlinkSync(temp);
    throw error;
  }
  console.log(JSON.stringify({status:'READY_LOCAL',version:manifest.version,changed:true,project,globalConnectionRequired:false,backup:path.relative(project,backupDir)}));
} catch(error) {
  console.error(JSON.stringify({status:'BLOCKED',error:error.message,fallback:'NONE'}));process.exitCode=1;
}
