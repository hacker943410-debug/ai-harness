import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {planProject,applyPlan,verifyProject,validateClientTargets} from './harness-project.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
function fixture(t,{claudeFile=false,geminiFile=false}={}){
 const base=fs.mkdtempSync(path.join(os.tmpdir(),'harness-triad-'));
 const project=path.join(base,'project'),snapshots=path.join(base,'snapshots');
 fs.mkdirSync(project);fs.mkdirSync(snapshots);
 if(claudeFile)fs.writeFileSync(path.join(project,'CLAUDE.md'),'# Custom Claude rules\nStay concise.\n');
 if(geminiFile)fs.writeFileSync(path.join(project,'GEMINI.md'),'# Historical Gemini instructions\nDo not remove.\n');
 t.after(()=>fs.rmSync(base,{recursive:true,force:true}));
 return {base,project,snapshots};
}
const request='이 프로젝트에 AI Harness 적용해줘';
test('explicit cli targets normalize and reject legacy Gemini and duplicate IDs',()=>{
 assert.deepEqual(validateClientTargets(['codex','claude','agy']),['agy','claude','codex']);
 assert.throws(()=>validateClientTargets(['gemini']),/UNSUPPORTED_CLIENT_TARGETS/);
 assert.throws(()=>validateClientTargets(['claude','claude']),/UNSUPPORTED_CLIENT_TARGETS/);
 assert.throws(()=>validateClientTargets('codex,claude,agy'),/UNSUPPORTED_CLIENT_TARGETS/);
});
test('default installer retains previous behavior; no surprise Claude or Gemini file',t=>{
 const {project,snapshots}=fixture(t);
 const p=planProject({project,sourceRoot:root,request,config:{snapshot_root:snapshots}});
 assert.equal(p.status,'READY');
 assert.ok(!p.actions.some(x=>x.file==='CLAUDE.md'));
 assert.equal(applyPlan(p).status,'PASS');
 assert.ok(fs.existsSync(path.join(project,'AGENTS.md')));
 assert.ok(!fs.existsSync(path.join(project,'CLAUDE.md')));
 assert.ok(!fs.existsSync(path.join(project,'GEMINI.md')));
});
test('explicit three-client plan creates thin Claude and shared Codex/AGY AGENTS',t=>{
 const {project,snapshots}=fixture(t);
 const p=planProject({project,sourceRoot:root,request,config:{client_targets:['codex','claude','agy'],snapshot_root:snapshots}});
 assert.equal(p.status,'READY');
 assert.deepEqual(p.client_targets,['agy','claude','codex']);
 assert.ok(p.actions.some(x=>x.file==='CLAUDE.md'));
 assert.equal(applyPlan(p).status,'PASS');
 const agent=fs.readFileSync(path.join(project,'AGENTS.md'),'utf8');
 const claude=fs.readFileSync(path.join(project,'CLAUDE.md'),'utf8');
 assert.match(agent,/AI-HARNESS:START/);assert.match(claude,/AI-HARNESS:START/);
 assert.match(agent,/Pinned version: 7\.0\.0/);assert.match(claude,/Pinned version: 7\.0\.0/);
 assert.ok(!fs.existsSync(path.join(project,'GEMINI.md')));
 assert.equal(verifyProject(project).status,'PASS');
});
test('existing custom Claude/Gemini instructions are preserved outside managed blocks',t=>{
 const {project,snapshots}=fixture(t,{claudeFile:true,geminiFile:true});
 const p=planProject({project,sourceRoot:root,request,config:{client_targets:['codex','claude','agy'],snapshot_root:snapshots}});
 assert.equal(p.status,'READY');
 assert.equal(applyPlan(p).status,'PASS');
 const claude=fs.readFileSync(path.join(project,'CLAUDE.md'),'utf8');
 const gemini=fs.readFileSync(path.join(project,'GEMINI.md'),'utf8');
 assert.match(claude,/Stay concise/);
 assert.match(gemini,/Historical Gemini instructions/);
 assert.match(claude,/AI-HARNESS:START/);
 assert.equal(verifyProject(project).status,'PASS');
});
test('CLI --clients option creates an auditable reviewed plan, not actual provider activation',t=>{
 const {base,project,snapshots}=fixture(t);
 const args=['scripts/harness-v6.mjs','plan','--project',project,'--request',request,
  '--clients','codex,claude,agy','--out',path.join(project,'.ai','triad-plan.json'),
  '--config',path.join(base,'approved-input.json')];
 fs.writeFileSync(path.join(base,'approved-input.json'),JSON.stringify({snapshot_root:snapshots}));
 const p=spawnSync(process.execPath,args,{cwd:root,encoding:'utf8',timeout:45000});
 assert.equal(p.status,0,p.stderr+' '+p.stdout.slice(0,1600));
 const result=JSON.parse(fs.readFileSync(path.join(project,'.ai','triad-plan.json'),'utf8'));
 assert.equal(result.status,'READY');
 assert.ok(result.actions.some(x=>x.file==='CLAUDE.md'));
 assert.ok(!fs.existsSync(path.join(project,'CLAUDE.md')));
});
