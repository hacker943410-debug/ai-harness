#!/usr/bin/env node
/** Source-descriptor checks only. Never mislabel this as model/MCP/CLI E2E. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function checkTriad(rootDir=root){
 const problems=[],descriptors={};
 const dir=path.join(rootDir,'settings/clients');
 const files=fs.readdirSync(dir).filter(f=>f.endsWith('.client.json')).sort();
 const expected=['agy.client.json','claude.client.json','codex.client.json'];
 if(JSON.stringify(files)!==JSON.stringify(expected))problems.push('EXPECTED_ONLY_AGY_CLAUDE_CODEX');
 for(const id of ['codex','claude','agy']){
  const file=path.join(dir,id+'.client.json');
  try{
   const d=JSON.parse(fs.readFileSync(file,'utf8'));
   descriptors[id]={client_id:d.client_id,binary:d.detect?.command,skill_path:d.skill_support?.project_path_template,
      mcp_probe:d.argv?.probe,scope:d.supports?.default_scope};
   if(d.client_id!==id||d.detect?.command!==id||d.adapter_kind!=='argv_cli'||
      !d.argv?.probe?.length||!d.argv?.register?.length||!d.argv?.remove?.length||
      !d.skill_support?.native)problems.push('INVALID_DESCRIPTOR:'+id);
  }catch{problems.push('MISSING_OR_INVALID_DESCRIPTOR:'+id)}
 }
 if(descriptors.codex?.skill_path!=='.agents/skills/{skill_id}'||
    descriptors.agy?.skill_path!=='.agents/skills/{skill_id}'||
    descriptors.claude?.skill_path!=='.claude/skills/{skill_id}')
    problems.push('NATIVE_SKILL_PATH_CONFLICT');
 const main=fs.readFileSync(path.join(rootDir,'scripts/harness-project.mjs'),'utf8');
 if(!main.includes("const clientTargets = validateClientTargets(supplied.client_targets || [])")||
    !main.includes("managedFiles(project, clientTargets)")||
    !main.includes("client_targets: plan.client_targets || []"))
  problems.push('OPT_IN_CLAUDE_BRIDGE_MISSING');
 const output={status:problems.length?'FAIL':'STATIC_PASS',version:fs.readFileSync(path.join(rootDir,'HARNESS_VERSION'),'utf8').trim(),
  supported_clients:['codex','claude','agy'],legacy_gemini:'PRESERVED_NOT_ACTIVE',
  client_executables:'NOT_PROBED',auth:'NOT_PROBED',mcp:'NOT_PROBED',models:'NOT_PROBED',
  instructions:'NOT_OBSERVED_IN_LIVE_SESSION',descriptors,problems};
 return output;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const r=checkTriad();process.stdout.write(JSON.stringify(r,null,2)+'\n');if(r.status!=='STATIC_PASS')process.exitCode=2;
}
