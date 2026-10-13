#!/usr/bin/env node
/** Validate handover evidence supplied by an ACTUAL authorized Roblox Studio MCP session.
 * This is a consistency validator, NOT a direct MCP connection and not cryptographic proof.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const emit=x=>process.stdout.write(JSON.stringify(x,null,2)+'\n');
const readonly=new Set(['list_roblox_studios','get_studio_state','search_game_tree',
 'inspect_instance','get_console_output','screen_capture','script_read','script_search','script_grep']);
export function verifyStudioEvidence(proof,{maxAgeMinutes=30,now=Date.now()}={}){
 const errors=[];
 if(!proof||typeof proof!=='object'||Array.isArray(proof))return {status:'FAIL',errors:['EVIDENCE_OBJECT_REQUIRED']};
 if(proof.schema_version!==1)errors.push('UNSUPPORTED_SCHEMA');
 if(typeof proof.studio_id!=='string'||!proof.studio_id.trim())errors.push('STUDIO_ID_REQUIRED');
 if(typeof proof.observed_at!=='string'||!Number.isFinite(Date.parse(proof.observed_at))||
   Math.abs(now-Date.parse(proof.observed_at))>maxAgeMinutes*60000)errors.push('STALE_OR_INVALID_TIMESTAMP');
 const calls=Array.isArray(proof.calls)?proof.calls:[];
 const names=new Set();
 for(const c of calls){
  if(!c||typeof c.tool!=='string'||!readonly.has(c.tool))errors.push('INVALID_OR_MUTATING_TOOL_RECEIPT');
  else {
   if(c.success!==true||typeof c.receipt_id!=='string'||c.receipt_id.length<3)errors.push('UNVERIFIED_TOOL_RECEIPT');
   if(c.tool!=='list_roblox_studios'&&c.studio_id!==proof.studio_id)errors.push('MISMATCHED_STUDIO_ID');
   names.add(c.tool);
  }
 }
 for(const must of ['list_roblox_studios','get_studio_state','search_game_tree'])
  if(!names.has(must))errors.push('MISSING_'+must.toUpperCase());
 if(!Array.isArray(proof.discovered_studios)||!proof.discovered_studios.some(x=>x?.studio_id===proof.studio_id))
   errors.push('STUDIO_NOT_IN_DISCOVERY');
 if(proof.session_count>1&&proof.confirmed_selection!==true)errors.push('MULTI_STUDIO_SELECTION_REQUIRED');
 return {status:errors.length?'FAIL':'EVIDENCE_STRUCTURALLY_VALID',
   provenance:'AGENT_SUBMITTED_UNATTESTED',studio_connection:'NOT_INDEPENDENTLY_VERIFIED',
   studio_id:typeof proof.studio_id==='string'?proof.studio_id:null,
   checked_tools:[...names],errors};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(process.argv.length!==4||process.argv[2]!=='--evidence')throw Error('Usage: node verify-session.mjs --evidence PATH');
 const p=path.resolve(process.argv[3]),r=verifyStudioEvidence(JSON.parse(fs.readFileSync(p,'utf8')));
 emit(r);if(r.status==='FAIL')process.exitCode=2;
}
