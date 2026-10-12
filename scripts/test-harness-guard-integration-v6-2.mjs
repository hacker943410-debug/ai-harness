import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,existsSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,dirname,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {planProject,applyPlan,verifyProject} from './harness-project.mjs';
import {main} from './harness-guard-v6-2.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
function setup(t){
 const p=mkdtempSync(join(tmpdir(),'v62-guard-project-'));
 const snapshots=mkdtempSync(join(tmpdir(),'v62-guard-snapshot-'));
 t.after(()=>{rmSync(p,{recursive:true,force:true});rmSync(snapshots,{recursive:true,force:true});});
 writeFileSync(join(p,'app.js'),'const x=1;\n');
 const check=join(p,'check.mjs');
 writeFileSync(check,'process.exit(0);\n');
 const command={command:process.execPath,args:[check]};
 const config={snapshot_root:snapshots,verification_commands:{
    build:command,test:command,critical_regression:command
 }};
 const plan=planProject({project:p,sourceRoot:root,request:'이 프로젝트 하네스 설치해줘',config});
 assert.equal(plan.status,'READY');
 const applied=applyPlan(plan);
 assert.equal(applied.status,'PASS');
 assert.equal(verifyProject(p).status,'PASS');
 return {project:p,check};
}
const fake={runCodex:async()=>({
 exit_code:0,signal:null,overflow:false,
 summary:{turns:1,events:2,errors:0,parse_errors:0,
 actual_usage:{input_tokens:40,output_tokens:8,cached_input_tokens:0,total_tokens:48}}
})};
const skippedJev={evaluateJevShadow:async()=>({
 status:'READY_NOT_ACTIVATED',used:false,fallback:true,route_changed:false
})};
const req=p=>['run','--project',p,'--request','Fix a small UI button','--soft-limit','50','--hard-limit','100'];

test('real installed project + fake Codex emits validated completion evidence',async t=>{
 const {project}=setup(t);
 const result=await main(req(project),{...fake,...skippedJev});
 assert.equal(result,0);
 const latest=JSON.parse(readFileSync(join(project,'.ai/harness-guard/latest.json'),'utf8'));
 assert.equal(latest.status,'PASS');
 assert.equal(latest.verification.status,'PASS');
 assert.equal(latest.budget.action,'CONTINUE');
 assert.equal(latest.token_usage.total_tokens,48);
 assert.equal(latest.jev.route_changed,false);
 assert.equal(latest.actual_agent_policy_reads,'UNOBSERVED');
 assert.equal(latest.actual_model,'UNKNOWN');
 assert.equal(await main(['report','--project',project]),0);
});
test('missing provider usage cannot achieve PASS even with passing project build/test',async t=>{
 const {project}=setup(t);
 const runCodex=async()=>({...await fake.runCodex(),summary:{
  turns:1,events:2,errors:0,parse_errors:0,actual_usage:null
 }});
 assert.equal(await main(req(project),{runCodex,...skippedJev}),2);
 const latest=JSON.parse(readFileSync(join(project,'.ai/harness-guard/latest.json'),'utf8'));
 assert.equal(latest.status,'FAIL');
 assert.equal(latest.token_measurement,'UNKNOWN_NO_PROVIDER_USAGE_FAIL_CLOSED');
});
test('failed project verification cannot achieve PASS even with valid provider usage',async t=>{
 const {project,check}=setup(t);
 writeFileSync(check,'process.exit(3);\n');
 assert.equal(await main(req(project),{...fake,...skippedJev}),2);
 const latest=JSON.parse(readFileSync(join(project,'.ai/harness-guard/latest.json'),'utf8'));
 assert.equal(latest.verification.status,'FAIL');
 assert.equal(latest.status,'FAIL');
});
test('hard budget on completed turn blocks subsequent managed run without checkpoint',async t=>{
 const {project}=setup(t);
 const hard={runCodex:async()=>({...await fake.runCodex(),summary:{
  turns:1,events:2,errors:0,parse_errors:0,actual_usage:{
   input_tokens:97,output_tokens:7,cached_input_tokens:0,total_tokens:104
  }
 }})};
 assert.equal(await main(req(project),{...hard,...skippedJev}),0);
 const latest=JSON.parse(readFileSync(join(project,'.ai/harness-guard/latest.json'),'utf8'));
 assert.equal(latest.budget.action,'CHECKPOINT_REQUIRED');
 await assert.rejects(main(req(project),{...fake,...skippedJev}),/PREVIOUS_HARD_BUDGET_REQUIRES_CHECKPOINT/);
 const f=join(project,'.ai','harness-guard','checkpoint.json');
 mkdirSync(dirname(f),{recursive:true});
 writeFileSync(f,JSON.stringify({kind:'harness-budget-checkpoint',
  previous_run_id:latest.run_id,source_hash:latest.source_hash,
  goal:'Fix the UI',current_phase:'08_FEATURE_IMPLEMENTATION',acceptance_criteria:['UI updated'],
  next_task:'Run verification'}));
 assert.equal(await main([...req(project),'--checkpoint-evidence','.ai/harness-guard/checkpoint.json'],
  {...fake,...skippedJev}),0);
});
test('missing token budget prevents fake agent run',async t=>{
 const {project}=setup(t);let called=false;
 await assert.rejects(main(['run','--project',project,'--request','Fix a UI button'],{
   runCodex:async()=>{called=true;return fake.runCodex()}
 }),/TOKEN_BUDGET_UNCONFIGURED/);
 assert.equal(called,false);
});
