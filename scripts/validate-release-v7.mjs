#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {sourceIdentity} from './harness-project.mjs';

export const ROBLOX_RUNTIME_FILES = [
 'harness/capabilities/roblox/tool-policy.json',
 'scripts/roblox/doctor.mjs','scripts/roblox/scaffold.mjs',
 'scripts/roblox/verify-project.mjs','scripts/roblox/verify-session.mjs',
 'scripts/roblox/verify-live-evidence.mjs',
 'templates/roblox-game/default.project.json','templates/roblox-game/rokit.toml',
 'templates/roblox-game/selene.toml','templates/roblox-game/stylua.toml',
 'templates/roblox-game/src/client/Bootstrap.client.luau',
 'templates/roblox-game/src/server/Bootstrap.server.luau',
 'templates/roblox-game/src/shared/Settings.luau',
].sort();

export function robloxRuntimeHash(root) {
 const digest=createHash('sha256');
 for(const relative of ROBLOX_RUNTIME_FILES) {
  const file=path.join(root,relative);
  if(fs.lstatSync(file).isSymbolicLink()) throw new Error('Linked runtime files are not approved');
  digest.update(relative+'\0').update(fs.readFileSync(file)).update('\0');
 }
 return digest.digest('hex');
}

// This validates an operator review record; it cannot attest a live Studio session.
// Original local MCP transcripts/screenshots must be reviewed separately.
export function validateReleaseRecord(record,{version,sourceRef,runtimeHash}={}) {
 const errors=[];
 if(version!=='7.0.0'||sourceRef!=='v7.0.0'||record?.version!==version) errors.push('RELEASE_IDENTITY_MISMATCH');
 if(record?.schema_version!==1||record?.status!=='GO') errors.push('RELEASE_NOT_GO');
 if(record?.operator_review?.confirmed!==true||record?.operator_review?.basis!=='USER_CONFIRMED_ORIGINAL_PRIVATE_EVIDENCE') errors.push('OPERATOR_REVIEW_REQUIRED');
 if(record?.evidence_basis!=='OBSERVED_OFFICIAL_LOCAL_MCP_TRANSCRIPTS') errors.push('ORIGINAL_LOCAL_EVIDENCE_REQUIRED');
 if(record?.tested_runtime_sha256!==runtimeHash||!/^[a-f0-9]{64}$/.test(runtimeHash||'')) errors.push('LIVE_RUNTIME_SOURCE_DRIFT');
 if(!/^[a-f0-9]{40}$/.test(record?.tested_candidate_sha||'')) errors.push('MISSING_TESTED_CANDIDATE');
 for(let number=5;number<=14;number++) {
  const id='R'+String(number).padStart(2,'0');
  if(record?.gates?.[id]?.status!=='PASS') errors.push('REQUIRED_GATE_NOT_PASS:'+id);
 }
 if(record?.scope!=='UNPUBLISHED_LOCAL_ROBLOX_TEMPLATE'||record?.production_data_mutation!==false) errors.push('UNAPPROVED_TEST_SCOPE');
 return {status:errors.length?'FAIL':'RELEASE_RECORD_ACCEPTED',errors,
  live_studio_attestation:'NOT_PROVIDED_BY_THIS_VALIDATOR',
  review_basis:'Operator reviewed original private evidence; JSON consistency alone is insufficient.'};
}

export function validateRelease(root) {
 const identity=sourceIdentity(root);
 const record=JSON.parse(fs.readFileSync(path.join(root,'docs/v7_0/RELEASE_ACCEPTANCE.json'),'utf8'));
 const result=validateReleaseRecord(record,{version:identity.version,sourceRef:identity.manifest.harness.source_ref,runtimeHash:robloxRuntimeHash(root)});
 for(const relative of ['docs/v7_0/RELEASE_ACCEPTANCE.json','docs/v7_0/RELEASE_NOTES_v7.0.0.md','scripts/validate-release-v7.mjs']) {
  if(!identity.manifest.payload_files.includes(relative)) {result.errors.push('MISSING_RELEASE_PAYLOAD:'+relative);result.status='FAIL';}
 }
 const notes=path.join(root,'docs/v7_0/RELEASE_NOTES_v7.0.0.md');
 if(!fs.existsSync(notes)) {result.errors.push('RELEASE_NOTES_MISSING');result.status='FAIL';}
 return {...result,version:identity.version,source_hash:identity.hash};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
 let result;
 try {result=validateRelease(root)} catch(error) {result={status:'FAIL',errors:[error.message]};}
 process.stdout.write(JSON.stringify(result,null,2)+'\n');
 if(result.status!=='RELEASE_RECORD_ACCEPTED') process.exitCode=2;
}
