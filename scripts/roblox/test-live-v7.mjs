import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyRobloxLiveEvidence} from './verify-live-evidence.mjs';
const phases=['discovery','read_only','backup','edit','playtest','console','visual','restore','multiplayer'];
const names={discovery:'list_roblox_studios',read_only:'search_game_tree',backup:'git_commit',
 edit:'multi_edit',playtest:'start_stop_play',console:'get_console_output',
 visual:'screen_capture',restore:'git_restore',multiplayer:'StudioTestService'};
const now=Date.UTC(2026,9,12,8);
const t=new Date(now).toISOString();
const sample=()=>({schema_version:1,studio_id:'studio-1',test_place_id:'private-test',environment:'PRIVATE_DISPOSABLE_PLACE',
 observed_at:t,human_reviewed:true,reviewer:'local-owner',production_affected:false,published:false,
 sessions:[{studio_id:'studio-1'}],explicit_studio_selection:true,
 backup_commit:'sha-before',restore_commit:'sha-after',restore_verified:true,
 tested_clients:[{client_id:'client1',status:'PASS'},{client_id:'client2',status:'PASS'}],
 console_errors:0,visual_evidence:'screenshots/private-test.png',source_sync_evidence:'git-check-run',
 steps:phases.map(phase=>({phase,studio_id:'studio-1',observed_tool:names[phase],observed_at:t,
 status:'PASS',receipt_id:'original-log-'+phase,artifact_ref:'private-local-'+phase}))
});
test('consistent proof stays untrusted; never assert live Studio PASS',()=>{
 const output=verifyRobloxLiveEvidence(sample(),{now});
 assert.equal(output.status,'EVIDENCE_CONSISTENT_UNATTESTED');
 assert.equal(output.live_attested,false);
 assert.equal(output.human_review_required,true);
});
test('missing, forged, stale or inconsistent evidence cannot pass',()=>{
 const scenarios=[
  p=>delete p.steps[p.steps.length-1],
  p=>p.steps[3].studio_id='another',
  p=>p.steps[4].observed_tool='execute_luau',
  p=>p.tested_clients=[p.tested_clients[0]],
  p=>p.production_affected=true,
  p=>p.published=true,
  p=>p.restore_verified=false,
  p=>p.console_errors=undefined,
  p=>p.observed_at='2020-01-01T00:00:00Z',
  p=>p.human_reviewed=false,
  p=>p.sessions=[{studio_id:'other'}],
  p=>p.steps[6].receipt_id='x',
  p=>p.steps[2].artifact_ref=''
 ];
 for(const change of scenarios){
  const proof=sample();change(proof);
  assert.equal(verifyRobloxLiveEvidence(proof,{now}).status,'FAIL');
 }
});
test('multiple Studios require explicit selection; production never allowed',()=>{
 const p=sample();p.sessions.push({studio_id:'studio-2'});p.explicit_studio_selection=false;
 assert.ok(verifyRobloxLiveEvidence(p,{now}).errors.includes('AMBIGUOUS_MULTIPLE_STUDIOS'));
});
