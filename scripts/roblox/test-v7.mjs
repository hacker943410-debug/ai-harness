import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {parseMcpRegistry,runDoctor,buildDoctorReport} from './doctor.mjs';
import {verifyStudioEvidence} from './verify-session.mjs';
import {scaffoldProject} from './scaffold.mjs';
import {inspectRobloxProject,verifyRobloxProject} from './verify-project.mjs';
import {fileURLToPath} from 'node:url';

test('registration is not called an actual Studio connection',()=>{
 assert.equal(parseMcpRegistry('[{"name":"Roblox_Studio"}]').status,'REGISTERED_UNVERIFIED');
 assert.equal(parseMcpRegistry('{"servers":[{"name":"roblox_studio"}]}').registered,true);
 assert.equal(parseMcpRegistry('[{"name":"Roblox_Studio"},{"name":"roblox_studio"}]').status,'DUPLICATE_REGISTRATIONS');
 assert.equal(parseMcpRegistry('{bad').ok,false);
 const report=buildDoctorReport({platform:'linux',codexResult:{ok:true,stdout:'[{"name":"Roblox_Studio"}]'},toolResults:{rojo:{ok:true}}});
 assert.equal(report.studio_connection,'NOT_VERIFIED');
 assert.equal(report.binaries.rojo,'AVAILABLE');
});
test('doctor invokes only allowlisted read-only CLI probes',()=>{
 const calls=[];
 const report=runDoctor({project:os.tmpdir(),probe:(cmd,args)=>{
  calls.push([cmd,args]);return cmd==='codex'?{ok:true,stdout:'[]'}:{ok:false,error:'ENOENT'};
 }});
 assert.deepEqual(calls[0],['codex',['mcp','list','--json']]);
 assert.ok(calls.every(([cmd,args])=>(cmd==='codex'&&args.join(' ')==='mcp list --json')||
  (['rokit','rojo','stylua','selene','lune','wally'].includes(cmd)&&args.join(' ')==='--version')));
 assert.equal(report.plugin_registration.registered,false);
});
test('Studio proof must name selected instance and 3 required read tools',()=>{
 const observed_at=new Date().toISOString(), studio_id='example-session-1';
 const proof={schema_version:1,observed_at,studio_id,session_count:1,
  discovered_studios:[{studio_id}],calls:['list_roblox_studios','get_studio_state','search_game_tree'].map(tool=>({
   tool,studio_id,success:true,receipt_id:'from-agent-tool-123'
  }))};
 const report=verifyStudioEvidence(proof);
 assert.equal(report.status,'EVIDENCE_STRUCTURALLY_VALID');
 assert.equal(report.studio_connection,'NOT_INDEPENDENTLY_VERIFIED');
 assert.equal(verifyStudioEvidence({...proof,session_count:2}).status,'FAIL');
 assert.equal(verifyStudioEvidence({...proof,observed_at:'2020-01-01T00:00:00Z'}).status,'FAIL');
 assert.equal(verifyStudioEvidence({...proof,calls:[...proof.calls,{tool:'execute_luau',studio_id,success:true,receipt_id:'x'}]}).status,'FAIL');
});
test('scaffold preview is read-only; create avoids overwriting existing content',t=>{
 const parent=fs.mkdtempSync(path.join(os.tmpdir(),'roblox-v7-test-'));
 t.after(()=>fs.rmSync(parent,{recursive:true,force:true}));
 const dst=path.join(parent,'my-game');
 assert.equal(scaffoldProject(dst).status,'DRY_RUN');
 assert.equal(fs.existsSync(dst),false);
 assert.equal(scaffoldProject(dst,{create:true}).status,'SCAFFOLDED');
 assert.equal(fs.existsSync(path.join(dst,'default.project.json')),true);
 assert.throws(()=>scaffoldProject(dst,{create:true}),/DESTINATION_NOT_EMPTY/);
});

test('starter static verification is truthful and tool verification requires actual run',()=>{
 const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../templates/roblox-game');
 const basic=inspectRobloxProject(source);
 assert.equal(basic.status,'PASS_STATIC_ONLY');
 assert.equal(basic.external_build,'NOT_RUN');
 assert.equal(basic.studio_playtest,'NOT_RUN');
 const passed=verifyRobloxProject(source,{runTools:true,
  runner:()=>({status:'PASS',exit_code:0})});
 assert.equal(passed.status,'PASS_LOCAL_TOOLS_ONLY');
 assert.equal(passed.studio_playtest,'NOT_RUN');
 const failed=verifyRobloxProject(source,{runTools:true,
  runner:binary=>({status:binary==='selene'?'FAIL':'PASS',exit_code:1})});
 assert.equal(failed.status,'FAIL');
 const unavailable=verifyRobloxProject(source,{runTools:true,
  runner:()=>({status:'NOT_RUN',error:'ENOENT'})});
 assert.equal(unavailable.status,'NOT_RUN');
});
test('missing Rojo mappings block static gate',t=>{
 const parent=fs.mkdtempSync(path.join(os.tmpdir(),'roblox-v7-bad-'));
 t.after(()=>fs.rmSync(parent,{recursive:true,force:true}));
 fs.writeFileSync(path.join(parent,'default.project.json'),'{}');
 assert.equal(inspectRobloxProject(parent).status,'FAIL');
});
