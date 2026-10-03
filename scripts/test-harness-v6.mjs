import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync, readdirSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join, dirname, relative, isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const fixtureRoots = [];
function fixture({ existing = false, exit = 0 } = {}) {
  const project = mkdtempSync(join(tmpdir(), 'harness-v6-test-'));
  fixtureRoots.push(project);
  writeFileSync(join(project, 'verify.mjs'), `process.exit(${exit});\n`);
  writeFileSync(join(project, 'product.txt'), '사용자 제품 bytes\r\nunchanged\n');
  if (existing) writeFileSync(join(project, 'AGENTS.md'), '# Local instructions\nKeep my formatting.\n');
  const command = { command: process.execPath, args: [join(project, 'verify.mjs')] };
  const snapshotRoot=mkdtempSync(join(tmpdir(),'harness-v6-test-')); fixtureRoots.push(snapshotRoot);
  return { project, sourceRoot: root, request: '이 프로젝트 하네스 설치해줘', config: { snapshot_root:snapshotRoot, verification_commands: { build: command, test: command, critical_regression: command } } };
}
function snapshot(project) {
  const result = {};
  function visit(folder) {
    for (const item of readdirSync(folder, { withFileTypes: true })) {
      const p = join(folder, item.name);
      if (item.isDirectory()) visit(p);
      else result[relative(project, p).replaceAll('\\', '/')] = readFileSync(p).toString('base64');
    }
  }
  visit(project);
  return result;
}
function cleanup() {
  for (const target of fixtureRoots) {
    const rel = relative(resolve(tmpdir()), resolve(target));
    assert.ok(rel && !rel.startsWith('..') && !isAbsolute(rel) && /^harness-v6-test-/.test(rel), 'cleanup must stay in own temporary fixture');
    rmSync(target, { recursive: true, force: true });
  }
}
process.on('exit', cleanup);

import { PHASES, routeTask, transitionPhase, validateResume, transitionDevelopmentState, evaluateTokenBudget, resolveModelTier } from './harness-engine.mjs';
import { planProject, applyPlan, rollbackProject, verifyProject, inspectProject, safePath, sourceIdentity } from './harness-project.mjs';
const gate = (extra = {}) => ({ status:'PASS', goal:'Preserve user intent', acceptance_criteria:['Acceptance met'], verification_method:'Recorded fixture assertion', evidence:['fixture/assertion.log'], ...extra });
const review = () => gate({builder_role:'builder', reviewer_role:'independent-reviewer'});
const readyRelease = () => ({workflow:['11_RELEASE_VERIFICATION'], phases:{}, acceptance:gate(), verification:gate(), review:review()});

test('sixteen canonical phases and bilingual four-mode routing', () => {
  assert.equal(PHASES.length,16); assert.equal(new Set(PHASES).size,16);
  for (const [request, detected, mode] of [
    ['새 프로젝트 구축',{},'GREENFIELD'], ['Fix existing app',{has_product:true},'MAINTENANCE'],
    ['서비스 장애 긴급 hotfix',{has_product:true},'HOTFIX'], ['database schema migration',{has_product:true},'MIGRATION'],
  ]) assert.equal(routeTask(request,detected).project_mode,mode);
  assert.equal(routeTask('초보자 화면 기능 추가',{has_product:true}).beginner_mode,true);
  assert.equal(routeTask('하네스 설치해줘',{has_product:true}).intent,'harness_adoption');
  assert.equal(routeTask('Install harness',{has_product:true,installed_version:'5.1'}).intent,'harness_update');
  assert.equal(routeTask({text:'security authentication fix',risk:'R0'},{has_product:true}).risk,'R3');
  assert.throws(() => routeTask({text:'fix',project_mode:'invented'}),/mode/i);
});
test('unsafe update timing and minimal blocker exception preserve major gates', () => {
  for (const operation of ['deploy','database migration','data-transform','hotfix','merge-conflict']) {
    assert.equal(routeTask('하네스 업데이트',{has_product:true,installed_version:'5.1',operation_in_progress:operation}).timing,'DEFERRED');
  }
  const detected = {has_product:true,installed_version:'6.0',target_version:'6.0',development_state:'IN_PROGRESS'};
  assert.equal(routeTask('harness workflow update',detected).timing,'CHECKPOINT');
  assert.equal(routeTask({text:'harness documentation update',blocking_harness_defect:true,minimal_repair:true},detected).timing,'NOW');
  assert.equal(routeTask({text:'harness core update',blocking_harness_defect:true,minimal_repair:true},detected).timing,'CHECKPOINT');
});
test('missing contracts, failed previous gates and fake evidence reject without mutating input', () => {
  const state = {workflow:['00_INTAKE','01_DISCOVERY'], phases:{'00_INTAKE':gate({status:'FAILED'})}};
  const before = structuredClone(state);
  assert.throws(() => transitionPhase(state,'01_DISCOVERY',gate()),/blocks/i);
  assert.deepEqual(state,before);
  for (const field of ['goal','acceptance_criteria','verification_method','evidence']) {
    const incomplete = gate(); delete incomplete[field];
    assert.throws(() => transitionPhase({workflow:['00_INTAKE']},'00_INTAKE',incomplete),/missing|evidence/i);
  }
  assert.throws(() => transitionPhase({workflow:['00_INTAKE']},'00_INTAKE',gate({evidence:['PASS']})),/evidence/i);
  assert.throws(() => transitionPhase({workflow:['01_DISCOVERY']},'01_DISCOVERY',{status:'N/A',required:false,reason:'skip'}),/N\/A/);
});
test('compressed workflows retain acceptance, verification and independent review', () => {
  assert.throws(() => transitionPhase({workflow:['08_FEATURE_IMPLEMENTATION']},'08_FEATURE_IMPLEMENTATION',gate()),/Acceptance/i);
  const state = readyRelease();
  assert.equal(transitionPhase(state,'11_RELEASE_VERIFICATION',gate()).phases['11_RELEASE_VERIFICATION'].status,'PASS');
  for (const field of ['acceptance','verification','review']) { const broken = readyRelease(); delete broken[field]; assert.throws(() => transitionPhase(broken,'11_RELEASE_VERIFICATION',gate())); }
  const same = readyRelease(); same.review.reviewer_role='builder';
  assert.throws(() => transitionPhase(same,'11_RELEASE_VERIFICATION',gate()),/distinct/i);
  assert.throws(() => transitionPhase({...readyRelease(), findings:[{severity:'critical',status:'OPEN'}]},'11_RELEASE_VERIFICATION',gate()),/critical/i);
});
test('production success demands structured nonsimulated production evidence', () => {
  const state = {...readyRelease(),workflow:['13_PRODUCTION_VERIFICATION'],production:true,release:gate(),deployment:gate({status:'DEPLOYED',evidence:[{ref:'external/deploy.log',status:'DEPLOYED',environment:'production',simulated:false}]})};
  for (const evidence of [['fixture.log'],[{ref:'fixture.log',status:'PASS',environment:'production',simulated:true}],[{ref:'fixture.log',status:'PASS',environment:'staging',simulated:false}]]) {
    assert.throws(() => transitionPhase(state,'13_PRODUCTION_VERIFICATION',gate({evidence})),/production/i);
  }
  assert.throws(() => transitionPhase(state,'13_PRODUCTION_VERIFICATION',{status:'N/A',required:false,reason:'Source-only fixture has no deployed service'}),/N\/A/);
  const missingDeployment=structuredClone(state); delete missingDeployment.deployment;
  assert.throws(() => transitionPhase(missingDeployment,'13_PRODUCTION_VERIFICATION',gate()),/deploy/i);
  assert.equal(transitionPhase(state,'13_PRODUCTION_VERIFICATION',gate({status:'VERIFIED_PRODUCTION',evidence:[{ref:'external/smoke.log',status:'PASS',environment:'production',simulated:false}]})).phases['13_PRODUCTION_VERIFICATION'].status,'VERIFIED_PRODUCTION');
});
test('token thresholds preserve verification; dynamic catalog has explicit fallback', () => {
  for (const [used,action] of [[0,'CONTINUE'],[80,'COMPACT'],[100,'CHECKPOINT']]) {
    const result=evaluateTokenBudget({used,soft_limit:80,hard_limit:100}); assert.equal(result.action,action); assert.equal(result.skip_verification,false);
  }
  assert.equal(evaluateTokenBudget({}).action,'MEASURE');
  assert.throws(() => evaluateTokenBudget({used:1,soft_limit:100,hard_limit:80}),/Budget/i);
  const catalog=[{id:'current-fast',description:'fastest affordable model'},{id:'current-balanced',description:'balances intelligence and cost'},{id:'current-capable',description:'strongest for complex professional work'}];
  assert.equal(resolveModelTier('economy',catalog).model,'current-fast');
  assert.equal(resolveModelTier('balanced',catalog).model,'current-balanced');
  assert.equal(resolveModelTier('frontier',catalog).model,'current-capable');
  assert.equal(resolveModelTier('frontier',[]).fallback,true);
  assert.equal(resolveModelTier('frontier',[]).model,null);
});
test('resume preserves exact goal/phase/next task and rejects incomplete verification', () => {
  const checkpoint={goal:'원래 목표',phase:'08_FEATURE_IMPLEMENTATION',next_task:'Continue slice',acceptance_criteria:['Original criterion'],rollback_point:'checkpoint/001'};
  const transition={from_version:'5.1',to_version:'6.0',project_mode:'MAINTENANCE',development_state:'FROZEN_FOR_MIGRATION',checkpoint,current_phase:checkpoint.phase,completed_phases:['04_ACCEPTANCE'],current_work:'slice',carry_forward:{decisions:['ADR001']},new_required_gates:['next phase review'],deferred_rules:[],conflicts:[],resume_from:{goal:checkpoint.goal,phase:checkpoint.phase,next_task:checkpoint.next_task}};
  const verification=Object.fromEntries(['harness_validation','transition_audit','build_baseline','test_baseline','critical_regression','benchmark'].map(key=>[key,gate()]));
  assert.equal(validateResume(transition,verification).goal,checkpoint.goal);
  assert.throws(()=>validateResume({...transition,resume_from:{...transition.resume_from,goal:'replacement'}},verification),/preserve/i);
  for(const key of Object.keys(verification)) { const bad=structuredClone(verification); bad[key].status='FAILED'; assert.throws(()=>validateResume(transition,bad),/blocks/i); }
  assert.throws(()=>transitionDevelopmentState('IN_PROGRESS','FROZEN_FOR_MIGRATION'),/Invalid/);
  assert.throws(()=>transitionDevelopmentState('IN_PROGRESS','SAFE_CHECKPOINT',{checkpoint}),/Checkpoint missing/i);
});
test('one-line adoption is read-only until apply, preserves product and all unmanaged instruction bytes, exact rollback', () => {
  const f=fixture({existing:true});
  writeFileSync(join(f.project,'CLAUDE.md'),'# Claude local\r\nKeep custom rule.\r\n');
  writeFileSync(join(f.project,'GEMINI.md'),'# Gemini local\nKeep custom rule.\n');
  const before=snapshot(f.project);
  const plan=planProject(f); assert.equal(plan.status,'READY'); assert.equal(plan.route.intent,'harness_adoption');
  assert.deepEqual(snapshot(f.project),before,'planning cannot write');
  const applied=applyPlan(plan); assert.equal(applied.status,'PASS'); assert.equal(verifyProject(f.project).status,'PASS');
  for(const name of ['product.txt','verify.mjs']) assert.equal(readFileSync(join(f.project,name)).toString('base64'),before[name]);
  for(const name of ['AGENTS.md','CLAUDE.md','GEMINI.md']) assert.ok(readFileSync(join(f.project,name),'utf8').startsWith(Buffer.from(before[name],'base64').toString('utf8')));
  const restored=rollbackProject(f.project); assert.equal(restored.status,'ROLLED_BACK');
  for(const [name,bytes] of Object.entries(before)) assert.equal(readFileSync(join(f.project,name)).toString('base64'),bytes);
  assert.equal(existsSync(join(f.project,'.ai/harness-project.json')),false);
});
test('active work preserves goal, criteria, phase, completed work, decisions and next task through update', () => {
  const f=fixture({existing:true});
  f.config.state={goal:'사용자 목표',current_phase:'08_FEATURE_IMPLEMENTATION',completed_phases:['01_DISCOVERY','04_ACCEPTANCE'],acceptance_criteria:['Current product criterion'],decisions:['ADR001'],next_task:'Finish existing slice',development_state:'IN_PROGRESS',project_mode:'MAINTENANCE',beginner_mode:false};
  const applied=applyPlan(planProject(f)); assert.equal(applied.status,'PASS');
  const state=JSON.parse(readFileSync(join(f.project,'.ai/harness-state.json'),'utf8'));
  for(const field of ['goal','current_phase','completed_phases','acceptance_criteria','decisions','next_task','beginner_mode']) assert.deepEqual(state[field],f.config.state[field]);
  const manifest=JSON.parse(readFileSync(join(f.project,'.ai/transition-manifest.yaml'),'utf8'));
  assert.equal(manifest.resume_from.goal,f.config.state.goal); assert.equal(manifest.status,'VERIFIED');
  const update=planProject({...f,request:'AI Harness v6.0으로 업데이트해줘',config:{...f.config,state:undefined}}); assert.equal(update.status,'READY');
  assert.equal(update.route.intent,'harness_update'); assert.equal(applyPlan(update).status,'PASS');
});
test('unsafe active operations defer, incomplete active state and missing baselines block', () => {
  const f=fixture();
  const noCommands=planProject({...f,config:{snapshot_root:f.config.snapshot_root}}); assert.equal(noCommands.status,'BLOCKED');
  const incomplete=planProject({...f,config:{...f.config,state:{development_state:'IN_PROGRESS',current_phase:'UNKNOWN'}}}); assert.equal(incomplete.status,'BLOCKED');
  const deferred=planProject({...f,config:{...f.config,state:{operation_in_progress:'deploy'}}}); assert.equal(deferred.status,'DEFERRED');
  assert.throws(()=>applyPlan(deferred),/PLAN_NOT_READY/);
});
test('later product drift and instruction drift invalidate a reviewed plan', () => {
  for(const name of ['product.txt','AGENTS.md']) {
    const f=fixture({existing:true}),plan=planProject(f);
    writeFileSync(join(f.project,name),'Later user edit\n');
    assert.throws(()=>applyPlan(plan),/DRIFT_OR_CONFLICT/);
    assert.equal(existsSync(join(f.project,'.ai/harness-project.json')),false);
  }
});
test('local managed conflict cannot be bypassed by hand editing plan status', () => {
  const f=fixture({existing:true}); applyPlan(planProject(f));
  const p=join(f.project,'AGENTS.md'); writeFileSync(p,readFileSync(p,'utf8').replace('## AI Harness v6','## Custom changed harness rule'));
  const plan=planProject(f); assert.equal(plan.status,'BLOCKED'); assert.ok(plan.conflicts.length);
  assert.throws(()=>applyPlan({...plan,status:'READY'}),/DRIFT_OR_CONFLICT/);
});
test('baseline command failure performs no binding writes and shell descriptors are refused', () => {
  const f=fixture({exit:1}),before=snapshot(f.project);
  assert.throws(()=>applyPlan(planProject(f)),/BASELINE_FAILED/);
  for(const [name,bytes] of Object.entries(before)) assert.equal(readFileSync(join(f.project,name)).toString('base64'),bytes);
  assert.equal(existsSync(join(f.project,'.ai/harness-project.json')),false);
  const shell=fixture(); shell.config.verification_commands.build={command:process.execPath,args:[],shell:true};
  assert.throws(()=>applyPlan(planProject(shell)),/ARGV/);
});
test('failed post-install regression restores managed bytes and records failure', () => {
  const f=fixture({existing:true});
  writeFileSync(join(f.project,'verify.mjs'),"import {existsSync} from 'node:fs'; process.exit(existsSync('.ai/harness-project.json')?1:0);\n");
  const agents=readFileSync(join(f.project,'AGENTS.md'));
  assert.throws(()=>applyPlan(planProject(f)),/REGRESSION_FAILED/);
  assert.deepEqual(readFileSync(join(f.project,'AGENTS.md')),agents);
  assert.equal(existsSync(join(f.project,'.ai/harness-project.json')),false);
  assert.equal(JSON.parse(readFileSync(join(f.project,'.ai/harness-last-transaction.json'),'utf8')).status,'ROLLED_BACK');
});
test('rollback refuses later edits and corrupted backup without overwriting user bytes', () => {
  for(const corrupt of [false,true]) {
    const f=fixture({existing:true}),applied=applyPlan(planProject(f));
    if(corrupt) {
      const journalPath=join(f.project,applied.evidence),journal=JSON.parse(readFileSync(journalPath,'utf8'));
      journal.backups['AGENTS.md']=Buffer.from('corrupt checkpoint').toString('base64'); writeFileSync(journalPath,JSON.stringify(journal));
    } else writeFileSync(join(f.project,'AGENTS.md'),'Later user work');
    const bytes=readFileSync(join(f.project,'AGENTS.md'));
    assert.throws(()=>rollbackProject(f.project),corrupt?/CORRUPT_CHECKPOINT/:/ROLLBACK_DRIFT/);
    assert.deepEqual(readFileSync(join(f.project,'AGENTS.md')),bytes);
  }
});
test('interrupted journal blocks new plans and rollback rejects traversal targets', () => {
  const f=fixture({existing:true}),applied=applyPlan(planProject(f));
  const pointerPath=join(f.project,'.ai/harness-last-transaction.json');
  const pointer=JSON.parse(readFileSync(pointerPath,'utf8')); pointer.status='APPLYING'; writeFileSync(pointerPath,JSON.stringify(pointer));
  assert.equal(planProject(f).status,'BLOCKED');
  const journalPath=join(f.project,applied.evidence),journal=JSON.parse(readFileSync(journalPath,'utf8'));
  journal.backups['../outside.txt']=null; writeFileSync(journalPath,JSON.stringify(journal));
  assert.throws(()=>rollbackProject(f.project),/INVALID_ROLLBACK_TARGET/);
});
test('version mismatch, path traversal and symbolic-link bindings are rejected', t => {
  const f=fixture(); mkdirSync(join(f.project,'.ai'),{recursive:true});
  writeFileSync(join(f.project,'.ai/harness-project.json'),JSON.stringify({harness:{version:'5.1'}}));
  writeFileSync(join(f.project,'.ai/harness.yaml'),JSON.stringify({harness:{version:'6.0'}}));
  assert.throws(()=>inspectProject(f.project,root),/VERSION_MISMATCH/);
  for(const path of ['../outside','/absolute','a/../b','a\\b']) assert.throws(()=>safePath(f.project,path),/PATH/);
  const linked=fixture();
  try {symlinkSync(linked.config.snapshot_root,join(linked.project,'.ai'),'junction');}
  catch(error) { if(['EPERM','EACCES','ENOTSUP'].includes(error.code)) {t.diagnostic(`Link test unavailable: ${error.code}`); return;} throw error; }
  assert.throws(()=>planProject(linked),/SYMLINK/);
});
test('immutable source snapshots are checked during verification', () => {
  const f=fixture(),applied=applyPlan(planProject(f));
  const original=sourceIdentity(applied.harness_root);
  writeFileSync(join(applied.harness_root,'CORE.md'),readFileSync(join(applied.harness_root,'CORE.md'),'utf8')+'\nTampered snapshot\n');
  assert.notEqual(sourceIdentity(applied.harness_root).hash,original.hash);
  assert.equal(verifyProject(f.project).status,'FAIL');
});
test('pinned snapshot version disagreement blocks verification', () => {
  const f=fixture(),applied=applyPlan(planProject(f));
  writeFileSync(join(applied.harness_root,'HARNESS_VERSION'),'5.1\n');
  assert.throws(()=>verifyProject(f.project),/SOURCE_VERSION_MISMATCH/);
});
test('justified build and test nonapplicability retains a real critical regression', () => {
  const f=fixture();
  f.config.verification_commands.build={required:false,reason:'This plain-text fixture has no compilation stage.'};
  f.config.verification_commands.test={required:false,reason:'The only applicable product assertion is the configured critical regression.'};
  const applied=applyPlan(planProject(f)); assert.equal(applied.status,'PASS');
  assert.equal(verifyProject(f.project).status,'PASS');
  assert.equal(applied.transition.verification.build_baseline.status,'N/A');
  assert.equal(applied.transition.verification.critical_regression.status,'PASS');
});
test('failed rollback verification reports failure after exact byte restoration', () => {
  const f=fixture({existing:true});
  writeFileSync(join(f.project,'verify.mjs'),"import {existsSync} from 'node:fs'; process.exit(existsSync('.ai/force-fail.txt')?1:0);\n");
  const agents=readFileSync(join(f.project,'AGENTS.md'));
  applyPlan(planProject(f)); writeFileSync(join(f.project,'.ai/force-fail.txt'),'failure trigger');
  assert.equal(rollbackProject(f.project).status,'ROLLBACK_VERIFICATION_FAILED');
  assert.deepEqual(readFileSync(join(f.project,'AGENTS.md')),agents);
});
test('config state cannot erase an observed active deployment', () => {
  const f=fixture(); applyPlan(planProject(f));
  const statePath=join(f.project,'.ai/harness-state.json'),state=JSON.parse(readFileSync(statePath,'utf8'));
  state.operation_in_progress='deploy'; state.development_state='IN_PROGRESS'; writeFileSync(statePath,JSON.stringify(state));
  const before=readFileSync(statePath);
  assert.throws(()=>planProject({...f,config:{...f.config,state:{operation_in_progress:null,development_state:'STABLE'}}}),/STATE_OVERRIDE_CONFLICT/);
  assert.deepEqual(readFileSync(statePath),before);
  assert.equal(planProject({...f,config:{...f.config,state:undefined}}).status,'DEFERRED');
});
test('CLI normal route and phase reject pinned source drift without modifying phase state', () => {
  const f=fixture(),applied=applyPlan(planProject(f));
  writeFileSync(join(applied.harness_root,'CORE.md'),readFileSync(join(applied.harness_root,'CORE.md'),'utf8')+'\nChanged pinned content\n');
  const statePath=join(f.project,'.ai/harness-state.json'),before=readFileSync(statePath);
  const contractPath=join(f.config.snapshot_root,'phase-contract.json'); writeFileSync(contractPath,JSON.stringify(gate()));
  for(const args of [
    ['route','--request','Fix small product bug'],
    ['phase','--phase','00_INTAKE','--contract',contractPath],
  ]) {
    const cli=spawnSync(process.execPath,[join(root,'scripts/harness-v6.mjs'),...args,'--project',f.project,'--source',root],{encoding:'utf8',windowsHide:true,timeout:15000});
    assert.notEqual(cli.status,0); const output=JSON.parse(cli.stdout); assert.equal(output.status,'BLOCKED'); assert.match(output.error,/SOURCE|PINNED|DRIFT|MISMATCH/);
    assert.deepEqual(readFileSync(statePath),before);
  }
});
function legacyFixture() {
  const f=fixture({existing:true}),legacy=readFileSync(join(root,'harness/update/legacy/PROJECT_INIT_v5_1.md'),'utf8').replaceAll('\r\n','\n');
  const instructions=legacy.match(/```markdown\n(<!-- AI-HARNESS:START -->\n## Global AI Harness[\s\S]*?<!-- AI-HARNESS:END -->)\n```/)[1];
  const bridge=legacy.match(/```text\n(GLOBAL HARNESS ROOT:\n[\s\S]*?)\n```/)[1].replaceAll('<실제 HARNESS_ROOT>',root.replaceAll('\\','/')).replaceAll('<HARNESS_ROOT>',root.replaceAll('\\','/'));
  mkdirSync(join(f.project,'.ai'),{recursive:true});
  writeFileSync(join(f.project,'AGENTS.md'),'# Product rules\n\n'+instructions+'\n\nKeep original scope.\n');
  writeFileSync(join(f.project,'.ai/HARNESS.md'),'# AI Harness Project Bridge\n\n'+bridge+'\n');
  writeFileSync(join(f.project,'.ai/harness.yaml'),`harness:\n  version: "5.1"\n  root: "${root.replaceAll('\\','/')}"\n  policy_count: 26\ncustom_project_rule: "preserve me"\n`);
  f.request='AI Harness v6.0으로 업데이트해줘';
  return f;
}
test('actual registered v5.1 templates upgrade to v6 and rollback retains all original custom bytes', () => {
  const f=legacyFixture(),before=snapshot(f.project),plan=planProject(f);
  assert.equal(plan.status,'READY'); assert.equal(plan.from_version,'5.1.0'); assert.equal(plan.route.update_class,'H3');
  const applied=applyPlan(plan); assert.equal(applied.status,'PASS');
  assert.equal(applied.transition.from_version,'5.1.0');
  assert.equal(JSON.parse(readFileSync(join(f.project,'.ai/harness.yaml'),'utf8')).legacy_customization_reference,Buffer.from(before['.ai/harness.yaml'],'base64').toString('utf8'));
  assert.equal(rollbackProject(f.project).status,'ROLLED_BACK');
  for(const [name,bytes] of Object.entries(before)) assert.equal(readFileSync(join(f.project,name)).toString('base64'),bytes);
});
test('customized v5 bridge and heading-only managed instructions are preserved as conflicts', () => {
  for(const target of ['.ai/HARNESS.md','AGENTS.md']) {
    const f=legacyFixture(),p=join(f.project,target);
    if(target==='AGENTS.md') writeFileSync(p,'# User instructions\n<!-- AI-HARNESS:START -->\n## Global AI Harness\nKeep my special critical rule.\n<!-- AI-HARNESS:END -->\n');
    else writeFileSync(p,readFileSync(p,'utf8')+'\nCustom critical project rule.\n');
    const before=readFileSync(p),plan=planProject(f); assert.equal(plan.status,'BLOCKED'); assert.ok(plan.conflicts.some(c=>c.file===target));
    assert.throws(()=>applyPlan({...plan,status:'READY'})); assert.deepEqual(readFileSync(p),before);
  }
});
test('plain YAML credentials and token argv pairs are rejected before plan serialization', () => {
  const yaml=legacyFixture();
  const p=join(yaml.project,'.ai/harness.yaml'); writeFileSync(p,readFileSync(p,'utf8')+'password: fixture-only-placeholder\n');
  const before=readFileSync(p); assert.throws(()=>planProject(yaml),/SECRET|CREDENTIAL/); assert.deepEqual(readFileSync(p),before);
  const argv=fixture(); argv.config.verification_commands.build={command:process.execPath,args:['--token','fixture-only-placeholder']};
  assert.throws(()=>planProject(argv),/CREDENTIAL/);
});
test('intermediate recorded state write recovers from an interrupted journal', () => {
  const f=fixture({existing:true}),before=readFileSync(join(f.project,'AGENTS.md')),applied=applyPlan(planProject(f));
  const statePath=join(f.project,'.ai/harness-state.json'),state=JSON.parse(readFileSync(statePath,'utf8'));
  state.development_state='FROZEN_FOR_MIGRATION'; delete state.last_migration;
  const bytes=JSON.stringify(state,null,2)+'\n',digest=createHash('sha256').update(bytes).digest('hex');
  const journal=JSON.parse(readFileSync(join(f.project,applied.evidence),'utf8'));
  assert.ok(journal.hash_history['.ai/harness-state.json'].includes(digest),'journal must record pre-resume write hash before updating final state');
  writeFileSync(statePath,bytes);
  const pointerPath=join(f.project,'.ai/harness-last-transaction.json'),pointer=JSON.parse(readFileSync(pointerPath,'utf8')); pointer.status='APPLYING'; writeFileSync(pointerPath,JSON.stringify(pointer));
  assert.equal(rollbackProject(f.project).status,'ROLLED_BACK'); assert.deepEqual(readFileSync(join(f.project,'AGENTS.md')),before);
});
test('snapshot ancestor junction is refused before writing through the link', t => {
  const f=fixture(),target=fixture();
  const linked=join(f.config.snapshot_root,'linked-ancestor');
  try {symlinkSync(target.config.snapshot_root,linked,'junction');}
  catch(error) {if(['EPERM','EACCES','ENOTSUP'].includes(error.code)){t.diagnostic(`Ancestor link test unavailable: ${error.code}`);return;}throw error;}
  f.config.snapshot_root=join(linked,'nested-snapshots'); const before=snapshot(target.config.snapshot_root);
  assert.throws(()=>applyPlan(planProject(f)),/SYMLINK/);
  assert.deepEqual(snapshot(target.config.snapshot_root),before);
});
test('failed exit-code evidence cannot be promoted to phase success', () => {
  assert.throws(()=>transitionPhase({workflow:['00_INTAKE']},'00_INTAKE',gate({evidence:[{ref:'fixture/failure.log',status:'PASS',exit_code:1}]})),/failed|exit|evidence/i);
});
test('UTF-16 unmanaged instructions block safely instead of rewriting custom bytes', () => {
  const f=fixture({existing:true}),p=join(f.project,'AGENTS.md'),bytes=Buffer.concat([Buffer.from([255,254]),Buffer.from('# 사용자 규칙\r\nKeep scope.\r\n','utf16le')]);
  writeFileSync(p,bytes); assert.throws(()=>planProject(f),/ENCODING|UTF.?16/i); assert.deepEqual(readFileSync(p),bytes);
});
test('CLI changed or deleted recorded phase artifacts block subsequent progress', () => {
  const f=fixture(); applyPlan(planProject(f));
  const statePath=join(f.project,'.ai/harness-state.json'),state=JSON.parse(readFileSync(statePath,'utf8'));
  state.workflow=['00_INTAKE','01_DISCOVERY']; writeFileSync(statePath,JSON.stringify(state));
  const artifact=join(f.project,'.ai/intake-evidence.log'),contract=join(f.config.snapshot_root,'contract.json');
  writeFileSync(artifact,'Original assertion evidence'); writeFileSync(contract,JSON.stringify(gate({evidence:['.ai/intake-evidence.log']})));
  const cli=phase=>spawnSync(process.execPath,[join(root,'scripts/harness-v6.mjs'),'phase','--phase',phase,'--contract',contract,'--project',f.project,'--source',root],{encoding:'utf8',windowsHide:true,timeout:15000});
  const first=cli('00_INTAKE'); assert.equal(first.status,0,first.stdout);
  const before=readFileSync(statePath); writeFileSync(artifact,'Changed assertion evidence');
  const changed=cli('01_DISCOVERY'); assert.notEqual(changed.status,0); assert.match(JSON.parse(changed.stdout).error,/ARTIFACT|EVIDENCE|DRIFT/); assert.deepEqual(readFileSync(statePath),before);
  rmSync(artifact);
  const deleted=cli('01_DISCOVERY'); assert.notEqual(deleted.status,0); assert.match(JSON.parse(deleted.stdout).error,/ARTIFACT|EVIDENCE|MISSING/); assert.deepEqual(readFileSync(statePath),before);
});
test('legacy active work requires faithful canonical mapping and state references invalidate stale plans', () => {
  const f=legacyFixture(),legacyPath=join(f.project,'.ai/current-state.md');
  const legacy='# Current Project State\n\nStatus: IN_PROGRESS\n\nCurrent Goal:\n- Preserve existing delivery\n\nCurrent Phase:\n- 08_FEATURE_IMPLEMENTATION\n\nNext Step:\n- Finish the current slice\n';
  writeFileSync(legacyPath,legacy);
  const unmapped=planProject(f); assert.equal(unmapped.status,'BLOCKED'); assert.ok(unmapped.conflicts.some(c=>c.kind==='LEGACY_STATE_REQUIRES_MAPPING'));
  f.config.state={goal:'Preserve existing delivery',current_phase:'08_FEATURE_IMPLEMENTATION',next_task:'Finish the current slice',acceptance_criteria:['Preserve original acceptance'],completed_phases:['04_ACCEPTANCE'],decisions:['ADR001'],project_mode:'MAINTENANCE',development_state:'IN_PROGRESS'};
  const mapped=planProject(f); assert.equal(mapped.status,'READY');
  const wrong=planProject({...f,config:{...f.config,state:{...f.config.state,current_phase:'00_INTAKE'}}}); assert.equal(wrong.status,'BLOCKED');
  writeFileSync(join(f.project,'.ai/active-spec.md'),'Changed specification after review');
  assert.throws(()=>applyPlan(mapped),/DRIFT_OR_CONFLICT/);
  const applied=applyPlan(planProject(f)); assert.equal(applied.status,'PASS');
  assert.equal(readFileSync(legacyPath,'utf8'),legacy);
  const state=JSON.parse(readFileSync(join(f.project,'.ai/harness-state.json'),'utf8'));
  assert.equal(state.current_phase,'08_FEATURE_IMPLEMENTATION'); assert.deepEqual(state.completed_phases,['04_ACCEPTANCE']); assert.deepEqual(state.decisions,['ADR001']);
});
test('changed product invalidates prior automated verification before review', () => {
  const f=fixture(); applyPlan(planProject(f));
  const statePath=join(f.project,'.ai/harness-state.json'),state=JSON.parse(readFileSync(statePath,'utf8'));
  state.workflow=['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW']; writeFileSync(statePath,JSON.stringify(state));
  writeFileSync(join(f.project,'.ai/verification.log'),'Recorded fixture evidence');
  const contract=join(f.config.snapshot_root,'contract.json');
  const cli=phase=>spawnSync(process.execPath,[join(root,'scripts/harness-v6.mjs'),'phase','--phase',phase,'--contract',contract,'--project',f.project,'--source',root],{encoding:'utf8',windowsHide:true,timeout:15000});
  writeFileSync(contract,JSON.stringify(gate({evidence:['.ai/verification.log']})));
  for(const phase of ['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION']) {const result=cli(phase);assert.equal(result.status,0,result.stdout);}
  const before=readFileSync(statePath); writeFileSync(join(f.project,'product.txt'),'Product changed after successful verification');
  writeFileSync(contract,JSON.stringify(review()));
  const result=cli('10_INDEPENDENT_REVIEW'); assert.notEqual(result.status,0); assert.match(JSON.parse(result.stdout).error,/VERIFICATION_SUBJECT_DRIFT/); assert.deepEqual(readFileSync(statePath),before);
});
test('compressed standalone gates retain recorded artifact freshness checks', () => {
  const f=fixture(); applyPlan(planProject(f));
  const statePath=join(f.project,'.ai/harness-state.json'),state=JSON.parse(readFileSync(statePath,'utf8'));
  state.workflow=['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW']; writeFileSync(statePath,JSON.stringify(state));
  const artifact=join(f.project,'.ai/gates.log'),contract=join(f.config.snapshot_root,'contract.json'); writeFileSync(artifact,'Recorded gate evidence');
  const cli=phase=>spawnSync(process.execPath,[join(root,'scripts/harness-v6.mjs'),'phase','--phase',phase,'--contract',contract,'--project',f.project,'--source',root],{encoding:'utf8',windowsHide:true,timeout:15000});
  for(const phase of ['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW']) {
    writeFileSync(contract,JSON.stringify(gate({evidence:['.ai/gates.log'],...(phase==='10_INDEPENDENT_REVIEW'?{builder_role:'builder',reviewer_role:'reviewer'}:{})})));
    const result=cli(phase); assert.equal(result.status,0,result.stdout);
  }
  const compressed=JSON.parse(readFileSync(statePath,'utf8'));
  compressed.acceptance=compressed.phases['04_ACCEPTANCE']; compressed.verification=compressed.phases['09_AUTOMATED_VERIFICATION']; compressed.review=compressed.phases['10_INDEPENDENT_REVIEW']; compressed.phases={}; compressed.workflow=['11_RELEASE_VERIFICATION'];
  writeFileSync(statePath,JSON.stringify(compressed)); const before=readFileSync(statePath);
  writeFileSync(artifact,'Changed standalone gate evidence'); writeFileSync(contract,JSON.stringify(gate({evidence:['.ai/gates.log']})));
  const result=cli('11_RELEASE_VERIFICATION'); assert.notEqual(result.status,0); assert.match(JSON.parse(result.stdout).error,/EVIDENCE_ARTIFACT_DRIFT/); assert.deepEqual(readFileSync(statePath),before);
});
test('reviewed target version cannot be forged without rejection and no writes', () => {
  const f=fixture(),plan=planProject(f),before=snapshot(f.project);
  for(const changes of [{to_version:'99.0.0'},{from_version:'1.0.0'},{legacy_binding:'custom forged contract'}]) assert.throws(()=>applyPlan({...plan,...changes}),/PLAN_SEMANTIC_DRIFT/);
  assert.deepEqual(snapshot(f.project),before);
});
test('editing upstream acceptance invalidates downstream canonical and compressed evidence', () => {
  const state={workflow:['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW','11_RELEASE_VERIFICATION'],phases:{'04_ACCEPTANCE':gate(),'09_AUTOMATED_VERIFICATION':gate(),'10_INDEPENDENT_REVIEW':review(),'11_RELEASE_VERIFICATION':gate()},verification:gate(),review:review(),release:gate(),deployment:gate({status:'DEPLOYED'})};
  const revised=transitionPhase(state,'04_ACCEPTANCE',gate({acceptance_criteria:['Revised accepted requirement']}));
  for(const id of ['09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW','11_RELEASE_VERIFICATION']) {assert.equal(revised.phases[id].status,'NOT_STARTED');assert.equal(revised.phases[id].invalidated_by,'04_ACCEPTANCE');}
  for(const alias of ['verification','review','release','deployment']) assert.equal(revised[alias].status,'NOT_STARTED');
  assert.throws(()=>transitionPhase({...revised,workflow:['11_RELEASE_VERIFICATION']},'11_RELEASE_VERIFICATION',gate()),/blocks|verification/i);
  assert.equal(state.verification.status,'PASS','pure transition leaves prior state unchanged');
});
test('clean Git consumer can apply the exact CLI plan saved under .ai', () => {
  const f=fixture({existing:true});
  const git=args=>{const result=spawnSync('git',['-C',f.project,...args],{encoding:'utf8',windowsHide:true,timeout:15000});assert.equal(result.status,0,result.stderr);};
  git(['init','-q']);git(['config','user.name','Harness fixture']);git(['config','user.email','fixture@example.invalid']);git(['add','AGENTS.md','product.txt','verify.mjs']);git(['commit','-qm','fixture baseline']);
  const config=join(f.config.snapshot_root,'config.json');writeFileSync(config,JSON.stringify(f.config));
  const saved=join(f.project,'.ai/v6-plan.json');
  const invoke=args=>spawnSync(process.execPath,[join(root,'scripts/harness-v6.mjs'),...args],{encoding:'utf8',windowsHide:true,timeout:30000});
  const planned=invoke(['plan','--project',f.project,'--source',root,'--request','이 프로젝트 하네스 설치해줘','--config',config,'--out',saved]);
  assert.equal(planned.status,0,planned.stdout);assert.equal(JSON.parse(readFileSync(saved,'utf8')).status,'READY');
  const product=readFileSync(join(f.project,'product.txt'));
  const applied=invoke(['apply','--plan',saved]);assert.equal(applied.status,0,applied.stdout);assert.equal(JSON.parse(applied.stdout).status,'PASS');
  assert.deepEqual(readFileSync(join(f.project,'product.txt')),product);
});
test('truly empty GREENFIELD install and verify require no invented product commands', () => {
  const project=mkdtempSync(join(tmpdir(),'harness-v6-test-')),snapshotRoot=mkdtempSync(join(tmpdir(),'harness-v6-test-'));fixtureRoots.push(project,snapshotRoot);
  assert.deepEqual(readdirSync(project),[]);
  const plan=planProject({project,sourceRoot:root,request:'이 프로젝트 하네스 설치해줘',config:{snapshot_root:snapshotRoot}});
  assert.equal(plan.status,'READY');assert.equal(plan.route.project_mode,'GREENFIELD');assert.deepEqual(plan.verification_commands,{});
  const applied=applyPlan(plan);assert.equal(applied.status,'PASS');assert.equal(verifyProject(project).status,'PASS');
  assert.equal(inspectProject(project).has_product,false);
  assert.equal(existsSync(join(project,'product.txt')),false);assert.equal(existsSync(join(project,'verify.mjs')),false);
  assert.equal(rollbackProject(project).status,'ROLLED_BACK');
});
test('all sixteen local phase gates execute in order with justified nonproduction applicability', () => {
  let state={workflow:[...PHASES],phases:{},goal:'Local lifecycle simulator',production:false,project_mode:'GREENFIELD'};
  for(const id of PHASES) {
    const contract=['12_DEPLOY','13_PRODUCTION_VERIFICATION'].includes(id)?{status:'N/A',required:false,reason:'This local harness simulator has no deployed product or production service.'}:id==='10_INDEPENDENT_REVIEW'?review():gate();
    state=transitionPhase(state,id,contract);assert.equal(state.current_phase,id);
  }
  assert.equal(Object.keys(state.phases).length,16);assert.equal(state.next_action,'COMPLETE');
  assert.equal(state.phases['12_DEPLOY'].status,'N/A');assert.equal(state.phases['13_PRODUCTION_VERIFICATION'].status,'N/A');
});
test('four project modes select distinct workflows while retaining mandatory gates', () => {
  const routes=[routeTask('Create a new project'),routeTask('Fix existing bug',{has_product:true}),routeTask('긴급 장애 hotfix',{has_product:true}),routeTask('database schema migration',{has_product:true})];
  assert.deepEqual(routes.map(r=>r.project_mode),['GREENFIELD','MAINTENANCE','HOTFIX','MIGRATION']);
  assert.equal(new Set(routes.map(r=>JSON.stringify(r.workflow))).size,4);
  for(const route of routes)for(const gate of ['04_ACCEPTANCE','09_AUTOMATED_VERIFICATION','10_INDEPENDENT_REVIEW','13_PRODUCTION_VERIFICATION'])assert.ok(route.workflow.includes(gate));
});
