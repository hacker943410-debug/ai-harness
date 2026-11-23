import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import childProcess,{spawnSync} from 'node:child_process';
import {syncBuiltinESMExports} from 'node:module';
import {materializeRuntime} from '../portable/build-runtime.mjs';
import {buildManifest,sha256} from '../portable/lib/portable-context.mjs';
import {version} from '../lib/io.mjs';
import {runVerification} from '../lib/verification-process.mjs';

test('Windows pipe setup errors recover with bounded stdout and stderr', {skip:process.platform!=='win32'},async t=>{
 const project=fs.mkdtempSync(path.join(os.tmpdir(),'jh-verify-capture-'));
 const logs=path.join(project,'logs');
 const original=childProcess.spawnSync;
 const simulatedPipeFailure=t.mock.method(childProcess,'spawnSync',()=>({pid:0,status:null,error:{code:'EPERM'}}));
 syncBuiltinESMExports();
 t.after(()=>{
  simulatedPipeFailure.mock.restore();
  syncBuiltinESMExports();
  assert.equal(childProcess.spawnSync,original);
  if(fs.existsSync(logs))fs.rmdirSync(logs);
  fs.rmdirSync(project);
 });

 const execute=code=>runVerification(process.execPath,['-e',code],{project,logs,env:process.env});
 const failed=await execute("console.log('out'); console.error('err'); process.exit(7);");
 assert.equal(failed.captureMode,'UNLINKED_FILES');
 assert.equal(failed.status,7);
 assert.equal(failed.stdout.toString(),'out\n');
 assert.equal(failed.stderr.toString(),'err\n');
 assert.deepEqual(fs.readdirSync(logs),[]);
 const oversized=await execute('process.stdout.write(Buffer.alloc(4*1024*1024+1));');
 assert.equal(oversized.error.code,'ENOBUFS');
 assert.equal(oversized.stdout.length,4*1024*1024);
 assert.deepEqual(fs.readdirSync(logs),[]);
});
function copy(source,target){const stat=fs.statSync(source);if(stat.isDirectory()){fs.mkdirSync(target,{recursive:true});for(const name of fs.readdirSync(source))copy(path.join(source,name),path.join(target,name));}else fs.copyFileSync(source,target);}
test('portable Core operates without global installation and refuses damaged evidence',async t=>{
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'jh-portable-'));
 const runtime=path.join(temp,'실행 환경'),project=path.join(temp,'프로젝트 one'),sentinel=path.join(temp,'unavailable-home');
 materializeRuntime(runtime);fs.mkdirSync(project);fs.writeFileSync(sentinel,'GLOBAL SENTINEL unchanged');
 const env={...process.env,PATH:'',CODEX_HOME:sentinel,HOME:sentinel,USERPROFILE:sentinel,JH_FIXTURE_PRIVATE:'never pass this to a test command'};
 const writeManifest=()=>fs.writeFileSync(path.join(runtime,'manifest.json'),JSON.stringify(buildManifest(runtime),null,2));writeManifest();
 const original=fs.readFileSync(sentinel);
 function run(args,expected=0,selectedProject=project,selectedRuntime=runtime,environment=env){const r=spawnSync(process.execPath,[path.join(selectedRuntime,'portable.mjs'),'--project',selectedProject,...args],{env:environment,encoding:'utf8',windowsHide:true});assert.equal(r.status,expected,JSON.stringify({args,...r}));return r.stdout+r.stderr;}
 const json=args=>JSON.parse(run(args));
 function binding(scope){fs.mkdirSync(path.join(project,'.ai'),{recursive:true});fs.writeFileSync(path.join(project,'.ai/harness-project.json'),JSON.stringify(scope));}
 try{
 await t.test('materializer refuses overwrite and setup preserves guidance without a global home',()=>{
  assert.throws(()=>materializeRuntime(runtime),/NEW_OUTPUT/);
  assert.throws(()=>materializeRuntime(path.join(temp,'untrusted-runtime'),{nodeBinary:sentinel,nodeLicense:sentinel}),/UNTRUSTED_NODE/);
  assert.equal(fs.existsSync(path.join(temp,'untrusted-runtime')),false);
  const selected=path.join(temp,'setup project');fs.mkdirSync(selected);
  const installed=path.join(selected,'.agents/j-harness');materializeRuntime(installed);
  const agents=path.join(selected,'AGENTS.md'),bytes=Buffer.from('User guidance: preserve these bytes.\r\n');fs.writeFileSync(agents,bytes);
  const setup=()=>spawnSync(process.execPath,[path.join(installed,'setup.mjs'),'--project',selected],{env,encoding:'utf8',windowsHide:true});
  const first=setup();assert.equal(first.status,0,first.stderr);assert.equal(JSON.parse(first.stdout).changed,true);
  const after=fs.readFileSync(agents);assert.deepEqual(after.subarray(0,bytes.length),bytes);
  const bindingFile=path.join(selected,'.ai/harness-project.json'),bindingBefore=fs.readFileSync(bindingFile);
  const second=setup();assert.equal(second.status,0,second.stderr);assert.equal(JSON.parse(second.stdout).changed,false);assert.deepEqual(fs.readFileSync(agents),after);assert.deepEqual(fs.readFileSync(bindingFile),bindingBefore);
  assert.equal(JSON.parse(run(['status'],0,selected,installed)).effective,'READY_LOCAL');
  const missing=run(['quickstart','--client','claude'],0,selected,installed);
  assert.match(missing,/https:\/\/code\.claude\.com\/docs\/en\/quickstart/);
  const bin=path.join(temp,'cli bin');fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin,process.platform==='win32'?'claude.exe':'claude'),'DISCOVERY ONLY');
  const onboarding=args=>run(args,0,selected,installed,{...env,PATH:bin});
  const clientState=()=>JSON.parse(onboarding(['doctor'])).clientSelection;
  const preference=path.join(selected,'.jh-artifacts/j-harness-core/client-selection.json');
  const choiceMenu=onboarding(['quickstart']);
  assert.match(choiceMenu,/Claude Code \(실행 파일 발견\).*select claude/);
  assert.match(choiceMenu,/Codex \(설치 안내 제공\).*select codex/);
  assert.match(choiceMenu,/select agy/);
  assert.ok(choiceMenu.indexOf('select claude')<choiceMenu.indexOf('select codex'));
  assert.equal(fs.existsSync(preference),false);
  assert.deepEqual(clientState(),{state:'UNSELECTED',client:null});
  const available=onboarding(['select','claude']);
  assert.deepEqual(clientState(),{state:'SELECTED',client:'claude'});
  assert.match(available,/claude --version/);
  assert.match(available,/AGENTS\.md/);
  assert.doesNotMatch(available,/codex --version|Supervisor/i);
  assert.match(available,/connect claude/);
  fs.writeFileSync(path.join(bin,process.platform==='win32'?'codex.exe':'codex'),'DISCOVERY ONLY');
  assert.match(onboarding(['quickstart']),/claude --version/);
  assert.match(onboarding(['quickstart','--client','codex']),/codex --version/);
  assert.deepEqual(clientState(),{state:'SELECTED',client:'claude'});
  assert.match(onboarding(['select','agy']),/https:\/\/antigravity\.google/);
  assert.match(onboarding(['quickstart']),/https:\/\/antigravity\.google/);
  assert.deepEqual(clientState(),{state:'SELECTED',client:'agy'});
  assert.match(run(['select','unknown'],1,selected,installed),/UNKNOWN_CLIENT/);
  assert.deepEqual(clientState(),{state:'SELECTED',client:'agy'});
  fs.writeFileSync(preference,'{damaged preference');
  assert.equal(clientState().state,'REVIEW_REQUIRED');
  assert.match(onboarding(['quickstart']),/다시 선택/);
  onboarding(['select','claude']);
  assert.deepEqual(clientState(),{state:'SELECTED',client:'claude'});
  const doctor=()=>JSON.parse(run(['doctor'],0,selected,installed)).clientGuidance;
  const connect=(expected=0)=>run(['connect','claude'],expected,selected,installed);
  const claude=path.join(selected,'CLAUDE.md');
  assert.equal(doctor().agents,'MANAGED_BLOCK_PRESENT');
  assert.equal(doctor().claude.state,'CONNECT_AVAILABLE');
  assert.equal(fs.existsSync(claude),false);
  assert.equal(JSON.parse(connect()).changed,true);
  assert.equal(JSON.parse(connect()).changed,false);
  assert.equal(doctor().claude.state,'IMPORT_PRESENT');
  assert.equal(doctor().modelApplication,'NOT_OBSERVED');
  const claudeRules=Buffer.from('\uFEFFUser guidance.\r\n~~~md\r\n@AGENTS.md\r\n~~~\r\n');
  fs.writeFileSync(claude,claudeRules);
  assert.equal(doctor().claude.state,'CONNECT_AVAILABLE');
  assert.equal(JSON.parse(connect()).changed,true);
  assert.deepEqual(fs.readFileSync(claude).subarray(0,claudeRules.length),claudeRules);
  assert.equal(JSON.parse(connect()).changed,false);
  const damaged=Buffer.from('<!-- J-HARNESS-CLAUDE:START -->\n@other.md\n<!-- J-HARNESS-CLAUDE:END -->\n');
  fs.writeFileSync(claude,damaged);
  assert.equal(doctor().claude.state,'REVIEW_REQUIRED');
  assert.match(connect(1),/CLAUDE_GUIDANCE_REQUIRES_REVIEW/);
  assert.deepEqual(fs.readFileSync(claude),damaged);
  fs.writeFileSync(claude,'~~~md\nAn unfinished fenced block.\n');
  assert.match(connect(1),/CLAUDE_GUIDANCE_REQUIRES_REVIEW/);
  assert.equal(fs.readFileSync(claude,'utf8'),'~~~md\nAn unfinished fenced block.\n');
  fs.writeFileSync(path.join(selected,'AGENTS.override.md'),'Existing override.\n');
  fs.writeFileSync(path.join(selected,'GEMINI.md'),'Existing AGY instructions.\n');
  assert.equal(doctor().codex.override,'OVERRIDE_PRESENT');
  assert.equal(doctor().agy.additionalGeminiGuidance,'PRESENT');
  fs.unlinkSync(agents);
  assert.equal(doctor().agents,'MISSING');
  assert.match(connect(1),/PROJECT_AGENTS_GUIDANCE_REQUIRES_REVIEW/);
  fs.writeFileSync(agents,after);
  fs.appendFileSync(agents,'\nUser-owned addition after setup.\n');
  fs.writeFileSync(agents,fs.readFileSync(agents,'utf8').replace('Never fall back to v7.','Allow an unreviewed fallback.'));
  assert.equal(doctor().agents,'REVIEW_REQUIRED');
  const edited=fs.readFileSync(agents),blocked=setup();assert.equal(blocked.status,1,blocked.stdout+blocked.stderr);assert.equal(JSON.parse(blocked.stderr).status,'BLOCKED');assert.match(blocked.stderr,/MANAGED_PROJECT_BRIDGE_REQUIRES_REVIEW/);assert.deepEqual(fs.readFileSync(agents),edited);assert.deepEqual(fs.readFileSync(bindingFile),bindingBefore);
 });
 await t.test('unbound normal and reversed portable markers require review and preserve guidance',()=>{
  const start='<!-- J-HARNESS-PORTABLE:START -->',end='<!-- J-HARNESS-PORTABLE:END -->';
  for(const [name,markers] of [['normal',[start,end]],['reversed',[end,start]]]){
   const selected=path.join(temp,'unbound-markers-'+name);fs.mkdirSync(selected);
   const installed=path.join(selected,'.agents/j-harness');materializeRuntime(installed);
   const agents=path.join(selected,'AGENTS.md'),bytes=Buffer.from('User rules\r\n'+markers.join('\r\nUnowned managed text\r\n')+'\r\n');fs.writeFileSync(agents,bytes);
   const result=spawnSync(process.execPath,[path.join(installed,'setup.mjs'),'--project',selected],{env,encoding:'utf8',windowsHide:true});
   assert.equal(result.status,1,result.stdout+result.stderr);assert.equal(JSON.parse(result.stderr).status,'BLOCKED');assert.match(result.stderr,/MANAGED_PROJECT_BRIDGE_REQUIRES_REVIEW/);assert.deepEqual(fs.readFileSync(agents),bytes);assert.equal(fs.existsSync(path.join(selected,'.ai/harness-project.json')),false);assert.equal(fs.existsSync(path.join(selected,'.jh-artifacts')),false);
  }
 });
 await t.test('legacy Harness metadata without a binding requires migration review and preserves files',()=>{
  for(const [index,names] of [['yaml',['harness.yaml']],['markdown',['HARNESS.md']],['both',['harness.yaml','HARNESS.md']]]){
   const selected=path.join(temp,'legacy-metadata-'+index);fs.mkdirSync(path.join(selected,'.ai'),{recursive:true});
   const installed=path.join(selected,'.agents/j-harness');materializeRuntime(installed);
   const originals=new Map([['AGENTS.md',Buffer.from('User-owned instructions\r\n')],...names.map(name=>['.ai/'+name,Buffer.from('Existing Harness contract: preserve '+name+'\r\n')])]);
   for(const [name,bytes] of originals)fs.writeFileSync(path.join(selected,name),bytes);
   const result=spawnSync(process.execPath,[path.join(installed,'setup.mjs'),'--project',selected],{env,encoding:'utf8',windowsHide:true});
   assert.equal(result.status,1,result.stdout+result.stderr);assert.equal(JSON.parse(result.stderr).status,'BLOCKED');assert.match(result.stderr,/EXISTING_HARNESS_MIGRATION_REQUIRES_REVIEW/);
   for(const [name,bytes] of originals)assert.deepEqual(fs.readFileSync(path.join(selected,name)),bytes);
   assert.equal(fs.existsSync(path.join(selected,'.ai/harness-project.json')),false);assert.equal(fs.existsSync(path.join(selected,'.jh-artifacts')),false);
  }
 });
 await t.test('late setup receipt failure restores an existing empty AGENTS file and removes the new binding',()=>{
  const selected=path.join(temp,'empty-guidance-rollback');fs.mkdirSync(selected);
  const installed=path.join(selected,'.agents/j-harness');materializeRuntime(installed);
  const agents=path.join(selected,'AGENTS.md'),bindingFile=path.join(selected,'.ai/harness-project.json');fs.writeFileSync(agents,Buffer.alloc(0));
  const hook=path.join(temp,'fail-setup-receipt.mjs'),witness=path.join(temp,'receipt-failure-witness.txt');
  fs.writeFileSync(hook,`import fs from 'node:fs';import path from 'node:path';
const originalWrite=fs.writeFileSync;
fs.writeFileSync=function(file,...args){
 if(path.basename(String(file))==='receipt.json'){
  if(!fs.existsSync(${JSON.stringify(bindingFile)})||!fs.readFileSync(${JSON.stringify(agents)},'utf8').includes('J-HARNESS-PORTABLE:START'))throw Error('FAILURE_INJECTION_TOO_EARLY');
  originalWrite(${JSON.stringify(witness)},'AFTER_GUIDANCE_AND_BINDING');throw Error('INJECTED_RECEIPT_FAILURE');
 }
 return originalWrite.call(this,file,...args);
};\n`);
  const setupBefore=fs.readFileSync(path.join(installed,'setup.mjs'));
  const result=spawnSync(process.execPath,['--import',pathToFileURL(hook).href,path.join(installed,'setup.mjs'),'--project',selected],{env,encoding:'utf8',windowsHide:true});
  assert.equal(result.status,1,result.stdout+result.stderr);assert.equal(JSON.parse(result.stderr).status,'BLOCKED');assert.match(result.stderr,/INJECTED_RECEIPT_FAILURE/);assert.equal(fs.readFileSync(witness,'utf8'),'AFTER_GUIDANCE_AND_BINDING');
  assert.equal(fs.existsSync(agents),true);assert.equal(fs.statSync(agents).size,0);assert.equal(fs.existsSync(bindingFile),false);assert.equal(fs.readdirSync(selected).some(name=>name.startsWith('AGENTS.md.tmp-')),false);assert.deepEqual(fs.readFileSync(path.join(installed,'setup.mjs')),setupBefore);
  assert.equal(JSON.parse(run(['status'],0,selected,installed)).effective,'READY_LOCAL');
 });
 await t.test('status doctor help version and genuine built-in reads',()=>{const status=json(['status']);assert.equal(status.version,version);assert.equal(status.effective,'READY_LOCAL');assert.equal(status.projectBinding,'UNBOUND');assert.equal(status.globalConnectionRequired,false);assert.equal(json(['doctor']).globalHomeRequired,false);assert.match(run(['--help']),/PROJECT_PORTABLE/);assert.equal(run(['--version']).trim(),version);assert.match(run(['skills','read','jh-guided-development']),/CONTENT_RETURNED/);assert.match(run(['policy','read','P07']),/CURATED/);assert.equal(json(['skills','list']).some(x=>x.file.startsWith(sentinel)),false);for(const cmd of ['install','on','off','toggle','uninstall','start'])assert.match(run([cmd],1),/UNAVAILABLE_IN_PROJECT_PORTABLE/);});
 await t.test('onboarding checks only the selected client and route distinguishes work without dispatch',()=>{
  const plan=json(['environment','plan','--client','claude']);
  assert.equal(plan.selectedClient,'claude');
  assert.equal(plan.state,'SETUP_REQUIRED');
  assert.match(run(['quickstart']),/JHarness\.cmd setup/);
  assert.match(run(['select','codex'],1),/PROJECT_SETUP_REQUIRED/);
  assert.equal(Object.hasOwn(json(['doctor']),'supervisor'),false);
  assert.ok(plan.beginnerSteps.some(step=>step.includes('environment inspect --client claude')));
  assert.equal(JSON.parse(run(['environment','inspect','--client','claude'],3)).state,'SETUP_REQUIRED');
  assert.match(run(['environment','install'],1),/READONLY/);
  const simple=json(['route','README 오탈자 수정']);
  const complex=json(['route','데이터베이스 스키마 변경, 데이터 마이그레이션 및 접근 권한 검증']);
  assert.equal(simple.risk,'R0');
  assert.equal(simple.delegation.recommendation,'HANDLE_DIRECTLY');
  assert.equal(complex.complexity,'COMPLEX');
  assert.ok(complex.policyIds.includes('P17'));
  assert.notDeepEqual(simple.recommendedPlan,complex.recommendedPlan);
  assert.equal(complex.delegation.execution,'NOT_DISPATCHED');
  assert.equal(json(['progress']).state,null);
 });
 await t.test('supervision fails closed and local evidence omits argv, inherits no private environment, and links the run',()=>{
  const dir=path.join(temp,'verification boundary');
  fs.mkdirSync(path.join(dir,'.ai'),{recursive:true});
  const config=path.join(dir,'.ai/harness-project.json');
  const fixtureScope={include:['src']};
  fs.writeFileSync(config,JSON.stringify({verification_scope:fixtureScope,supervisor:{required:true}}));
  fs.mkdirSync(path.join(dir,'src'));
  fs.writeFileSync(path.join(dir,'src','.env'),'synthetic unused fixture');
  fs.writeFileSync(path.join(dir,'src','oauth_creds.json'),'synthetic unused OAuth fixture');
  const quoted='synthetic multi-word credential';
  const google='AIza'+'0'.repeat(35);
  const github='github_pat_'+'0'.repeat(24);
  fs.writeFileSync(path.join(dir,'src','check.cjs'),[
   "if(process.env.JH_FIXTURE_PRIVATE!==undefined||process.env.CODEX_HOME!==undefined)process.exit(9);",
   "if(process.argv[2]!=='arbitrary-argument-sentinel')process.exit(8);",
   "console.log('Authorization: Bearer synthetic-placeholder');",
   'console.error('+JSON.stringify(JSON.stringify({ANTHROPIC_AUTH_TOKEN:quoted})+'\n'+google+' '+github)+');',
  ].join('\n'));
  assert.match(run(['begin','ANTHROPIC_AUTH_TOKEN="'+quoted+'"'],1,dir),/SECRET_LIKE_TEXT_REFUSED/);
  const id=JSON.parse(run(['begin','Verify boundary fixture'],0,dir)).runId;
  run(['advance','plan','--note','Run the isolated check'],0,dir);
  run(['advance','implement'],0,dir);
  assert.equal(JSON.parse(run(['supervisor','status'],1,dir)).launchAuthorized,false);
  assert.equal(JSON.parse(run(['doctor'],0,dir)).supervisor.launchAuthorized,false);
  assert.match(run(['verify','--',process.execPath,'src/check.cjs'],1,dir),/SUPERVISOR_REQUIRED_EXECUTION_BLOCKED/);
  assert.equal(fs.existsSync(path.join(dir,'.jh-artifacts/j-harness-core/logs')),false);
  fs.writeFileSync(config,JSON.stringify({verification_scope:{include:['src/.env']}}));
  const command=['verify','--',process.execPath,'src/check.cjs','arbitrary-argument-sentinel'];
  assert.match(run(command,1,dir),/CREDENTIAL_PATH_NOT_ALLOWED/);
  fs.writeFileSync(config,JSON.stringify({verification_scope:fixtureScope}));
  assert.match(run(['verify','--require-supervisor',...command.slice(1)],1,dir),/SUPERVISOR_REQUIRED_EXECUTION_BLOCKED/);
  const verified=JSON.parse(run(command,0,dir));
  assert.equal(verified.runId,id);
  assert.equal(verified.sourceScope.files,1);
  assert.equal(verified.stdoutTail.trim(),'Authorization: Bearer [REDACTED]');
  assert.deepEqual(verified.stderrTail.trim().split('\n'),['{"ANTHROPIC_AUTH_TOKEN":"[REDACTED]"}','[REDACTED TOKEN] [REDACTED TOKEN]']);
  const durable=fs.readFileSync(path.join(verified.logDirectory,verified.id+'.stderr.txt'),'utf8');
  assert.equal(durable,verified.stderrTail);
  const persisted=run(['progress'],0,dir);
  assert.doesNotMatch(persisted,/arbitrary-argument-sentinel|synthetic-placeholder/);
  assert.ok(JSON.parse(persisted).events.every(row=>row.runId===id&&row.eventId));
 });
 await t.test('failed test repaired, stale PASS blocked, actual handoff and relocation',()=>{
  const script=path.join(project,'check.cjs');
  const verify=['verify','--',process.execPath,'check.cjs'];
  fs.writeFileSync(script,'process.exit(1)');
  fs.writeFileSync(path.join(project,'README.md'),'Run the application with the installed Node executable. Check the saved results and follow these instructions.\n');
  run(['begin','portable acceptance']);
  const beforePlan=json(['progress']);
  assert.match(run(['advance','--help']),/advance plan --note/);
  assert.match(run(['advance','plan','positional text'],1),/advance plan --note/);
  assert.deepEqual(json(['progress']),beforePlan);
  run(['advance','plan','--note','Run the fixture and repair its observed exit failure']);
  run(['advance','implement']);
  run(verify,1);
  fs.writeFileSync(script,'process.exit(0)');
  assert.equal(json(verify).result,'PASS');
  fs.appendFileSync(script,'\n// changed');
  assert.match(run(['advance','handoff'],1),/CODE_CHANGED/);
  run(verify);
  run(['learn','--cause','Fixture exited one','--fix','Corrected fixture exit']);
  run(['advance','handoff']);
  const beforeFinish=json(['progress']);
  assert.match(run(['verify','--help']),/verify '--'/);
  assert.match(run(['finish','--help']),/finish --guide/);
  assert.match(run(['finish','--unknown'],1),/finish --guide/);
  assert.deepEqual(json(['progress']),beforeFinish);
  assert.equal(json(['finish']).result,'COMPLETE_LOCAL_VERIFIED');
  const relocated=path.join(temp,'복사 project two');
  copy(project,relocated);
  assert.equal(JSON.parse(run(['progress'],0,relocated)).state.project,fs.realpathSync(relocated));
  const relocatedRuntime=path.join(temp,'독립 runtime copy');
  copy(runtime,relocatedRuntime);
  assert.equal(JSON.parse(run(['status'],0,relocated,relocatedRuntime)).effective,'READY_LOCAL');
 });
 await t.test('explicit scope, stale scope, missing and escaping inputs',()=>{binding({verification_scope:{include:['check.cjs','README.md'],exclude:[]}});run(['begin','explicit scope']);run(['advance','plan','--note','Use explicit source inputs']);run(['advance','implement']);const evidence=json(['verify','--',process.execPath,'check.cjs']);assert.deepEqual(evidence.sourceScope.scope.include,['check.cjs','README.md']);fs.writeFileSync(path.join(project,'outside-evidence.txt'),'unrelated');run(['advance','handoff']);run(['finish']);for(const scope of [{include:[],exclude:[]},{include:['missing'],exclude:[]},{include:['../escape'],exclude:[]},{include:['check.cjs'],exclude:['../escape']},{include:['check.cjs'],exclude:['check.cjs']}]){binding({verification_scope:scope});assert.match(run(['progress'],1),/SCOPE|PATH/);}binding({verification_scope:{include:['check.cjs'],exclude:[]}});run(['begin','scope mutation test']);run(['advance','plan','--note','Reject changing source during verification']);run(['advance','implement']);const modified=JSON.parse(run(['verify','--',process.execPath,'-e',"require('fs').appendFileSync('check.cjs','\\n// mutation')"].map(x=>x),1));assert.equal(modified.result,'FAIL');});
 await t.test('canonical portable modes preserve declared maintenance and reject invalid or conflicting declarations',()=>{
  let fixtureId=0;
  function fixture(state,config={}){
   const dir=path.join(temp,'mode-'+fixtureId++);fs.mkdirSync(path.join(dir,'.ai'),{recursive:true});fs.mkdirSync(path.join(dir,'existing-service/src'),{recursive:true});
   if(state!==undefined)fs.writeFileSync(path.join(dir,'.ai/harness-state.json'),JSON.stringify(state));
   fs.writeFileSync(path.join(dir,'.ai/harness-project.json'),JSON.stringify(config));return dir;
  }
  for(const mode of ['GREENFIELD','MAINTENANCE','HOTFIX','MIGRATION']){
   const dir=fixture({project_mode:mode,goal:'Preserve business goal',current_phase:'00_INTAKE'},{binding:{project_mode:mode}});
   const stateFile=path.join(dir,'.ai/harness-state.json'),bindingFile=path.join(dir,'.ai/harness-project.json'),before=fs.readFileSync(stateFile),bindingBefore=fs.readFileSync(bindingFile);
   assert.equal(JSON.parse(run(['begin','portable local goal'],0,dir)).mode,mode);assert.deepEqual(fs.readFileSync(stateFile),before);assert.deepEqual(fs.readFileSync(bindingFile),bindingBefore);
  }
  const bindingOnly=fixture(undefined,{project_mode:'HOTFIX'});assert.equal(JSON.parse(run(['begin','binding mode'],0,bindingOnly)).mode,'HOTFIX');
  for(const mode of ['maintenance','UNKNOWN','',null,3]){
   for(const [state,config] of [[{project_mode:mode},{}],[undefined,{project_mode:mode}],[undefined,{binding:{project_mode:mode}}]]){
    const dir=fixture(state,config);assert.match(run(['begin','invalid mode'],1,dir),/INVALID_CANONICAL_PROJECT_MODE/);assert.equal(fs.existsSync(path.join(dir,'.jh-artifacts')),false);
   }
  }
  for(const config of [{project_mode:'GREENFIELD'},{binding:{project_mode:'HOTFIX'}},{project_mode:'MAINTENANCE',binding:{project_mode:'MIGRATION'}}])assert.match(run(['begin','conflicting mode'],1,fixture({project_mode:'MAINTENANCE'},config)),/CONFLICTING_CANONICAL_PROJECT_MODE/);
  const empty=fixture(undefined);assert.equal(JSON.parse(run(['begin','unconfigured empty'],0,empty)).mode,'GREENFIELD');
  const existing=fixture(undefined);fs.writeFileSync(path.join(existing,'package.json'),'{}');assert.equal(JSON.parse(run(['begin','heuristic existing'],0,existing)).mode,'MAINTENANCE');
 });
 await t.test('each explicit model guard dependency and canonical state invalidates real PASS at handoff and finish',()=>{
  const dependencies=['harness/scripts/model_execution.py','harness/scripts/runtime_engine.py','harness/runtime/model-execution-activation.json','.ai/harness-state.json'];
  const dir=path.join(temp,'guard-project');fs.mkdirSync(path.join(dir,'.ai'),{recursive:true});
  fs.writeFileSync(path.join(dir,'check.cjs'),'process.exit(0)');fs.writeFileSync(path.join(dir,'README.md'),'Run the installed Node executable against check.cjs and inspect saved verification evidence before accepting this local fixture.');
  for(const file of dependencies){fs.mkdirSync(path.dirname(path.join(dir,file)),{recursive:true});fs.writeFileSync(path.join(dir,file),file==='.ai/harness-state.json'?JSON.stringify({project_mode:'MAINTENANCE',goal:'preserved business goal'}):'original guard fixture');}
  const include=['check.cjs','README.md',...dependencies];fs.writeFileSync(path.join(dir,'.ai/harness-project.json'),JSON.stringify({verification_scope:{include,exclude:[]}}));
  run(['begin','guard freshness'],0,dir);run(['advance','plan','--note','Verify every explicit guard input'],0,dir);run(['advance','implement'],0,dir);
  for(const file of dependencies){
   const before=JSON.parse(run(['verify','--',process.execPath,'check.cjs'],0,dir));assert.equal(before.result,'PASS');assert.deepEqual(before.sourceScope.scope.include,include);assert.equal(before.sourceScope.files,6);
   if(file==='.ai/harness-state.json')fs.writeFileSync(path.join(dir,file),JSON.stringify({project_mode:'HOTFIX',goal:'preserved business goal'}));else fs.appendFileSync(path.join(dir,file),' changed');assert.match(run(['advance','handoff'],1,dir),/CODE_CHANGED_PREVIOUS_PASS_INVALID/);
   assert.equal(JSON.parse(run(['verify','--',process.execPath,'check.cjs'],0,dir)).result,'PASS');run(['advance','handoff'],0,dir);
   if(file==='.ai/harness-state.json')fs.writeFileSync(path.join(dir,file),JSON.stringify({project_mode:'MIGRATION',goal:'preserved business goal'}));else fs.appendFileSync(path.join(dir,file),' changed again');assert.match(run(['finish'],1,dir),/CODE_CHANGED_PREVIOUS_PASS_INVALID/);
   run(['verify','--',process.execPath,'check.cjs'],0,dir);
  }
  run(['advance','handoff'],0,dir);run(['finish'],0,dir);
 });
 await t.test('same real Windows directory aliases pass and unrelated runtime bindings fail',()=>{
  const dir=path.join(temp,'case-project');fs.mkdirSync(path.join(dir,'.ai'),{recursive:true});const bindingFile=path.join(dir,'.ai/harness-project.json');
  const harness={product:'J Harness Core',root:runtime,version,manifest_sha256:sha256(fs.readFileSync(path.join(runtime,'manifest.json')))};
  fs.writeFileSync(bindingFile,JSON.stringify({binding:{harness}}));run(['status'],0,dir);
  if(process.platform==='win32'){
   const alias=dir.replace(/[a-zA-Z]/g,c=>c===c.toUpperCase()?c.toLowerCase():c.toUpperCase());assert.notEqual(alias,dir);run(['status'],0,alias);
   fs.writeFileSync(bindingFile,JSON.stringify({binding:{harness:{...harness,root:runtime.toUpperCase()}}}));run(['status'],0,alias);
  }
  const unrelated=path.join(temp,'unrelated-runtime');copy(runtime,unrelated);fs.writeFileSync(bindingFile,JSON.stringify({binding:{harness:{...harness,root:unrelated}}}));assert.match(run(['status'],1,dir),/BOUND_RUNTIME_MISMATCH/);
  const linked=path.join(temp,'bound-runtime-junction');fs.symlinkSync(runtime,linked,process.platform==='win32'?'junction':'dir');fs.writeFileSync(bindingFile,JSON.stringify({binding:{harness:{...harness,root:linked}}}));assert.match(run(['status'],1,dir),/LINK_PATH_REFUSED/);fs.unlinkSync(linked);
 });
 await t.test('the portable guide participates in runtime validation',()=>{
  const guide=path.join(runtime,'PORTABLE.md'),bytes=fs.readFileSync(guide);
  try{
   fs.appendFileSync(guide,'\nTest fixture: altered guidance.\n');
   assert.match(run(['doctor'],1),/RUNTIME_HASH_DRIFT: PORTABLE\.md/);
  }finally{fs.writeFileSync(guide,bytes);}
  assert.equal(json(['doctor']).runtimeIntegrity,'VERIFIED');
 });
 await t.test('manifest traversal duplicate hash drift missing files and binding pins',()=>{const file=path.join(runtime,'manifest.json'),clean=fs.readFileSync(file);function bad(change,pattern){const m=JSON.parse(clean);change(m);fs.writeFileSync(file,JSON.stringify(m));assert.match(run(['status'],1),pattern);fs.writeFileSync(file,clean);}bad(m=>m.files.push({path:'../escape',sha256:'0'.repeat(64)}),/INVALID_RELATIVE/);bad(m=>m.files.push(m.files[0]),/DUPLICATE/);bad(m=>m.files[0].sha256='0'.repeat(64),/HASH_DRIFT/);bad(m=>m.files.pop(),/INCOMPLETE/);bad(m=>m.version='wrong',/VERSION/);const core=path.join(runtime,'runtime/core/cli.mjs'),bytes=fs.readFileSync(core);fs.writeFileSync(core,"throw Error('DAMAGED_CORE_EXECUTED');");const output=run(['status'],1);assert.match(output,/HASH_DRIFT/);assert.doesNotMatch(output,/DAMAGED_CORE_EXECUTED/);fs.writeFileSync(core,bytes);fs.renameSync(core,core+'.missing');assert.match(run(['status'],1),/ENOENT/);fs.renameSync(core+'.missing',core);const harness={product:'J Harness Core',root:runtime,version,manifest_sha256:sha256(clean)};binding({binding:{harness}});assert.equal(json(['status']).projectBinding,'BOUND_VERIFIED');for(const field of ['root','version','manifest_sha256']){binding({binding:{harness:{...harness,[field]:'wrong'}}});assert.match(run(['status'],1),/BOUND_/);}binding({});});
 await t.test('symlink containment, missing manifest, and duplicate project options',()=>{const link=path.join(project,'linked-input');fs.symlinkSync(runtime,link,process.platform==='win32'?'junction':'dir');binding({verification_scope:{include:['linked-input'],exclude:[]}});assert.match(run(['progress'],1),/LINK/);fs.unlinkSync(link);binding({});const linkedRuntime=path.join(runtime,'linked-runtime');fs.symlinkSync(project,linkedRuntime,process.platform==='win32'?'junction':'dir');assert.match(run(['status'],1),/LINK/);fs.unlinkSync(linkedRuntime);const manifest=path.join(runtime,'manifest.json');fs.renameSync(manifest,manifest+'.held');assert.match(run(['status'],1),/ENOENT/);fs.renameSync(manifest+'.held',manifest);assert.match(run(['status','--project',project],1),/DUPLICATE_PROJECT/);});
 await t.test('project scoped external registration approval and drift checks',()=>{const skill=path.join(temp,'external');fs.mkdirSync(skill);fs.writeFileSync(path.join(skill,'SKILL.md'),'---\nname: portable-fixture\ndescription: A locally reviewed fixture skill.\n---\nUse the fixture.\n');const inspected=json(['skills','inspect','--path',skill]);const register=['skills','register','--path',skill,'--source','https://example.com/fixture','--review-sha256',inspected.treeSha256];assert.match(run(register,1),/EXPLICIT_REVIEW/);run([...register,'--approve']);const stored=path.join(project,'.jh-artifacts/j-harness-core/registered/portable-fixture/SKILL.md');assert.ok(fs.existsSync(stored));run(['skills','read','portable-fixture']);fs.appendFileSync(stored,'Changed');assert.match(run(['skills','read','portable-fixture'],1),/CHANGED_REVIEW/);assert.equal(fs.existsSync(path.join(runtime,'registered')),false);});
 await t.test('global API compatibility and sentinel unchanged',()=>{const io=path.join(runtime,'runtime/core/lib/io.mjs'),install=path.join(runtime,'runtime/core/lib/install.mjs');const r=spawnSync(process.execPath,['--input-type=module','-e',`import {home,rootFor} from ${JSON.stringify(new URL('file:///'+io.replaceAll('\\','/')).href)};import {status} from ${JSON.stringify(new URL('file:///'+install.replaceAll('\\','/')).href)};console.log(JSON.stringify({home:home(${JSON.stringify(temp)}),root:rootFor(${JSON.stringify(temp)}),status:status(${JSON.stringify(temp)})}));`],{env,encoding:'utf8'});assert.equal(r.status,0,r.stderr);assert.equal(JSON.parse(r.stdout).status.effective,'NOT_CONNECTED');assert.deepEqual(fs.readFileSync(sentinel),original);});
 }finally{const resolved=path.resolve(temp);assert.ok(resolved.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(resolved).startsWith('jh-portable-'));fs.rmSync(resolved,{recursive:true,force:true});}
});
