import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import os from 'node:os';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {install} from '../lib/install.mjs';import {rootFor,treeFiles,hash,fileHash} from '../lib/io.mjs';import * as hub from '../lib/skills.mjs';import * as flow from '../lib/workflow.mjs';import {projectState,events} from '../lib/events.mjs';
const cli=fileURLToPath(new URL('../cli.mjs',import.meta.url));
function fixture(){const root=fs.mkdtempSync(path.join(os.tmpdir(),'jh stability 한글 ')),h=path.join(root,'home'),project=path.join(root,'project');fs.mkdirSync(h);fs.mkdirSync(project);install(h);return{root,h,project};}
const snap=root=>JSON.stringify(treeFiles(root));
test('readonly CLI queries never create or modify home/project files',()=>{
 const{root,h,project}=fixture(),skill=path.join(rootFor(h),'runtime/core/skills/jh-web-quality');
 const commands=[['status'],['doctor'],['skills','list'],['skills','search','웹 테스트'],['skills','read','jh-web-quality'],['skills','inspect','--path',skill],['policy','read','P06'],['progress'],['lessons']];
 const writes=[];for(const args of commands){const before=snap(root),r=spawnSync(process.execPath,[cli,...args,'--codex-home',h,'--project',project],{encoding:'utf8',windowsHide:true});assert.equal(r.status,0,r.stderr);if(snap(root)!==before)writes.push(args.join(' '));}
 assert.deepEqual(writes,[],'Query commands changed files');
 assert.equal(fs.existsSync(path.join(project,'.jh-artifacts')),false);
});
test('Skill scalar descriptions preserve multiline content, singleline compatibility and explicit support status',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'jh metadata '));
 const cases=[
 ['folded','>-\n  Operate Orca-managed worktrees,\n  terminals and artifacts.','Operate Orca-managed worktrees, terminals and artifacts.'],
 ['single','Review local files.','Review local files.'],
 ['quoted','"Review: files # safely."','Review: files # safely.'],
 ['single-quoted',"'Don''t truncate this.'","Don't truncate this."],
 ['literal','|-\n  First line.\n  Second line.','First line.\nSecond line.'],
 ['paragraphs','>-\n  First paragraph.\n\n  Second paragraph.','First paragraph.\nSecond paragraph.'],
 ['clip','>\n  First line.\n  Second line.','First line. Second line.\n'],
 ['keep','|+\n  Keep newline.\n','Keep newline.\n\n'],
 ['indent','>2-\n  Explicit indent.\n  All words.','Explicit indent. All words.'],
 ['plain-continuation','A first line\n  and its continuation.','A first line and its continuation.'],
 ['quoted-continuation','"A first line\n  and its continuation."','A first line and its continuation.'],
 ['spaced-header','"A complete description."\n','A complete description.'],
 ['quoted-paragraphs','"First paragraph.\n\n  Second paragraph."','First paragraph.\nSecond paragraph.'],
 ];
 for(const[name,description,expected]of cases){const dir=path.join(root,name);fs.mkdirSync(dir);const file=path.join(dir,'SKILL.md');fs.writeFileSync(file,'---\r\nname: '+name+'\r\ndescription: '+description.replaceAll('\n','\r\n')+'\r\n---\r\n# Read only.\r\n');const row=hub.metadata(file);assert.equal(row.description,expected,name);assert.equal(row.name,name);assert.equal(row.file,file);}
 const{h,project}=fixture(),folder=path.join(project,'.agents/skills/metadata-only');fs.mkdirSync(folder,{recursive:true});fs.writeFileSync(path.join(folder,'SKILL.md'),'---\nname: metadata-only\ndescription: >-\n  Locate worktrees and terminals.\n  Preserve the entire explanation.\n---\nRead only.\n');
 const row=hub.list(h,project,{includeUser:false}).find(x=>x.name==='metadata-only');assert.equal(row.status,'SUPPORTED');assert.equal(row.supported,true);assert.equal(row.execution,'INSTRUCTIONS_ONLY_NO_AUTO_SCRIPT_EXECUTION');assert.ok(hub.search(h,project,'terminals',{includeUser:false}).some(x=>x.name==='metadata-only'));
 fs.writeFileSync(path.join(folder,'SKILL.md'),'---\nname: metadata-only\ndescription: *unknown-anchor\n---\n');
 const bad=hub.list(h,project,{includeUser:false}).find(x=>x.name==='metadata-only');assert.equal(bad.supported,false);assert.match(bad.status,/UNSUPPORTED|INVALID/);assert.equal(bad.file,path.join(folder,'SKILL.md'));
});
test('explicit workflow/Skill evidence is project-local, existing home untouched and artifact links refused',()=>{
 const{root,h,project}=fixture(),before=snap(h);
 fs.writeFileSync(path.join(project,'README.md'),'# Local guide\nRun node check.mjs to verify this synthetic project. No external service or user credentials are needed.\n');
 fs.writeFileSync(path.join(project,'check.mjs'),'import assert from "node:assert/strict"; assert.equal(6*7,42);\n');
 flow.begin(h,project,'로컬 검증');flow.advance(h,project,'plan','기존 도구로 검증');flow.advance(h,project,'implement');
 hub.readSkill(h,project,'jh-web-quality',{includeUser:false});flow.policy(h,project,'P06');
 const record=hub.record(h,project,'jh-web-quality','APPLIED','검토한 웹 품질 체크 적용');assert.equal(record.kind,'skill_result');
 const verified=flow.verify(h,project,[process.execPath,'check.mjs']);assert.equal(verified.result,'PASS');
 assert.ok(verified.logDirectory.startsWith(path.join(project,'.jh-artifacts')+path.sep));assert.equal(snap(h),before);assert.ok(fs.existsSync(path.join(project,'.jh-artifacts/j-harness-core/events.jsonl')));
 flow.advance(h,project,'handoff');assert.equal(flow.finish(h,project,'README.md').result,'COMPLETE_LOCAL_VERIFIED');
 const linked=path.join(root,'linked-project'),outside=path.join(root,'outside');fs.mkdirSync(linked);fs.mkdirSync(outside);
 fs.symlinkSync(outside,path.join(linked,'.jh-artifacts'),process.platform==='win32'?'junction':'dir');
 assert.throws(()=>flow.begin(h,linked,'거부할 링크 경로'),/LINK/);assert.deepEqual(fs.readdirSync(outside),[]);
});
test('legacy global workflow/history stays read-only while explicit continuation writes locally',()=>{
 const{h,project}=fixture();const old=path.join(rootFor(h),'projects',hash(fs.realpathSync(project)).slice(0,24));fs.mkdirSync(old,{recursive:true});
 const state={schema:1,runId:'legacy-fixture',project,goal:'기존 작업',stage:'analysis',plan:[],finished:false,verification:null};
 fs.writeFileSync(path.join(old,'workflow.json'),JSON.stringify(state));fs.writeFileSync(path.join(old,'events.jsonl'),JSON.stringify({utc:'2026-01-01T00:00:00Z',kind:'workflow_begin',runId:state.runId})+'\n');const before=snap(h);
 assert.equal(projectState(h,project).runId,'legacy-fixture');assert.equal(events(h,project).length,1);assert.equal(snap(h),before);
 flow.advance(h,project,'plan','기존 작업을 이어서 검증');assert.equal(snap(h),before);assert.equal(projectState(h,project).stage,'plan');assert.ok(fs.existsSync(path.join(project,'.jh-artifacts/j-harness-core/workflow.json')));
});
