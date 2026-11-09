import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {createLab, inspectTrustedLab} from '../supervisor/phase1/lab.mjs';
import {request,readStatus} from '../supervisor/phase1/client.mjs';
import {examineOwnerState,startLabBroker} from '../supervisor/phase1/broker.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const server=path.join(here,'../supervisor/phase1/server.mjs');
const agent=path.join(here,'../supervisor/phase1/agent-probe.mjs');

async function fixture(t){
 const f=createLab();
 t.after(()=>{try{fs.rmSync(f.root,{force:true,recursive:true})}catch{}});
 const child=spawn(process.execPath,[server,f.root,f.workspace],{stdio:['ignore','pipe','pipe']});
 let combined='';
 const line=await new Promise((resolve,reject)=>{
  const timeout=setTimeout(()=>reject(Error('BROKER_START_TIMEOUT: '+combined)),6000);
  child.stdout.on('data',part=>{combined+=part;if(combined.includes('\n')){clearTimeout(timeout);resolve(combined.trim().split('\n')[0]);}});
  child.once('error',e=>{clearTimeout(timeout);reject(e)});
  child.once('exit',code=>{clearTimeout(timeout);reject(Error('BROKER_EXIT_'+code))});
 });
 assert.equal(JSON.parse(line).ready,true,line);
 t.after(()=>{if(child.exitCode===null){child.kill('SIGTERM');}});
 return {...f,child};
}

test('broker refuses owner state forgery and never declares ENFORCED', async t=>{
 const f=await fixture(t);
 const s=await readStatus(f.root);
 assert.equal(s.state,'BLOCKED');assert.equal(s.desired,'ON');
 assert.equal(s.enforcement,'NOT_ATTESTED');assert.equal(s.launchAuthorized,false);
 assert.equal(s.toggleAvailable,false);
 assert.equal((await request(f.publicSocket,'status',{agentClaim:'PASS',enforcement:'ENFORCED'})).enforcement,'NOT_ATTESTED');
});
test('owner and public transports reject all mutation operations', async t=>{
 const f=await fixture(t);
 for(const op of ['toggle','change_policy','push','deploy','execute_tool','arbitrary','on','off']){
  assert.equal((await request(f.publicSocket,op,{desired:'OFF'})).decision,'DENY',op);
  assert.equal((await request(f.controlSocket,op,{desired:'OFF'})).decision,'DENY',op);
 }
 assert.equal((await readStatus(f.root)).desired,'ON');
});
test('policy tampering, invalid state and changed epoch never authorize launch', async t=>{
 const f=await fixture(t);
 const stateFile=path.join(f.protectedDir,'state.json');
 const policyFile=path.join(f.protectedDir,'policy.json');
 fs.appendFileSync(policyFile,'X');
 let s=await readStatus(f.root);
 assert.equal(s.state,'BLOCKED');assert.equal(s.reason,'POLICY_INTEGRITY_FAILURE');
 fs.writeFileSync(stateFile,'{"schema":1,"desired":"ON","epoch":2,"policySha256":"invalid"}\n');
 s=await readStatus(f.root);assert.equal(s.state,'BLOCKED');assert.equal(s.launchAuthorized,false);
});
test('service unavailable is BLOCKED and never silently switches OFF', async t=>{
 const f=await fixture(t);
 f.child.kill('SIGKILL');
 await new Promise(resolve=>f.child.once('exit',resolve));
 const state=await readStatus(f.root);
 assert.equal(state.state,'BLOCKED');assert.equal(state.reason,'SUPERVISOR_UNREACHABLE');
 assert.equal(state.desired,'UNKNOWN');
});
test('trusted lab startup fails closed on writable protected roots',async t=>{
 const f=createLab();t.after(()=>fs.rmSync(f.root,{force:true,recursive:true}));
 fs.chmodSync(f.protectedDir,0o777);
 assert.throws(()=>inspectTrustedLab(f.root,f.workspace),/WRITABLE_BY_UNTRUSTED_IDENTITY|PROTECTED_DIR_NOT_PRIVATE/);
});
test('trusted lab startup rejects linked protected directory',async t=>{
 const f=createLab();t.after(()=>fs.rmSync(f.root,{force:true,recursive:true}));
 const privateReal=path.join(f.root,'private-real');
 fs.renameSync(f.protectedDir,privateReal);
 fs.symlinkSync(privateReal,f.protectedDir);
 assert.throws(()=>inspectTrustedLab(f.root,f.workspace),/UNTRUSTED_LAB_ROOT/);
});
test('cannot bind duplicate broker; existing socket preserved',async t=>{
 const f=await fixture(t);
 await assert.rejects(startLabBroker(f.root,f.workspace),/EXISTING_SOCKET_PRESERVED_REVIEW_REQUIRED/);
 assert.equal((await readStatus(f.root)).state,'BLOCKED');
});

test('REAL LINUX OS ACL: distinct UID can write workspace but cannot read or write trust store or control socket', {skip:process.platform!=='linux' || process.geteuid?.()!==0 || !fs.existsSync('/usr/bin/setpriv') ? 'requires isolated Linux root test harness with setpriv' : false}, async t=>{
 const f=await fixture(t);
 const r=spawnSync('/usr/bin/setpriv',['--reuid','65534','--regid','65534','--clear-groups',process.execPath,agent,f.root,f.workspace],{encoding:'utf8',timeout:10000});
 assert.equal(r.status,0,r.stderr+'\n'+r.stdout);
 const s=JSON.parse(r.stdout.trim());
 assert.equal(s.actorUid,65534);
 for(const op of ['protectedRead','protectedWrite','protectedStateWrite','controlPipe'])assert.match(s[op],/EACCES|EPERM/,op);
 assert.equal(s.workspaceWrite,'ALLOWED');
 assert.equal(s.publicToggle,'DENY');assert.equal(s.publicPolicyChange,'DENY');
 assert.equal(s.fakePassInfluence,'NOT_ATTESTED');
 assert.equal(s.status.state,'BLOCKED');
 assert.equal(fs.readFileSync(path.join(f.workspace,'agent-work.txt'),'utf8'),'WORKER_CAN_WORK');
 t.diagnostic('Linux OS access-denial observed under real UID 65534, independent from service UID 0. This is NOT Windows E2E.');
});

test('root link and workspace link are not trusted even if they resolve to a real directory',async t=>{
 const f=createLab();t.after(()=>fs.rmSync(f.root,{force:true,recursive:true}));
 const alias=path.join(path.dirname(f.root),path.basename(f.root)+'-alias');
 fs.symlinkSync(f.root,alias);t.after(()=>fs.rmSync(alias,{force:true}));
 assert.throws(()=>inspectTrustedLab(alias,f.workspace),/UNTRUSTED_LAB_ROOT/);
 const workspaceReal=path.join(f.root,'work-real');
 fs.renameSync(f.workspace,workspaceReal);fs.symlinkSync(workspaceReal,f.workspace);
 assert.throws(()=>inspectTrustedLab(f.root,f.workspace),/UNTRUSTED_WORKSPACE/);
});

test('Windows candidate cannot silently create accounts, install service or report enforcement',t=>{
 const windows=path.join(here,'../../windows');
 const prep=fs.readFileSync(path.join(windows,'New-WindowsBoundaryLab.ps1'),'utf8');
 const service=fs.readFileSync(path.join(windows,'WindowsService-Lab.cs'),'utf8');
 const build=fs.readFileSync(path.join(windows,'Build-WindowsServiceLab.ps1'),'utf8');
 assert.match(prep,/\[switch\]\$CreateFixture/);
 assert.match(prep,/if \(-not \$CreateFixture\)/);
 assert.match(service,/"BLOCKED"|\\"state\\":\\"BLOCKED\\"/);
 assert.match(service,/READ_ONLY_PIPE/);
 assert.doesNotMatch(build, /\b(sc\.exe|New-Service|Start-Service|New-LocalUser)\b/);
 assert.match(build,/serviceInstalled=\$false/);
});
