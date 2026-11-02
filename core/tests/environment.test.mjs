import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {inspectEnvironment,planEnvironment,findExecutable,stagePinnedLocalFile,sha256} from '../environment/doctor.mjs';

function fixture(t){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'jh-env-'));
 const bin=path.join(root,'bin');fs.mkdirSync(bin);
 t.after(()=>fs.rmSync(root,{recursive:true,force:true}));
 return {root,bin,tool(id){const p=path.join(bin,id);fs.writeFileSync(p,'NOT EXECUTABLE DATA');return p}};
}
function inspect(f,extra={}){
 return inspectEnvironment({client:'codex',profile:'general',platform:'linux',nodeVersion:'22.16.0',
   envPath:f.bin,separator:path.delimiter,...extra});
}
test('one CLI is enough, and read-only inventory cannot change user files',t=>{
 const f=fixture(t);f.tool('codex');const before=fs.readdirSync(f.bin);
 const result=inspect(f);
 assert.equal(result.state,'DISCOVERED_UNVERIFIED');
 assert.deepEqual(result.blocked,[]);
 assert.deepEqual(result.unusedClients,['claude','agy']);
 assert.equal(result.evidence.packageInstalled,false);
 assert.equal(result.evidence.modelSessionVerified,false);
 assert.deepEqual(fs.readdirSync(f.bin),before);
 const plan=planEnvironment(result);
 assert.equal(plan.installation,'NOT_IMPLEMENTED');
 assert.equal(plan.hostChanged,false);
});
test('AGY or Claude works without other CLI installed',t=>{
 const f=fixture(t);f.tool('agy');f.tool('claude');
 for(const client of ['agy','claude']){
   const result=inspect(f,{client});
   assert.equal(result.state,'DISCOVERED_UNVERIFIED',client);
   assert.equal(result.steps.some(step=>step.id==='codex'),false);
 }
 assert.throws(()=>inspect(f,{client:'gemini'}),/UNKNOWN_CLIENT/);
 assert.throws(()=>inspect(f,{profile:'unknown'}),/UNKNOWN_PROFILE/);
});
test('old runtime and missing active CLI cause BLOCKED, never silent installation',t=>{
 const f=fixture(t);f.tool('codex');
 for(const version of ['v18.19.0','20.0.0','0.0.0']){
   const result=inspect(f,{nodeVersion:version});
   assert.equal(result.state,'SETUP_REQUIRED');
   assert.deepEqual(result.blocked,['node']);
   assert.equal(planEnvironment(result).state,'NEEDS_APPROVAL_AND_COMPONENTS');
 }
 const missing=inspect(f,{client:'agy'});
 assert.deepEqual(missing.blocked,['agy']);
});
test('Roblox dependencies are conditional only',t=>{
 const f=fixture(t);f.tool('codex');
 const a=inspect(f),b=inspect(f,{profile:'roblox'});
 assert.equal(a.steps.some(x=>x.id==='rojo'),false);
 for(const name of ['rojo','stylua','selene']){
   assert.equal(b.steps.find(x=>x.id===name)?.required,false);
 }
 assert.deepEqual(b.blocked,[]);
});
test('symlinks and unsafe executable names are rejected',t=>{
 const f=fixture(t);const real=f.tool('codex');
 const link=path.join(f.bin,'agy');
 try{fs.symlinkSync(real,link)}
 catch(e){if(['EPERM','EACCES','ENOTSUP'].includes(e.code)){t.diagnostic('symlink unavailable');return}throw e}
 assert.equal(findExecutable('agy',{envPath:f.bin,platform:'linux'}),null);
 assert.throws(()=>findExecutable('../../bin/sh'),/INVALID_TOOL_NAME/);
});
test('offline pinned file preparation is opt-in, verifies SHA, and never overwrites',t=>{
 const f=fixture(t),source=path.join(f.root,'source.bin'),managedRoot=path.join(f.root,'managed');
 fs.writeFileSync(source,'OWNER-PINNED-BINARY');
 const digest=sha256(fs.readFileSync(source));
 const base={source,expectedSha256:digest,component:'node',fileName:'node.exe',managedRoot};
 assert.throws(()=>stagePinnedLocalFile(base),/EXPLICIT_APPROVAL_REQUIRED/);
 assert.throws(()=>stagePinnedLocalFile({...base,approved:true,expectedSha256:'f'.repeat(64)}),/SOURCE_SHA256_MISMATCH/);
 assert.equal(fs.existsSync(managedRoot),false);
 const result=stagePinnedLocalFile({...base,approved:true});
 assert.equal(result.status,'VERIFIED_STAGED_NOT_INSTALLED');
 assert.equal(sha256(fs.readFileSync(result.path)),digest);
 assert.equal(result.executed,false);
 assert.throws(()=>stagePinnedLocalFile({...base,approved:true}),/EXISTING_COMPONENT_PRESERVED/);
 assert.throws(()=>stagePinnedLocalFile({...base,approved:true,component:'../escape'}),/INVALID_COMPONENT/);
});
test('command line implements only inspect and plan, never install/apply',t=>{
 const f=fixture(t),file=fileURLToPath(new URL('../environment/doctor.mjs',import.meta.url));
 const before=fs.readdirSync(f.root);
 const ok=spawnSync(process.execPath,[file,'plan','--client','agy','--profile','general'],
   {cwd:f.root,encoding:'utf8',timeout:15000});
 assert.equal(ok.status,0,ok.stderr);
 assert.equal(JSON.parse(ok.stdout).hostChanged,false);
 const denied=spawnSync(process.execPath,[file,'apply'],{cwd:f.root,encoding:'utf8',timeout:15000});
 assert.equal(denied.status,2);
 assert.deepEqual(fs.readdirSync(f.root),before);
});
