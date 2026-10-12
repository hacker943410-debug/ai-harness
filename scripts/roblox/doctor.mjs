#!/usr/bin/env node
/** Roblox capability probe: READ ONLY. No provider API calls or Studio edits. */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../..');
const emit=x=>process.stdout.write(JSON.stringify(x,null,2)+'\n');

export function parseMcpRegistry(json){
 let value;
 try{value=typeof json==='string'?JSON.parse(json):json}catch{return {ok:false,registered:false,reason:'INVALID_MCP_JSON',count:0}}
 const entries=Array.isArray(value)?value:Array.isArray(value?.servers)?value.servers:
   Array.isArray(value?.mcp_servers)?value.mcp_servers:
   value&&typeof value==='object'&&value.servers&&typeof value.servers==='object'?
    Object.keys(value.servers).map(name=>({name})):null;
 if(!entries)return {ok:false,registered:false,reason:'UNRECOGNIZED_MCP_REGISTRY',count:0};
 const names=entries.map(x=>typeof x==='string'?x:x?.name||x?.id).filter(x=>typeof x==='string');
 const found=names.filter(x=>x.toLowerCase()==='roblox_studio');
 return {ok:true,registered:found.length===1,duplicate:found.length>1,
   status:found.length===1?'REGISTERED_UNVERIFIED':found.length>1?'DUPLICATE_REGISTRATIONS':'NOT_REGISTERED',
   count:names.length, server_id:found.length?'Roblox_Studio':null};
}
function fixedProbe(command,args){
 // Never pass user-controlled text to shell. Windows Node cannot spawn .cmd shims reliably.
 const cmd=process.platform==='win32'?'cmd.exe':command;
 const argv=process.platform==='win32'?['/d','/s','/c',[command,...args].join(' ')]:args;
 try{
  const p=spawnSync(cmd,argv,{windowsHide:true,encoding:'utf8',timeout:5000,
   maxBuffer:128*1024,env:process.env,shell:false});
  if(p.error)return {ok:false,error:p.error.code||'SPAWN_ERROR'};
  if(p.status!==0)return {ok:false,error:'EXIT_NONZERO',exit_code:p.status};
  return {ok:true,stdout:p.stdout||''};
 }catch(e){return {ok:false,error:e.code||'PROBE_ERROR'}}
}
export function buildDoctorReport({platform=process.platform,localAppData=process.env.LOCALAPPDATA,
  project=process.cwd(),codexResult,toolResults={}}={}){
 const studioLauncher=platform==='win32'&&localAppData?
   path.join(localAppData,'Roblox','mcp.bat'):null;
 const safeProject=path.resolve(project);
 const file=path.join(safeProject,'default.project.json');
 const registry=codexResult?.ok?parseMcpRegistry(codexResult.stdout):
  {ok:false,registered:false,status:'NOT_PROBED',reason:codexResult?.error||'CODEX_NOT_AVAILABLE'};
 let rojoManifest='ABSENT';
 if(fs.existsSync(file)){
  try {const obj=JSON.parse(fs.readFileSync(file,'utf8'));rojoManifest=obj.tree&&obj.name?'PRESENT_VALID_JSON':'INVALID_STRUCTURE';}
  catch{rojoManifest='INVALID_JSON'}
 }
 const binaries={};
 for(const [name,x] of Object.entries(toolResults))binaries[name]=x.ok?'AVAILABLE':'NOT_CONFIRMED';
 const warnings=[];
 if(!registry.registered)warnings.push('Codex MCP registration not confirmed; use official Roblox plugin.');
 if(registry.duplicate)warnings.push('Duplicate Roblox Studio registrations; stop before mutation.');
 if(!studioLauncher)warnings.push('No Windows StudioMCP launcher location inferred; verify official plugin on this OS.');
 else if(!fs.existsSync(studioLauncher))warnings.push('Expected Windows Studio MCP launcher not found at LOCALAPPDATA.');
 return {schema_version:1,scope:'READ_ONLY_LOCAL_DIAGNOSIS',project:safeProject,
  studio_launcher_detected:studioLauncher?fs.existsSync(studioLauncher):'NOT_PROBED',
  platform,plugin_registration:registry,
  studio_connection:'NOT_VERIFIED',studio_session:'NOT_SELECTED',
  tool_schema:'NOT_DISCOVERED',rojo_project:rojoManifest,binaries,
  warnings,
  suggested_next_action:registry.registered?'Use Codex official Roblox Plugin to list Studio windows and verify tool schemas.':'Install/enable the official Roblox Studio Agent Plugin (no automatic changes performed).'};
}
export function runDoctor({project=process.cwd(),probe=fixedProbe}={}){
 const codexResult=probe('codex',['mcp','list','--json']);
 const tools={};
 for(const name of ['rokit','rojo','stylua','selene','lune','wally'])tools[name]=probe(name,['--version']);
 return buildDoctorReport({project,codexResult,toolResults:tools});
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 let project=process.cwd();
 if(process.argv.length>2){
  if(process.argv.length!==4||process.argv[2]!=='--project')throw Error('Usage: node doctor.mjs [--project PATH]');
  project=process.argv[3];
 }
 const report=runDoctor({project});emit(report);
 // Doctor is informative: missing Studio is not a false PASS or a process crash.
}
