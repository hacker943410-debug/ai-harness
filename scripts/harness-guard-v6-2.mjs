#!/usr/bin/env node
/** v6.2 managed Codex execution; DOES NOT intercept ordinary interactive sessions. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const ownFile=fileURLToPath(import.meta.url);
const root=path.resolve(path.dirname(ownFile),'..');
const newid=()=>new Date().toISOString().replace(/[:.]/g,'-')+'-'+crypto.randomBytes(4).toString('hex');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const valid=n=>Number.isSafeInteger(n)&&n>=0;
function safe(base,rel){
 if(!rel||path.isAbsolute(rel)||rel.split(/[\\/]/).includes('..'))throw Error('UNSAFE_FILE_PATH');
 const r=path.resolve(base),p=path.resolve(r,rel);
 if(!p.startsWith(r+path.sep))throw Error('PATH_OUTSIDE_PROJECT');
 let cursor=r;
 for(const segment of path.relative(r,p).split(path.sep)){
  cursor=path.join(cursor,segment);
  if(fs.existsSync(cursor)&&fs.lstatSync(cursor).isSymbolicLink())throw Error('SYMLINK_PATH_REFUSED');
 }
 return p;
}
function save(p,data){
 fs.mkdirSync(path.dirname(p),{recursive:true});
 const temp=p+'.'+process.pid+'.tmp';
 try{fs.writeFileSync(temp,JSON.stringify(data,null,2)+'\n',{flag:'wx',mode:0o600});fs.renameSync(temp,p);}
 finally{if(fs.existsSync(temp))fs.rmSync(temp);}
}
export function extractUsage(evt){
 if(!evt||evt.type!=='turn.completed')return null;
 const u=evt.usage;
 if(!u||!valid(u.input_tokens)||!valid(u.output_tokens))return null;
 return {input_tokens:u.input_tokens,output_tokens:u.output_tokens,
  cached_input_tokens:valid(u.cached_input_tokens)?u.cached_input_tokens:null,
  total_tokens:u.input_tokens+u.output_tokens};
}
export function budgetDecision(tokens,soft,hard){
 if(tokens===null)return {action:'UNKNOWN',reason:'No actual Codex usage received'};
 if(!valid(soft)||!valid(hard)||soft<1||hard<=soft)return {action:'UNCONFIGURED'};
 return {action:tokens>=hard?'CHECKPOINT_REQUIRED':tokens>=soft?'COMPACT_NEXT_TURN':'CONTINUE',
  reason:'Measured completed-turn token usage'};
}
export function summarizeJsonl(content){
 const out={events:0,turns:0,usage_events:0,actual_usage:null,errors:0,parse_errors:0};
 const total={input_tokens:0,output_tokens:0,cached_input_tokens:0,total_tokens:0};
 for(const line of String(content).split(/\r?\n/)){
  if(!line.trim())continue;
  let event;try{event=JSON.parse(line)}catch{out.parse_errors++;continue}
  out.events++;
  if(event.type==='turn.failed'||event.type==='error')out.errors++;
  if(event.type==='turn.completed'){
   out.turns++;const u=extractUsage(event);
   if(u){
    out.usage_events++;
    for(const k of ['input_tokens','output_tokens','total_tokens'])total[k]+=u[k];
    if(u.cached_input_tokens!==null)total.cached_input_tokens+=u.cached_input_tokens;
   }
  }
 }
 if(out.usage_events)out.actual_usage=total;
 return out;
}
function argsParse(argv){
 const [command,...items]=argv,o={};
 for(let i=0;i<items.length;i++){
  const key=items[i];
  if(!/^--[a-z-]+$/.test(key)||!items[i+1]||items[i+1].startsWith('--'))throw Error('EXPECTED_FLAG_AND_VALUE');
  if(Object.hasOwn(o,key.slice(2)))throw Error('DUPLICATE_FLAG');
  o[key.slice(2)]=items[++i];
 }
 return {command,o};
}
async function readiness(project,request){
 const {inspectProject,sourceIdentity}=await import('./harness-project.mjs');
 const {routeTask}=await import('./harness-engine.mjs');
 const info=inspectProject(project,root),config=read(safe(project,'.ai/harness-project.json'));
 if(!config.harness?.root)throw Error('HARNESS_NOT_BOUND');
 if(path.resolve(config.harness.root)!==root)throw Error('WRONG_PINNED_ROOT');
 if(info.pinned_source_status!=='PASS')throw Error('PINNED_SOURCE_DRIFT');
 if(info.installed_version!==sourceIdentity(root).version)throw Error('HARNESS_VERSION_MISMATCH');
 const route=routeTask(request,info);
 if(route.timing==='DEFERRED')throw Error('UNSAFE_ACTIVE_OPERATION');
 if(info.development_state==='FROZEN_FOR_MIGRATION'&&route.intent==='development')throw Error('MIGRATION_FREEZE');
 for(const rel of route.jit_files)if(!fs.existsSync(safe(root,rel)))throw Error('MISSING_JIT_POLICY');
 return {info,config,route};
}
async function verify(project){
 const {verifyProject}=await import('./harness-project.mjs');
 return verifyProject(project);
}
function managedPrompt(request,route){
 return ['AI HARNESS GUARDED RUN. Follow current project AGENTS.md and .ai/HARNESS.md.',
 'JIT policy references (read only the relevant pinned files before changing code):',
 ...route.jit_files.map(x=>'- '+x),
 'Project mode='+route.project_mode+'; risk='+route.risk+'; model tier ADVISORY='+route.tier+'.',
 'Set acceptance first, preserve local rules, record independent review and actual verification.',
 'External guard verifies completion. Do not claim a successful test without running it.',
 'USER REQUEST:',request].join('\n');
}
function runCodex(project,request,binary){
 return new Promise((done,fail)=>{
  const child=spawn(binary,['exec','--json',request],{cwd:project,env:process.env,shell:false,windowsHide:true,
   stdio:['ignore','pipe','pipe']});
  let buffer='',overflow=false,stderr_bytes=0;
  child.stdout.setEncoding('utf8');
  child.stdout.on('data',chunk=>{if(buffer.length+chunk.length<12000000)buffer+=chunk;else overflow=true;});
  child.stderr.on('data',chunk=>{stderr_bytes+=chunk.length;});
  child.on('error',fail);
  child.on('close',(exit_code,signal)=>done({exit_code,signal,summary:summarizeJsonl(buffer),overflow,stderr_bytes}));
 });
}
const output=x=>process.stdout.write(JSON.stringify(x,null,2)+'\n');
export async function main(argv=process.argv.slice(2)){
 const {command,o}=argsParse(argv);
 if(!['preflight','run','verify','report'].includes(command))throw Error('Use preflight, run, verify or report');
 if(!o.project)throw Error('--project required');
 const project=fs.realpathSync(o.project);
 if(command==='verify'){const result=await verify(project);output(result);return result.status==='PASS'?0:2;}
 if(command==='report'){
  const f=safe(project,'.ai/harness-guard/latest.json');
  if(!fs.existsSync(f))throw Error('NO_GUARD_EVIDENCE');
  output(read(f));return 0;
 }
 if(!o.request)throw Error('--request required');
 const ready=await readiness(project,o.request);
 const budgetSettings=ready.config.guard_v6_2?.token_budget||{};
 const soft=o['soft-limit']===undefined?budgetSettings.soft_limit:Number(o['soft-limit']);
 const hard=o['hard-limit']===undefined?budgetSettings.hard_limit:Number(o['hard-limit']);
 const budgetConfigured=valid(soft)&&valid(hard)&&soft>0&&hard>soft;
 if(command==='preflight'){
  output({status:'PREFLIGHT_PASS',version:ready.info.installed_version,mode:ready.route.project_mode,
   state:ready.info.development_state,planned_jit_files:ready.route.jit_files,actual_reads:'UNOBSERVED',
   recommended_tier:ready.route.tier,model_enforced:false,
   token_budget:budgetConfigured?{soft,hard}:'UNCONFIGURED',
   scope:'Only guarded codex exec; interactive use is not intercepted'});
  return 0;
 }
 if(!budgetConfigured)throw Error('TOKEN_BUDGET_UNCONFIGURED: set guard_v6_2.token_budget or explicit limits');
 if(process.platform==='win32' && /\.cmd$/i.test(o['codex-bin']||''))throw Error('WINDOWS_CMD_SHIM_UNVERIFIED: pass the trusted codex.exe path with --codex-bin');
 const latest=safe(project,'.ai/harness-guard/latest.json');
 if(fs.existsSync(latest)&&read(latest).budget?.action==='CHECKPOINT_REQUIRED'&&!o['checkpoint-evidence'])
  throw Error('PREVIOUS_HARD_BUDGET_REQUIRES_CHECKPOINT');
 let checkpoint=false;
 if(o['checkpoint-evidence']){
  const f=safe(project,o['checkpoint-evidence']);
  if(!fs.existsSync(f)||!fs.statSync(f).isFile())throw Error('CHECKPOINT_EVIDENCE_MISSING');
  const proof=read(f);
  const prior=fs.existsSync(latest)?read(latest):null;
  if(proof.kind!=='harness-budget-checkpoint'||proof.previous_run_id!==prior?.run_id||
   proof.source_hash!==ready.config.harness.source_hash||
   !['goal','current_phase','next_task'].every(k=>typeof proof[k]==='string'&&proof[k].trim().length>0)||
   !Array.isArray(proof.acceptance_criteria)||proof.acceptance_criteria.length===0)
    throw Error('INVALID_CHECKPOINT_CONTRACT: require previous_run_id, pinned hash, goal, phase, acceptance and next task');
  checkpoint=true;
 }
 const started=Date.now(),run_id=newid();
 const execution=await runCodex(project,managedPrompt(o.request,ready.route),o['codex-bin']||'codex');
 const tokens=execution.summary.actual_usage?.total_tokens??null;
 const budget=budgetDecision(tokens,soft,hard);
 const eventHealthy=execution.exit_code===0&&!execution.signal&&!execution.overflow&&execution.summary.turns>0
   &&execution.summary.errors===0&&execution.summary.parse_errors===0;
 const verification=eventHealthy?await verify(project).catch(e=>({status:'FAIL',error:e.message})):
  {status:'NOT_RUN',reason:'Codex execution or JSONL event stream failed'};
 const status=eventHealthy&&verification.status==='PASS'&&tokens!==null?'PASS':'FAIL';
 const report={schema_version:1,run_id,timestamp:new Date().toISOString(),duration_ms:Date.now()-started,
  status,harness_version:ready.info.installed_version,source_hash:ready.config.harness.source_hash,
  project_mode:ready.route.project_mode,route:{intent:ready.route.intent,tier:ready.route.tier,
   reasoning:ready.route.reasoning,jit_files:ready.route.jit_files},
  policy_delivery:'REFERENCES_NOT_ATTESTED',actual_agent_policy_reads:'UNOBSERVED',actual_model:'UNKNOWN',
  codex:{exit_code:execution.exit_code,signal:execution.signal,turns:execution.summary.turns,
   events:execution.summary.events,errors:execution.summary.errors,
   parse_errors:execution.summary.parse_errors,output_overflow:execution.overflow},
  token_usage:execution.summary.actual_usage,token_measurement:tokens===null?'UNKNOWN_NO_PROVIDER_USAGE_FAIL_CLOSED':'CODEX_TURN_COMPLETED',
  budget,checkpoint_validated:checkpoint,verification,
  enforcement_scope:'GUARDED_EXEC_ONLY',interactive_enforcement:'NOT_INSTALLED',
  limitations:['Cannot retroactively intercept interactive Codex','Budget evaluated after completed turns',
   'JIT file reads are not attested by the agent event stream']};
 save(safe(project,'.ai/harness-guard/runs/'+run_id+'.json'),report);
 save(latest,report);
 output(report);
 return status==='PASS'?0:2;
}
if(process.argv[1]&&path.resolve(process.argv[1])===ownFile){
 main().then(x=>{process.exitCode=x}).catch(e=>{
  output({status:'BLOCKED',reason:e.message,scope:'GUARDED_EXEC_ONLY'});process.exitCode=2;
 });
}
