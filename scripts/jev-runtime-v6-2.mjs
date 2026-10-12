#!/usr/bin/env node
/**
 * Jev opt-in project integration for AI Harness v6.2.
 * Credentials are provided by AI_GATEWAY_API_KEY in the process environment.
 * Never persist keys or user task text. Shadow never changes deterministic routes.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {evaluateJevDecision} from './jev-decision.mjs';

const ownFile=fileURLToPath(import.meta.url);
const isDirect=()=>process.argv[1] && path.resolve(process.argv[1])===ownFile;
const root=path.resolve(path.dirname(ownFile),'..');
const CONFIG='.ai/harness-project.json';
const MODEL='typesafe-ai/jev';
const PROVIDER='vercel_ai_gateway';
const pretty=x=>JSON.stringify(x,null,2)+'\n';
const keyPresent=()=>Boolean((process.env.AI_GATEWAY_API_KEY||'').trim());

function localFile(project){
  const dir=fs.realpathSync(project);
  const ai=path.join(dir,'.ai');
  const target=path.join(ai,'harness-project.json');
  if(!fs.existsSync(ai)||fs.lstatSync(ai).isSymbolicLink()||
     !fs.existsSync(target)||fs.lstatSync(target).isSymbolicLink()||
     !fs.statSync(target).isFile())throw Error('PROJECT_HARNESS_CONFIG_NOT_FOUND_OR_UNSAFE');
  return target;
}
function readConfig(project){
  return JSON.parse(fs.readFileSync(localFile(project),'utf8').replace(/^\uFEFF/,''));
}
function writeConfig(project,config){
  const target=localFile(project);
  const before=readConfig(project);
  if(!before.harness?.root||!before.harness?.version)throw Error('HARNESS_BINDING_REQUIRED');
  // Avoid modifying unrelated config values or committing secrets.
  const raw=pretty(config);
  if(/(?:sk-[A-Za-z0-9]{20,}|jv_live_[A-Za-z0-9]+)/.test(raw))throw Error('CREDENTIAL_IN_CONFIG_REFUSED');
  const tmp=target+'.jev-'+process.pid+'.tmp';
  try{
    fs.writeFileSync(tmp,raw,{flag:'wx',mode:0o600});
    fs.renameSync(tmp,target);
  } finally{if(fs.existsSync(tmp))fs.rmSync(tmp);}
}
export function statusFor(config,env=process.env){
  const enabled=config?.decision_engine?.enabled===true;
  const mode=config?.decision_engine?.mode??'shadow';
  const credential=Boolean((env.AI_GATEWAY_API_KEY||'').trim());
  return {
    engine:'jev',provider:PROVIDER,model:MODEL,credential_present:credential,
    configured:enabled,mode:enabled?mode:'disabled',
    status:!credential?'MISSING_API_KEY':!enabled?'READY_NOT_ACTIVATED':
      mode!=='shadow'?'UNSUPPORTED_MODE': 'SHADOW_READY',
    normal_codex_interactive:'NOT_INSTRUMENTED',
    guard_integration:'GUARDED_EXEC_ONLY',
    network_test:'NOT_RUN'
  };
}
function canUse(route,info){
  return route?.intent==='development' &&
   ['R0','R1','R2'].includes(route?.risk) &&
   ['GREENFIELD','MAINTENANCE'].includes(route?.project_mode) &&
   info?.production!==true && info?.development_state!=='FROZEN_FOR_MIGRATION';
}
export function makeShadowRequest(route,info={}){
  if(!canUse(route,info))return null;
  // Only coarse, predeclared values. No user input, paths, filenames or credentials.
  const tier=['economy','balanced','frontier'].includes(route.tier)?route.tier:'balanced';
  return {
    decision_type:'task_route',data_classification:'non_sensitive',
    state:'Synthetic developer routing metadata: mode='+route.project_mode+
      '; risk='+route.risk+'; phase_profile='+(
      ['GREENFIELD_CONTEXT','MAINTENANCE_DELTA','HOTFIX_CRITICAL','MIGRATION_COMPATIBILITY']
        .includes(route.context_profile)?route.context_profile:'UNKNOWN')+
      '. Select a cost-aware model tier; this is not a security approval.',
    existing_route:tier,
    questions:{
      tier:{
        type:'choice',
        instructions:'Choose the lowest capable tier from task risk and context profile. Security, verification and human decisions remain governed by the main Harness.',
        criteria:{
          economy:'Simple bounded mechanical work with no complex dependencies',
          balanced:'Normal product implementation or moderate debugging',
          frontier:'Complex/high-risk reasoning and critical review'
        }
      }
    }
  };
}
export async function shadowFor(config,route,info={},evaluate=evaluateJevDecision){
  const configured=statusFor(config);
  if(configured.status!=='SHADOW_READY')
    return {status:configured.status,used:false,fallback:true,route_changed:false};
  const req=makeShadowRequest(route,info);
  if(!req)return {status:'SKIPPED_BY_POLICY',used:false,fallback:true,route_changed:false};
  try{
    const res=await evaluate(req);
    return {
      status:res.ok?'SHADOW_OBSERVED':'FALLBACK',
      used:true,fallback:!res.ok,route_changed:false,
      agreement:res.ok?res.agreement:null,
      suggested_tier:res.ok?res.answers?.tier?.choice??null:null,
      deterministic_tier:route.tier,
      error_type:res.ok?null:res.error_type||'PROVIDER_FAILURE',
      latency_ms:Number.isFinite(res.latency_ms)?res.latency_ms:null,
      usage:res.ok?res.usage??null:null,
      provider:PROVIDER,model:MODEL,
      data_scope:'SYNTHETIC_ENUM_METADATA_ONLY'
    };
  } catch {
    return {status:'FALLBACK',used:true,fallback:true,route_changed:false,error_type:'PROVIDER_EXCEPTION'};
  }
}
const CANARY={
  decision_type:'task_route',data_classification:'non_sensitive',
  state:'Synthetic canary: a small deterministic formatting task, no user data.',
  existing_route:'economy',
  questions:{
    tier:{
      type:'choice',
      instructions:'For this simple low-risk formatting task, choose the smallest sufficient model tier.',
      criteria:{economy:'Fast low cost',balanced:'Standard',frontier:'Complex high-risk'}
    }
  }
};
export async function liveCanary(evaluate=evaluateJevDecision){
  if(!keyPresent())return {status:'MISSING_API_KEY',ok:false,network_test:'NOT_RUN'};
  try{
    const result=await evaluate(CANARY);
    return {status:result.ok?'CANARY_PASS':'CANARY_FAILED',ok:result.ok,
      network_test:'LIVE_PROVIDER',error_type:result.ok?null:result.error_type??'UNKNOWN',
      model:MODEL,usage:result.ok?result.usage??null:null,
      latency_ms:result.latency_ms??null,
      // Do not claim semantic accuracy from one valid typed response.
      agreement:result.ok?result.agreement:null,
      data_scope:'SYNTHETIC_INPUT_ONLY'};
  }catch{return {status:'CANARY_FAILED',ok:false,network_test:'LIVE_PROVIDER',error_type:'PROVIDER_EXCEPTION'};}
}
function parseArgs(argv){
  const [cmd,...flags]=argv,options={};
  for(let i=0;i<flags.length;i++){
    if(!/^--[a-z-]+$/.test(flags[i])||!flags[i+1]||flags[i+1].startsWith('--'))
      throw Error('FLAG_VALUE_PAIR_REQUIRED');
    options[flags[i].slice(2)]=flags[++i];
  }
  return {cmd,options};
}
export async function main(argv=process.argv.slice(2),evaluate=evaluateJevDecision){
  const {cmd,options}=parseArgs(argv);
  if(!['status','activate','disable','canary'].includes(cmd))throw Error('Use status, activate, disable or canary');
  if(!options.project)throw Error('--project required');
  const project=fs.realpathSync(options.project);
  const config=readConfig(project);
  if(cmd==='status')return statusFor(config);
  if(cmd==='disable'){
    config.decision_engine={...config.decision_engine,engine:'jev',enabled:false,mode:'shadow'};
    writeConfig(project,config);
    return {status:'DISABLED',credential_present:keyPresent(),route_changed:false};
  }
  if(options.live!=='true')throw Error('LIVE_PROVIDER_CONFIRMATION_REQUIRED: use --live true');
  const canary=await liveCanary(evaluate);
  if(cmd==='canary')return canary;
  if(!canary.ok)return {...canary,activation:'BLOCKED'};
  config.decision_engine={...config.decision_engine,engine:'jev',enabled:true,mode:'shadow',
    provider:PROVIDER,model:MODEL,credential_env:'AI_GATEWAY_API_KEY',fallback:'existing_router',
    data_policy:'non_sensitive_only',auto_accept:'DISABLED_UNTIL_CALIBRATED'};
  writeConfig(project,config);
  return {status:'ACTIVATED_SHADOW',mode:'shadow',network_test:canary.network_test,
    canary:{status:canary.status,usage:canary.usage,agreement:canary.agreement},
    credential_saved:false,interactive_enforcement:'NOT_INSTALLED'};
}
if(isDirect()){
  main().then(r=>{process.stdout.write(pretty(r));
    if(['CANARY_FAILED','MISSING_API_KEY','UNSUPPORTED_MODE'].includes(r.status)||r.activation==='BLOCKED')process.exitCode=2;
  }).catch(e=>{process.stdout.write(pretty({status:'BLOCKED',error:e.message}));process.exitCode=2;});
}
