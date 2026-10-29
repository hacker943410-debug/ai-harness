import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.join(root,'docs/v8/SUPERVISOR_CONTROL_CONTRACT.json');
const contract=JSON.parse(fs.readFileSync(source,'utf8'));

test('v8 is a design-only contract, never a claim of runtime enforcement',()=>{
  assert.equal(contract.status,'DESIGN_CONTRACT_ONLY_NOT_ENFORCEMENT');
  assert.match(contract.notes.join(' '),/E2E verified/i);
});
test('user-adjustable surface contains only the ON/OFF toggle',()=>{
  const ui=contract.user_control_surface;
  assert.deepEqual(ui.buttons,[]);
  assert.deepEqual(ui.toggles,['harness.enabled']);
  assert.deepEqual(ui.writable_fields,['harness.enabled']);
  assert.deepEqual(ui.allowed_values,['ON','OFF']);
  assert.equal(ui.default_state,'ON');
  assert.deepEqual(ui.agent_writable_fields,[]);
  for(const [key,val] of Object.entries(ui)){
    if(/^manual_.*selection$/.test(key))assert.equal(val,false,key);
  }
});
test('user ON with broken enforcement never silently becomes OFF',()=>{
  const state=contract.runtime_state_policy;
  assert.equal(state.on_healthy,'MANAGED');
  assert.equal(state.on_unhealthy,'BLOCKED');
  assert.equal(state.unresolved_toggle,'BLOCKED');
  assert.equal(state.auto_off_on_failure,false);
  assert.equal(state.off,'UNMANAGED');
  assert.equal(state.mid_session_switch,'STOP_AND_RESTART_OR_DENY');
});
test('AI cannot set the toggle or falsely declare direct CLI managed',()=>{
  const state=contract.runtime_state_policy;
  assert.equal(state.authenticated_user_toggle_only,true);
  assert.equal(state.toggle_storage_outside_agent_workspace,true);
  assert.equal(state.direct_agent_toggle_request,'DENY');
  assert.equal(state.unmanaged_cli_cannot_claim_enforcement,true);
});
test('source updates require separated GitHub owner channel, not a delegated AI credential',()=>{
  const a=contract.source_authority;
  assert.equal(contract.repository,'hacker943410-debug/ai-harness');
  assert.equal(a.owner_login,'hacker943410-debug');
  assert.equal(a.owner_github_account_id,258754438);
  assert.equal(a.changes_only_via,'OWNER_INTERACTIVE_GITHUB_APPROVAL');
  assert.equal(a.agent_git_write_allowed,false);
  assert.equal(a.agent_owner_credentials_allowed,false);
  assert.equal(a.unverified_source_updates_allowed,false);
  assert.equal(a.owner_approval_proven_by_access_token_alone,false);
  assert.deepEqual([...a.authorized_release_requires].sort(),[
    'protected_repository_reference',
    'owner_out_of_band_approval',
    'verified_artifact_integrity'
  ].sort());
});
