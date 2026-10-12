#!/usr/bin/env node
/** Roblox project checks: static by default, external tools only with --run-tools.
 * Does not open Studio or perform any network/asset publishing.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const emit=x=>process.stdout.write(JSON.stringify(x,null,2)+'\n');
function checkManifest(project){
 const file=path.join(project,'default.project.json');
 if(!fs.existsSync(file))return {ok:false,error:'MISSING_ROJO_MANIFEST'};
 let o;try{o=JSON.parse(fs.readFileSync(file,'utf8'))}catch{return {ok:false,error:'INVALID_ROJO_JSON'}}
 const tree=o.tree;
 if(!tree||tree.$className!=='DataModel')return {ok:false,error:'ROJO_TREE_INVALID'};
 const mapped=[];
 function walk(n){if(!n||typeof n!=='object')return;
  for(const [k,v] of Object.entries(n)){
   if(k==='$path'){
    if(typeof v!=='string'||path.isAbsolute(v)||v.split(/[\\/]/).includes('..'))return mapped.push({path:v,status:'INVALID'});
    const f=path.resolve(project,v);mapped.push({path:v,status:fs.existsSync(f)?'EXISTS':'MISSING'});continue;
   }
   if(typeof v==='object'&&v!==null)walk(v);
  }
 }
 walk(tree);
 return {ok:mapped.length>=3&&mapped.every(x=>x.status==='EXISTS'),mapped,error:null};
}
export function inspectRobloxProject(project){
 if(!fs.existsSync(project)||!fs.statSync(project).isDirectory())return {status:'FAIL',errors:['PROJECT_NOT_FOUND']};
 const root=fs.realpathSync(project),manifest=checkManifest(root),errors=[];
 if(!manifest.ok)errors.push(manifest.error||'MAPPING_NOT_FOUND');
 const rokit=path.join(root,'rokit.toml');
 if(!fs.existsSync(rokit))errors.push('MISSING_TOOL_PINS');
 else {
  const text=fs.readFileSync(rokit,'utf8');
  for(const name of ['rojo','selene','stylua','wally','lune'])
   if(!new RegExp('^'+name+'\\s*=\\s*"[^"]+@[^"]+"','mi').test(text))errors.push('MISSING_PIN_'+name.toUpperCase());
 }
 const generated=path.join(root,'src');
 if(!fs.existsSync(generated))errors.push('MISSING_SRC');
 return {status:errors.length?'FAIL':'PASS_STATIC_ONLY',errors,rojo:manifest,
  external_build:'NOT_RUN',studio_playtest:'NOT_RUN',data_integrity:'NOT_RUN',
  release_approved:false};
}
function runTool(binary,args,cwd){
 try{const p=spawnSync(binary,args,{cwd,encoding:'utf8',timeout:45000,maxBuffer:256*1024,windowsHide:true,shell:false});
  if(p.error)return {status:'NOT_RUN',error:p.error.code||'SPAWN_FAILED'};
  return {status:p.status===0?'PASS':'FAIL',exit_code:p.status,signal:p.signal||null};
 }catch(e){return {status:'NOT_RUN',error:e.code||'EXECUTION_FAILED'}}
}
export function verifyRobloxProject(project,{runTools=false,runner=runTool}={}){
 const staticResult=inspectRobloxProject(project);
 if(staticResult.status!=='PASS_STATIC_ONLY'||!runTools)return staticResult;
 const root=fs.realpathSync(project);
 const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'roblox-v7-build-'));
 let steps;
 try {
  steps={
   stylua:runner('stylua',['--check','src'],root),
   selene:runner('selene',['src'],root),
   rojo:runner('rojo',['build','default.project.json','-o',path.join(temporary,'place.rbxlx')],root)
  };
 }finally{fs.rmSync(temporary,{recursive:true,force:true});}
 const statuses=Object.values(steps).map(x=>x.status);
 return {...staticResult,external_build:statuses.every(x=>x==='PASS')?'PASS':
  statuses.includes('FAIL')?'FAIL':'NOT_RUN',
  status:statuses.includes('FAIL')?'FAIL':
   statuses.every(x=>x==='PASS')?'PASS_LOCAL_TOOLS_ONLY':'NOT_RUN',
  tool_results:steps};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 if(args.length<2||args[0]!=='--project'||args.length>3||(args.length===3&&args[2]!=='--run-tools'))
  throw Error('Usage: node verify-project.mjs --project PATH [--run-tools]');
 const r=verifyRobloxProject(args[1],{runTools:args.includes('--run-tools')});emit(r);
 if(r.status==='FAIL')process.exitCode=2;
}
