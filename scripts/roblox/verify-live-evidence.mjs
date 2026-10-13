#!/usr/bin/env node
/** Strict consistency validator for real Studio operator evidence.
 * NOT a Studio MCP client, not a trusted/certified connection attestation.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const requiredPhases=['discovery','read_only','backup','edit','playtest','console','visual','restore','multiplayer'];
const string=v=>typeof v==='string'&&v.trim().length>0;
function parseTimestamp(v,now,maxAgeMinutes){
 if(!string(v))return false;
 const ts=Date.parse(v);
 return Number.isFinite(ts)&&ts<=now+5*60_000&&ts>=now-maxAgeMinutes*60_000;
}
export function verifyRobloxLiveEvidence(proof,{now=Date.now(),maxAgeMinutes=1440}={}){
 const errors=[],warnings=[];
 if(!proof||typeof proof!=='object'||Array.isArray(proof))
  return {status:'FAIL',errors:['OBJECT_REQUIRED'],live_attested:false};
 if(proof.schema_version!==1)errors.push('SCHEMA_VERSION');
 if(!string(proof.studio_id))errors.push('STUDIO_ID_REQUIRED');
 if(!string(proof.test_place_id))errors.push('TEST_PLACE_REQUIRED');
 if(proof.environment!=='PRIVATE_DISPOSABLE_PLACE')errors.push('ISOLATED_TEST_PLACE_REQUIRED');
 if(!parseTimestamp(proof.observed_at,now,maxAgeMinutes))errors.push('OBSERVED_AT_INVALID_OR_STALE');
 if(proof.human_reviewed!==true)errors.push('HUMAN_REVIEW_REQUIRED');
 if(!string(proof.reviewer))errors.push('REVIEWER_REQUIRED');
 if(proof.production_affected!==false)errors.push('PRODUCTION_NOT_PROVEN_UNTOUCHED');
 if(proof.published!==false)errors.push('PUBLISH_MUST_BE_FALSE');
 if(!Array.isArray(proof.sessions)||!proof.sessions.some(x=>x?.studio_id===proof.studio_id))
  errors.push('SELECTED_STUDIO_NOT_DISCOVERED');
 if(proof.sessions?.length>1&&proof.explicit_studio_selection!==true)
  errors.push('AMBIGUOUS_MULTIPLE_STUDIOS');
 const phases=new Map();
 for(const step of Array.isArray(proof.steps)?proof.steps:[]){
  if(!step||!string(step.phase)||!requiredPhases.includes(step.phase)){
   errors.push('UNKNOWN_PHASE');continue;
  }
  if(phases.has(step.phase)){errors.push('DUPLICATE_PHASE:'+step.phase);continue}
  phases.set(step.phase,step);
  if(step.status!=='PASS')errors.push('STEP_NOT_PASS:'+step.phase);
  if(!string(step.receipt_id)||step.receipt_id.length<8)errors.push('RECEIPT_REQUIRED:'+step.phase);
  if(!string(step.observed_tool))errors.push('OBSERVED_TOOL_REQUIRED:'+step.phase);
  if(step.studio_id!==proof.studio_id)errors.push('SESSION_MISMATCH:'+step.phase);
  if(!parseTimestamp(step.observed_at,now,maxAgeMinutes))errors.push('STEP_TIMESTAMP_INVALID:'+step.phase);
 }
 for(const phase of requiredPhases)if(!phases.has(phase))errors.push('STEP_MISSING:'+phase);
 const requiredTools={
  discovery:'list_roblox_studios',read_only:'search_game_tree',
  edit:'multi_edit',playtest:'start_stop_play',console:'get_console_output',
  visual:'screen_capture'
 };
 for(const [phase,tool] of Object.entries(requiredTools)){
  if(phases.get(phase)?.observed_tool!==tool)errors.push('EXPECTED_TOOL_'+phase.toUpperCase());
 }
 // Do not prescribe exact backup/restore tool; Studio and Git mechanism may vary.
 for(const phase of ['backup','restore','multiplayer'])
  if(phases.has(phase)&&!string(phases.get(phase).artifact_ref))
   errors.push('ARTIFACT_REF_REQUIRED:'+phase);
 if(!string(proof.backup_commit)||!string(proof.restore_commit))errors.push('SOURCE_BACKUP_RESTORE_PROOF');
 if(proof.restore_verified!==true)errors.push('RESTORATION_UNVERIFIED');
 if(!Array.isArray(proof.tested_clients)||proof.tested_clients.length<2||
    !proof.tested_clients.every(x=>string(x.client_id)&&x.status==='PASS'))
  errors.push('TWO_CLIENT_MULTIPLAYER_REQUIRED');
 if(proof.console_errors!==0)errors.push('CONSOLE_ERRORS_NONZERO_OR_UNKNOWN');
 if(!string(proof.visual_evidence))errors.push('VISUAL_EVIDENCE_REQUIRED');
 if(!string(proof.source_sync_evidence))errors.push('SOURCE_SYNC_EVIDENCE_REQUIRED');
 warnings.push('UNATTESTED_OPERATOR_SUBMITTED_EVIDENCE: evidence fields can be fabricated');
 warnings.push('Review original MCP transcripts, Roblox Studio indicator, backed-up place and test videos outside this validator');
 return {status:errors.length?'FAIL':'EVIDENCE_CONSISTENT_UNATTESTED',
  live_attested:false,automated_studio_connection:'NOT_TESTED',
  human_review_required:true,errors:[...new Set(errors)],warnings,checked_phases:[...phases.keys()]};
}
const direct=process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(direct){
 const arg=process.argv.slice(2);
 if(arg.length!==2||arg[0]!=='--evidence')throw Error('Usage: node verify-live-evidence.mjs --evidence PRIVATE_LOCAL_JSON_PATH');
 try{
  const report=verifyRobloxLiveEvidence(JSON.parse(fs.readFileSync(path.resolve(arg[1]),'utf8')));
  process.stdout.write(JSON.stringify(report,null,2)+'\n');
  // Consistent-only evidence is NOT a pass of real execution and cannot approve release.
  process.exitCode=report.status==='FAIL'?2:3;
 }catch(e){
  process.stdout.write(JSON.stringify({status:'FAIL',error:e.code||'EVIDENCE_UNREADABLE'},null,2)+'\n');process.exitCode=2;
 }
}
