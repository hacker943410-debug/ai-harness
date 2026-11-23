import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {portableContext,scopedFingerprint,rootFor,readJson,atomic,json,hash,fileHash,safeText,projectSlot,noLinks,credentialPathName} from './io.mjs';
import {requireOn} from './install.mjs';
import {event,runEvents,projectState,saveProject} from './events.mjs';
import {routeTask} from './harness-engine.mjs';
import {requireLocalExecution,verificationEnvironment} from './execution-boundary.mjs';
import {runVerification} from './verification-process.mjs';
import {redactSecrets} from './secrets.mjs';
export const stages=['analysis','plan','implement','verify','handoff'];
const defaultExclusions=['.git','node_modules','data','.jh-artifacts'];
export function fingerprint(project){
 if(portableContext()){const scoped=scopedFingerprint(project);if(scoped)return scoped;}
 const root=fs.realpathSync(project),rows=[];
 function walk(folder){
  for(const item of fs.readdirSync(folder,{withFileTypes:true})){
   if(defaultExclusions.includes(item.name)||credentialPathName(item.name))continue;
   const full=path.join(folder,item.name);
   if(item.isSymbolicLink())throw Error('PROJECT_LINK_REQUIRES_REVIEW');
   if(item.isDirectory())walk(full);
   else if(item.isFile()){
    if(rows.length>10000)throw Error('PROJECT_TOO_LARGE_NEEDS_TARGETED_VERIFICATION');
    rows.push([path.relative(root,full).replaceAll('\\','/'),fileHash(full)]);
   }
  }
 }
 walk(root);rows.sort((a,b)=>a[0].localeCompare(b[0],'en'));
 return {sha256:hash(JSON.stringify(rows)),files:rows.length,exclusions:[...defaultExclusions,'credential-like filenames']};
}
export function staleVerificationReason(project,verification){
 const portable=portableContext();
 if(portable&&verification.runtimeManifestSha256!==portable.manifestSha256)return 'RUNTIME_CHANGED_PREVIOUS_PASS_INVALID';
 return fingerprint(project).sha256===verification.sourceAfter?null:'CODE_CHANGED_PREVIOUS_PASS_INVALID';
}
function projectMode(project){
 if(portableContext()){
  const modes=[];
  for(const name of ['harness-state.json','harness-project.json']){
   const file=path.join(project,'.ai',name);noLinks(file);if(!fs.existsSync(file))continue;
   const document=JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
   for(const owner of name==='harness-project.json'?[document,document.binding]:[document]){
    if(!owner||!Object.hasOwn(owner,'project_mode'))continue;
    const mode=owner.project_mode;
    if(!['GREENFIELD','MAINTENANCE','HOTFIX','MIGRATION'].includes(mode))throw Error('INVALID_CANONICAL_PROJECT_MODE');
    modes.push(mode);
   }
  }
  if(new Set(modes).size>1)throw Error('CONFLICTING_CANONICAL_PROJECT_MODE');
  if(modes.length)return modes[0];
 }
 return fs.existsSync(path.join(project,'package.json'))||fs.existsSync(path.join(project,'src'))?'MAINTENANCE':'GREENFIELD';
}
export function route(h,project,goal){
 requireOn(h);safeText(goal);
 const mode=projectMode(project);
 const decision=routeTask(goal,{has_product:mode!=='GREENFIELD',project_mode:mode});
 const complex=Number(decision.risk.slice(1))>=3;
 const steps=complex?[
  '목표, 변경 범위, 영향받는 데이터와 권한을 확인하고 수용 기준을 적습니다.',
  '변경 전 상태를 기록하고 설계, 구현, 검증으로 나눕니다.',
  '첫 기능을 작게 구현하고 실패와 복구 흐름을 시험합니다.',
  '테스트 근거와 변경 내용을 별도로 검토하고 결과를 인계합니다.',
 ]:[
  '바꿀 파일과 기대 결과를 확인합니다.',
  '변경을 작게 적용하고 관련 테스트를 실행합니다.',
  '사용 방법과 확인 결과를 알려줍니다.',
 ];
 return {mode,intent:decision.intent,risk:decision.risk,complexity:complex?'COMPLEX':'STANDARD',
  policyIds:[...new Set(['P07',...decision.jit_files.map(file=>file.match(/^policies\/(\d{2})_/))
   .filter(Boolean).map(match=>'P'+match[1])])],
  recommendedModelTier:decision.tier,modelSelection:'ADVISORY_ONLY',
  delegation:complex?{recommendation:'REVIEW_TASKS_FOR_DELEGATION',roles:['Explorer','Builder','Reviewer'],execution:'NOT_DISPATCHED'}
   :{recommendation:'HANDLE_DIRECTLY',roles:[],execution:'NOT_DISPATCHED'},
  recommendedPlan:steps};
}

export function begin(h,project,goal){
 const routing=route(h,project,goal);
 const prior=projectState(h,project);
 if(prior&&!prior.finished)throw Error('ACTIVE_WORKFLOW_EXISTS_USE_PROGRESS_OR_FINISH');
 const state={schema:1,runId:crypto.randomUUID(),project:fs.realpathSync(project),goal,stage:'analysis',mode:routing.mode,
  routing,assumptions:['기존 스택을 보존하고 새 앱은 로컬에서 작게 시작합니다.',
   '외부 설치, 인증정보, 삭제, 비용, 배포는 필요한 승인을 받습니다.'],
  acceptance:['요청 기능이 동작한다','실제 테스트와 오류 수정 결과를 기록한다','초보자용 실행/사용 안내가 있다'],
  plan:[],finished:false,verification:null,modelApplication:'AGENT_EXECUTED_WORKFLOW_NOT_INDEPENDENT_MODEL_OBSERVATION'};
 saveProject(h,project,state);
 event(h,project,'workflow_begin',{runId:state.runId,goal,mode:state.mode,risk:routing.risk});
 return {...state,recommendedPlan:routing.recommendedPlan,next:'policy read P07'};
}
export function advance(h,project,stage,note){
 requireOn(h);
 const state=projectState(h,project);
 if(!state||state.finished)throw Error('ACTIVE_WORKFLOW_REQUIRED');
 const current=stages.indexOf(state.stage),next=stages.indexOf(stage);
 const recovering=state.stage==='verify'&&stage==='implement'&&state.verification?.result==='FAIL';
 if(next<0||next>current+1||(next<current&&!recovering))throw Error('SEQUENTIAL_WORKFLOW_STAGE_REQUIRED');
 if(stage==='plan'){safeText(note??'');state.plan=[note];}
 else if(note?.trim())safeText(note);
 if(stage==='handoff'){
  requireLocalExecution(project);
  if(state.verification?.result!=='PASS')throw Error('REAL_VERIFICATION_REQUIRED_BEFORE_HANDOFF');
  if(portableContext()){
   const stale=staleVerificationReason(project,state.verification);
   if(stale)throw Error(stale);
  }
 }
 state.stage=stage;saveProject(h,project,state);event(h,project,'stage',{stage,note:note??null});return state;
}
export async function verify(h,project,argv,{requireSupervisor=false}={}){
 requireOn(h);
 const boundary=requireLocalExecution(project,requireSupervisor);
 const state=projectState(h,project);
 if(!state||state.finished||stages.indexOf(state.stage)<2)throw Error('PLAN_AND_IMPLEMENT_STAGE_REQUIRED');
 if(!argv.length||argv.some(a=>typeof a!=='string'))throw Error('EXECUTABLE_ARGV_REQUIRED');
 safeText(argv.join(' '));
 const [executable,...args]=argv;
 if(/^(?:rm|del|rmdir|curl|wget|powershell|cmd|npx)(?:\.exe)?$/i.test(path.basename(executable)))throw Error('VERIFIER_EXPECTS_TEST_COMMAND_NOT_ADMIN_OR_DOWNLOAD_SHELL');
 const before=fingerprint(project),id=crypto.randomUUID(),startedUtc=new Date().toISOString(),clock=performance.now();
 const logs=path.join(projectSlot(h,project),'logs');
 const result=await runVerification(executable,args,{project,env:verificationEnvironment(),logs});
 const after=fingerprint(project);
 const stdout=redactSecrets((result.stdout??Buffer.alloc(0)).toString('utf8'));
 const stderr=redactSecrets((result.stderr??Buffer.alloc(0)).toString('utf8'));
 atomic(path.join(logs,id+'.stdout.txt'),stdout);
 atomic(path.join(logs,id+'.stderr.txt'),stderr);
 const sourceChanged=before.sha256!==after.sha256;
 const record={id,runId:state.runId,result:result.status===0&&!result.error&&!sourceChanged?'PASS':'FAIL',
  executable,argumentCount:args.length,executableSha256:fs.existsSync(executable)?fileHash(executable):null,
  exitCode:result.status,error:result.error?.code??null,captureMode:result.captureMode??'PIPE',startedUtc,endedUtc:new Date().toISOString(),
  elapsedMs:performance.now()-clock,sourceBefore:before.sha256,sourceAfter:after.sha256,sourceChanged,
  sourceScope:before,stdoutSha256:hash(stdout),stderrSha256:hash(stderr),logDirectory:logs,
  evidenceScope:'LOCAL_ACTUAL_COMMAND_NOT_OS_TAMPER_PROOF',executionBoundary:boundary.mode,
  runtimeManifestSha256:portableContext()?.manifestSha256??null,
  tokenUsage:{actual:null,estimate:null,reason:'This local command has no provider token telemetry.'}};
 state.stage='verify';state.verification=record;saveProject(h,project,state);event(h,project,'verification',record);
 // Preserve immediate argv feedback for existing callers. Durable evidence omits raw arguments.
 return {...record,arguments:args.map(redactSecrets),stdoutTail:stdout.slice(-2000),stderrTail:stderr.slice(-2000)};
}
export function policy(h,project,id,{full=false}={}){requireOn(h);if(!/^P\d{2}$/.test(id))throw Error('POLICY_ID_REQUIRED');const root=path.join(rootFor(h),'runtime'),name=fs.readdirSync(path.join(root,'policies')).find(n=>n.startsWith(id.slice(1)+'_'));if(!name)throw Error('POLICY_NOT_FOUND');const file=path.join(root,'policies',name),notes=readJson(path.join(root,'core/knowledge/policy-notes.json'));const content=full?fs.readFileSync(file,'utf8'):notes[id];if(!content)throw Error('NO_CURATED_NOTE_USE_EXPLICIT_FULL_SOURCE');return{id,queryOnly:true,source:file,sourceSha256:fileHash(file),kind:full?'ORIGINAL_V7_SOURCE':'CURATED_GUIDANCE_WITH_ORIGINAL_REFERENCE',content,tokenEstimate:{kind:'ESTIMATE_NOT_PROVIDER_USAGE',formula:'UTF-8 bytes / 4 (rough; Korean/code varies)',value:Math.ceil(Buffer.byteLength(content)/4)}};}
export function finish(h,project,guide){
 requireOn(h);requireLocalExecution(project);
 const state=projectState(h,project);
 if(!state||state.finished||state.stage!=='handoff'||!state.plan.length||state.verification?.result!=='PASS')throw Error('PLANNED_VERIFIED_HANDOFF_REQUIRED');
 const stale=staleVerificationReason(project,state.verification);
 if(stale)throw Error(stale);
 if(!guide||path.isAbsolute(guide)||guide.split(/[\\/]/).includes('..'))throw Error('PROJECT_RELATIVE_GUIDE_REQUIRED');
 const file=path.join(project,guide);noLinks(file);
 if(!fs.existsSync(file)||!fs.statSync(file).isFile()||fs.statSync(file).size<80)throw Error('USABLE_GUIDE_REQUIRED');
 state.finished=true;state.guide=guide;state.result='COMPLETE_LOCAL_VERIFIED';
 state.releaseReadiness='INDEPENDENT_REVIEW_NOT_ATTESTED';
 state.notRun=['REAL_CODEX_MODEL_TEST','BROWSER_INTERACTION_UNLESS_SEPARATELY_RECORDED','DEPLOYMENT'];
 saveProject(h,project,state);event(h,project,'handoff',{guide,sha256:fileHash(file),result:state.result});
 const history=runEvents(h,project,state.runId);
 return {...state,appliedPolicies:history.filter(e=>e.kind.startsWith('policy_')).map(e=>({id:e.id,kind:e.kind})),
  skills:history.filter(e=>e.kind==='skill_result')};
}
export function learn(h,project,cause,fix){requireOn(h);safeText(cause);safeText(fix);const s=projectState(h,project);if(s?.verification?.result!=='PASS'||!runEvents(h,project,s.runId).some(e=>e.kind==='verification'&&e.result==='FAIL'))throw Error('FAILED_REPRO_AND_SUCCESSFUL_RECHECK_REQUIRED');if(staleVerificationReason(project,s.verification))throw Error('STALE_VERIFICATION');const file=path.join(projectSlot(h,project),'lessons.json'),rows=readJson(file,[]),row={id:crypto.randomUUID(),runId:s.runId,cause,fix,verificationId:s.verification.id,sourceHash:s.verification.sourceAfter,scope:'VERIFIED_LOCAL_CASE_NOT_UNIVERSAL_RULE',utc:new Date().toISOString()};rows.push(row);atomic(file,json(rows));return row;}

export function lessons(h,project,query=''){return [...(!portableContext()?readJson(path.join(rootFor(h),'lessons.json'),[]):[]),...readJson(path.join(projectSlot(h,project),'lessons.json'),[])].filter(x=>JSON.stringify(x).toLowerCase().includes(query.toLowerCase()));}
