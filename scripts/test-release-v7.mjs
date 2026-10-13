import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateReleaseRecord} from './validate-release-v7.mjs';

const hash='a'.repeat(64);
const identity={version:'7.0.0',sourceRef:'v7.0.0',runtimeHash:hash};
function fixture() {
 return {schema_version:1,version:'7.0.0',status:'GO',
  operator_review:{confirmed:true,basis:'USER_CONFIRMED_ORIGINAL_PRIVATE_EVIDENCE'},
  evidence_basis:'OBSERVED_OFFICIAL_LOCAL_MCP_TRANSCRIPTS',tested_runtime_sha256:hash,
  tested_candidate_sha:'b'.repeat(40),scope:'UNPUBLISHED_LOCAL_ROBLOX_TEMPLATE',production_data_mutation:false,
  gates:Object.fromEntries(Array.from({length:10},(_,index)=>['R'+String(index+5).padStart(2,'0'),{status:'PASS'}]))};
}
test('accepted release record remains explicitly separate from live attestation',()=>{
 const result=validateReleaseRecord(fixture(),identity);
 assert.equal(result.status,'RELEASE_RECORD_ACCEPTED');
 assert.equal(result.live_studio_attestation,'NOT_PROVIDED_BY_THIS_VALIDATOR');
});
test('publication requires actual operator confirmation rather than a GO assertion',()=>{
 const record=fixture();record.operator_review.confirmed=false;
 assert.ok(validateReleaseRecord(record,identity).errors.includes('OPERATOR_REVIEW_REQUIRED'));
});
test('every required live gate must pass; skipped and untrusted receipts remain blocked',()=>{
 for(let number=5;number<=14;number++) {
  const id='R'+String(number).padStart(2,'0');
  for(const status of ['NOT_RUN','EVIDENCE_CONSISTENT_UNATTESTED','PASS_STATIC_ONLY']) {
   const record=fixture();record.gates[id].status=status;
   assert.ok(validateReleaseRecord(record,identity).errors.includes('REQUIRED_GATE_NOT_PASS:'+id));
  }
 }
});
test('live review cannot carry forward over changed runtime sources or mismatched version pins',()=>{
 assert.ok(validateReleaseRecord(fixture(),{...identity,runtimeHash:'c'.repeat(64)}).errors.includes('LIVE_RUNTIME_SOURCE_DRIFT'));
 assert.ok(validateReleaseRecord(fixture(),{...identity,sourceRef:'v6.2.0'}).errors.includes('RELEASE_IDENTITY_MISMATCH'));
});
test('a reviewed local template does not authorize production data mutation',()=>{
 const record=fixture();record.production_data_mutation=true;
 assert.ok(validateReleaseRecord(record,identity).errors.includes('UNAPPROVED_TEST_SCOPE'));
});
