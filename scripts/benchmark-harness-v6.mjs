import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, existsSync } from 'node:fs';
import { resolve, join, dirname, relative, isAbsolute, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { routeTask, transitionPhase } from './harness-engine.mjs';
import { planProject, applyPlan, rollbackProject, verifyProject, sourceIdentity } from './harness-project.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
function option(name) {const n=process.argv.indexOf(name); return n>=0 ? process.argv[n+1] : null;}
const baselineRoot=option('--baseline-root');
assert.ok(baselineRoot,'--baseline-root must identify the actual unchanged v5 checkout');
const baselinePath=resolve(baselineRoot);
assert.notEqual(baselinePath,root,'v5 baseline must differ from the v6 source');
const out=resolve(option('--out')??join(root,'harness/benchmark'));
for(const name of ['CORE.md','ROUTER.md','POLICY_INDEX.yaml']) assert.ok(existsSync(join(baselinePath,name)),`Missing baseline ${name}`);
const baselineIndexVersion=readFileSync(join(baselinePath,'POLICY_INDEX.yaml'),'utf8').match(/^harness_version:\s*["']?([\d.]+)/m)?.[1];
const baselineVersion=existsSync(join(baselinePath,'HARNESS_VERSION'))?readFileSync(join(baselinePath,'HARNESS_VERSION'),'utf8').trim():baselineIndexVersion;
assert.match(baselineVersion??'',/^v?5\./,'baseline version source must identify actual v5 source');
assert.equal(baselineVersion.replace(/^v/,''),baselineIndexVersion,'baseline version sources must agree');
const cases=JSON.parse(readFileSync(join(root,'harness/benchmark/cases/representative.json'),'utf8')).cases;
const sha=text=>createHash('sha256').update(text).digest('hex');
const unavailable='Not measured: local harness fixture benchmark has no real users, model provider, product development or deployed production service.';
const tokenizerCandidates=[process.env.HARNESS_BENCHMARK_PYTHON,'python'].filter(Boolean);
let tokenizer=null;
for(const candidate of tokenizerCandidates) {
  const probe=spawnSync(candidate,['-c','import tiktoken,importlib.metadata; print(importlib.metadata.version("tiktoken"))'],{encoding:'utf8',timeout:10000,windowsHide:true});
  if(probe.status===0) {tokenizer={command:candidate,version:probe.stdout.trim()}; break;}
}
function context(source,route) {
  const selected=[...new Set(['CORE.md','ROUTER.md','POLICY_INDEX.yaml',...route.jit_files])];
  const present=selected.filter(p=>existsSync(join(source,p)));
  const text=present.map(p=>readFileSync(join(source,p),'utf8')).join('\n');
  let tokens=null;
  if(tokenizer) {
    const count=spawnSync(tokenizer.command,['-X','utf8','-c','import sys,tiktoken; print(len(tiktoken.get_encoding("cl100k_base").encode(sys.stdin.read())))'],{input:text,encoding:'utf8',timeout:20000,windowsHide:true});
    if(count.status===0 && /^\d+$/.test(count.stdout.trim())) tokens=Number(count.stdout.trim());
  }
  return {selection:'v6 deterministic selection applied to both payloads',files:present,unavailable_files:selected.filter(p=>!present.includes(p)),utf8_bytes:Buffer.byteLength(text,'utf8'),sha256:sha(text),tokens,tokenizer:tokens===null?null:{encoding:'cl100k_base',package:'tiktoken',version:tokenizer.version},estimated_tokens:Math.ceil(Buffer.byteLength(text,'utf8')/4),estimator:'ceil(UTF8 bytes / 4); heuristic only',billed_api_tokens:null};
}
const gate={status:'PASS',goal:'Fixture check',acceptance_criteria:['Fixture stays intact'],verification_method:'Assertion',evidence:['fixture/assertion.log']};
const baseline=[]; const results=[];
for(const c of cases) {
  const routeStart=performance.now();
  const detected={has_product:!['05','11'].includes(c.id)};
  const route=routeTask({text:c.request,beginner_mode:c.beginner??false},detected);
  const routeMs=performance.now()-routeStart;
  const oldContext=context(baselinePath,route);
  baseline.push({...c,context:oldContext,wall_ms:null,tool_calls:null,retries:null,human_interventions:null,capabilities:{phase_engine:'unavailable',project_transaction:'unavailable'},reason:'v5 lacks the executable v6 lifecycle/transaction API; prose guidance is not an executed score.'});
  const project=mkdtempSync(join(tmpdir(),'harness-v6-bench-'));
  const snapshotRoot=mkdtempSync(join(tmpdir(),'harness-v6-bench-'));
  const t0=performance.now(); let toolCalls=1; const checks={}; let error=null; let filesTouched=null; let rollbackCount=0; let subprocessCalls=0;
  try {
    assert.equal(route.project_mode,c.mode); checks.mode_route=true;
    if(c.kind==='security') { assert.ok(route.jit_files.some(p=>p.startsWith('policies/17_'))); checks.security_boundary=true; }
    if(c.kind==='database') { assert.ok(route.jit_files.some(p=>p.startsWith('policies/16_'))); checks.migration_boundary=true; }
    let product=null;
    const config={snapshot_root:snapshotRoot};
    if(detected.has_product) {
      writeFileSync(join(project,'product.txt'),'benchmark product\r\n한글 bytes\n'); product=readFileSync(join(project,'product.txt'));
      writeFileSync(join(project,'AGENTS.md'),'# User rules\nKeep these bytes.\n');
      writeFileSync(join(project,'verify.mjs'),'process.exit(0);\n');
      const command={command:process.execPath,args:[join(project,'verify.mjs')]};
      config.verification_commands={build:command,test:command,critical_regression:command};
    }
    const planned=planProject({project,sourceRoot:root,request:'이 프로젝트 하네스 설치해줘',config}); toolCalls++;
    if(!detected.has_product) {assert.equal(planned.route.project_mode,'GREENFIELD');checks.empty_greenfield_binding=true;}
    assert.equal(planned.status,'READY'); checks.plan=true;
    const applied=await applyPlan(planned); toolCalls++;
    assert.equal(applied.status,'PASS'); subprocessCalls+=applied.benchmark.tool_calls; checks.transaction=true;
    const verified=await verifyProject(project); toolCalls++;
    assert.equal(verified.status,'PASS'); subprocessCalls+=Object.values(verified.verification).filter(x=>x.status!=='N/A').length; checks.verification=true;
    if(product) {assert.deepEqual(readFileSync(join(project,'product.txt')),product);checks.product_preserved=true;}
    else checks.no_product_creation= !existsSync(join(project,'product.txt'))&&!existsSync(join(project,'verify.mjs'));
    const phaseStart=performance.now();
    assert.throws(()=>transitionPhase({workflow:['08_FEATURE_IMPLEMENTATION']},'08_FEATURE_IMPLEMENTATION',gate)); toolCalls++; checks.acceptance_gate=true;
    assert.throws(()=>transitionPhase({workflow:['00_INTAKE','01_DISCOVERY'],phases:{'00_INTAKE':{...gate,status:'FAILED'}}},'01_DISCOVERY',gate)); toolCalls++; checks.failed_prior_gate=true;
    if(c.kind==='build_recovery') {
      const repaired=transitionPhase({workflow:['00_INTAKE','01_DISCOVERY'],phases:{'00_INTAKE':gate}},'01_DISCOVERY',gate); toolCalls++;
      assert.equal(repaired.phases['01_DISCOVERY'].status,'PASS'); checks.repaired_gate_resume=true;
    }
    if(c.kind==='production_recovery') {
      const s={workflow:['13_PRODUCTION_VERIFICATION'],acceptance:gate,verification:gate,review:{...gate,builder_role:'builder',reviewer_role:'reviewer'},release:gate,deployment:{...gate,status:'DEPLOYED',evidence:[{ref:'fixture/deployment.log',status:'DEPLOYED',environment:'production',simulated:false}]},production:true};
      assert.throws(()=>transitionPhase(s,'13_PRODUCTION_VERIFICATION',{...gate,status:'VERIFIED_PRODUCTION',evidence:[{ref:'fixture/smoke.log',status:'PASS',environment:'production',simulated:true}]}),/production evidence/); toolCalls++;
      checks.simulated_production_rejected=true;
    }
    const phaseDuration=performance.now()-phaseStart;
    const rollback=await rollbackProject(project); toolCalls++; assert.equal(rollback.status,'ROLLED_BACK'); subprocessCalls+=Object.values(rollback.verification).filter(x=>x.status!=='N/A').length; rollbackCount++;
    if(product) assert.deepEqual(readFileSync(join(project,'product.txt')),product); checks.rollback=true;
    filesTouched=planned.actions.length;
    checks.phase_duration_ms=phaseDuration;
  } catch(e) {error=e.message;}
  finally {
    for(const target of [project,snapshotRoot]) {
      const rel=relative(resolve(tmpdir()),resolve(target));
      assert.ok(rel && !rel.startsWith('..')&&!isAbsolute(rel)&&/^harness-v6-bench-/.test(rel));
      rmSync(target,{recursive:true,force:true});
    }
  }
  const success=error===null;
  results.push({...c,route:{project_mode:route.project_mode,risk:route.risk,tier:route.tier,verification_profile:route.verification_profile},wall_ms:performance.now()-t0+routeMs,route_duration_ms:routeMs,wall_scope:'Routing plus fixture operations and cleanup; context tokenizer time excluded.',tool_calls:toolCalls,verification_subprocess_calls:subprocessCalls,tool_call_scope:'Public harness API calls; verification subprocess calls recorded separately; internal Git probes excluded.',retries:0,human_interventions:0,files_touched:filesTouched,files_touched_scope:'Managed binding actions; journal and source snapshot bookkeeping excluded.',rollback_count:rollbackCount,context:context(root,route),checks,error,measurement_scope:'harness_fixture',task_success:success,first_pass_success:success,verification_pass:checks.verification===true,product_metrics:{reviewer_findings:null,post_merge_defects:null,visual_regressions:null,architecture_violations:null,first_deployment_success:null,production_verification_success:null,reason:unavailable},beginner_metrics:{guided_completion:null,decision_error_recovery:null,required_external_knowledge:null,successful_first_deployment:null,reason:unavailable}});
}
const failures=results.filter(c=>!c.task_success).length;
const oldBytes=baseline.reduce((n,c)=>n+c.context.utf8_bytes,0),newBytes=results.reduce((n,c)=>n+c.context.utf8_bytes,0);
const gitCommit=source=>{const r=spawnSync('git',['-C',source,'rev-parse','HEAD'],{encoding:'utf8',windowsHide:true,timeout:10000});return r.status===0?r.stdout.trim():null;};
const provenance={baseline_source:'Unmodified v5 Git checkout supplied by --baseline-root',baseline_harness_version:baselineVersion,baseline_git_commit:gitCommit(baselinePath),v6_source:'Current v6 worktree containing this runner',v6_git_commit:gitCommit(root),v6_payload_sha256:sourceIdentity(root).hash,node:process.version,tokenizer:tokenizer?{executable:basename(tokenizer.command),version:tokenizer.version,encoding:'cl100k_base'}:null,case_input_sha256:sha(readFileSync(join(root,'harness/benchmark/cases/representative.json'))),model_provider_calls:0,limitations:unavailable};
const common={schema_version:'1.0',generated_at:new Date().toISOString(),scope:'Local routing/gate/project-binding fixtures and controlled context payload comparison',provenance};
mkdirSync(join(out,'baseline'),{recursive:true}); mkdirSync(join(out,'results'),{recursive:true});
writeFileSync(join(out,'baseline/v5.json'),JSON.stringify({...common,version:'v5',cases:baseline},null,2)+'\n');
const result={...common,version:'v6',cases:results,summary:{case_count:cases.length,fixture_passed:cases.length-failures,fixture_failed:failures,fixture_success_rate:(cases.length-failures)/cases.length,total_wall_ms:results.reduce((n,c)=>n+c.wall_ms,0),api_billed_tokens:null,production_success_rate:null},release_gate:{status:failures?'FAIL':'PASS',fixture_regressions:failures,baseline_executable_comparison:'unavailable',context_utf8_delta:newBytes-oldBytes,context_cost_explanation:'Additive executable lifecycle, evidence, migration and update contracts increase always-loaded runtime text and selected JIT payloads; no claim of reduced billed tokens.'}};
writeFileSync(join(out,'results/v6.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({status:result.release_gate.status,cases:cases.length,failures,out}));
process.exitCode=failures?1:0;
