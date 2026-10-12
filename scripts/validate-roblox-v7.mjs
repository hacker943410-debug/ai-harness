#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {inspectRobloxProject} from './roblox/verify-project.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function validateRoblox(rootDir=root){
 const errors=[],must=[
  'harness/capabilities/roblox/capability.json',
  'harness/capabilities/roblox/tool-policy.json',
  'harness/capabilities/roblox/verification.json',
  'docs/v7_0/ROBLOX_MCP_SETUP.md','docs/v7_0/ROBLOX_CAPABILITY_ARCHITECTURE.md',
  'docs/v7_0/PROJECT_ETERNAL_REQUIREMENTS.md',
  'scripts/roblox/doctor.mjs','scripts/roblox/verify-session.mjs',
  'scripts/roblox/verify-project.mjs','scripts/roblox/scaffold.mjs','scripts/roblox/test-v7.mjs',
  'scripts/roblox/verify-live-evidence.mjs','scripts/roblox/test-live-v7.mjs',
  'docs/v7_0/INSTALLATION_AND_OPERATIONS.md','docs/v7_0/VERIFICATION_MATRIX.md',
  'templates/roblox-game/default.project.json','templates/roblox-game/rokit.toml'
 ];
 const manifest=JSON.parse(fs.readFileSync(path.join(rootDir,'harness/manifest.yaml'),'utf8'));
 for(const rel of must){
  if(!fs.existsSync(path.join(rootDir,rel)))errors.push('MISSING_FILE:'+rel);
  if(!manifest.payload_files.includes(rel))errors.push('MISSING_PAYLOAD:'+rel);
 }
 const capability=JSON.parse(fs.readFileSync(path.join(rootDir,must[0]),'utf8'));
 const tool=JSON.parse(fs.readFileSync(path.join(rootDir,must[1]),'utf8'));
 if(capability.auto_install!==false||capability.auto_publish!==false)errors.push('MUTATION_DEFAULT_NOT_DISABLED');
 if(capability.lifecycle!=='OPT_IN_NOT_INSTALLED')errors.push('MISSING_OPT_IN');
 if(tool.default_action!=='DENY_MUTATION_UNTIL_USER_APPROVAL')errors.push('UNSAFE_TOOL_DEFAULT');
 if(!tool.classifications.read_only.includes('list_roblox_studios')||tool.classifications.read_only.includes('execute_luau'))
  errors.push('UNSAFE_TOOL_CLASSIFICATION');
 const starter=inspectRobloxProject(path.join(rootDir,'templates/roblox-game'));
 if(starter.status!=='PASS_STATIC_ONLY')errors.push('STARTER_INVALID:'+starter.errors.join(','));
 if(manifest.harness.version!=='6.2.0'||manifest.harness.source_ref!=='v6.2.0')errors.push('UNRELEASED_V7_VERSION_MUST_REMAIN_6_2');
 if(manifest.capabilities.roblox_studio_candidate!==true)errors.push('MISSING_CAPABILITY_FLAG');
 if(!fs.readFileSync(path.join(rootDir,'docs/v7_0/VERIFICATION_MATRIX.md'),'utf8').includes('NO_GO'))errors.push('NO_RELEASE_HARD_GATE');
 return {status:errors.length?'FAIL':'PASS_STATIC_ONLY',actual_studio:'NOT_RUN',errors,
  checked:must.length,release_version:manifest.harness.version};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const r=validateRoblox();process.stdout.write(JSON.stringify(r,null,2)+'\n');
 if(r.status==='FAIL')process.exitCode=2;
}
