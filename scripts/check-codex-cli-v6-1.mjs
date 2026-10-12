#!/usr/bin/env node
// Read-only Codex CLI capability probe; no config writes and no MCP secrets in logs.
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function parseVersion(text) {
  const m = String(text).match(/(?:codex(?:-cli)?\s+)?(\d+\.\d+\.\d+(?:-[a-z0-9.]+)?)/i);
  return m ? { value: m[1], prerelease: m[1].includes('-') } : null;
}
export function probe(binary, args) {
  const r=spawnSync(binary,args,{encoding:'utf8',timeout:10000,maxBuffer:131072,windowsHide:true,shell:false});
  return {ok: !r.error && r.status===0, code:r.status??null, error:r.error?.code??null, output:r.stdout??''};
}
export function diagnose(binary='codex') {
  const v=probe(binary,['--version']);
  if(!v.ok) return {installed:false,version:null,authenticated:'UNKNOWN',status:'NOT_RUN',reason:v.error||'version_command_failed'};
  const h=probe(binary,['mcp','--help']);
  const m=probe(binary,['mcp','list','--json']);
  let count=null,valid=false;
  if(m.ok) { try { const data=JSON.parse(m.output); valid=Array.isArray(data); if(valid) count=data.length; } catch {} }
  return {installed:true,version:parseVersion(v.output),mcp_help:h.ok,mcp_list:m.ok,mcp_json_valid:valid,mcp_count:count,authenticated:'UNKNOWN',status:h.ok&&valid?'PROBE_OK':'PROBE_INCOMPLETE'};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 const d=diagnose();
 process.stdout.write(JSON.stringify(d,null,2)+'\n');
 if(d.status!=='PROBE_OK') process.exitCode=2;
}
