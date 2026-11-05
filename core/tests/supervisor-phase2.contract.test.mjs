import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>fs.readFileSync(path.join(base,p),'utf8');
const svc=read('windows/phase2/JHarnessPhase2LabService.cs');
const ci=read('windows/phase2/Invoke-Phase2WindowsCILab.ps1');
const probe=read('windows/phase2/Invoke-Phase2WorkerProbe.ps1');
const build=read('windows/phase2/Build-Phase2Service.ps1');
const readClient=read('windows/phase2/Get-Phase2LabStatus.ps1');
const workflow=read('.github/workflows/v8-supervisor-phase2-windows-ci.yml');

test('Phase2 only runs as explicit ephemeral GitHub Windows CI job',()=>{
  assert.match(ci,/IAmInDisposableGitHubWindowsRunner/);
  assert.match(ci,/GITHUB_ACTIONS.+true/);
  assert.match(ci,/RUNNER_OS.+Windows/);
  assert.match(ci,/RUNNER_ENVIRONMENT.+github-hosted/);
  assert.match(ci,/RUNNER_TEMP/);
  assert.match(workflow,/pull_request:/);
  assert.doesNotMatch(workflow,/workflow_dispatch:|pull_request_target:|\n\s+push:/);
});
test('distinct account created only inside explicitly authorized ephemeral CI and later deleted',()=>{
  assert.match(ci,/New-LocalUser/);
  assert.match(ci,/Remove-LocalUser/);
  assert.match(ci,/Start-Process[^\n]*-Credential/);
  assert.match(ci,/agentSid -eq \$identity\.User\.Value/);
  assert.match(probe,/WRONG_WORKER_SID_NO_PROBE/);
  assert.match(probe,/ADMINISTRATOR_WORKER_REFUSED/);
});
test('owner protected roots reside under guarded ProgramData test parent, not actor writable workspace',()=>{
  assert.match(ci,/CommonApplicationData/);
  assert.match(ci,/Set-LabAcl \$protected ''/);
  assert.match(ci,/Set-LabAcl \$workspace \$agentSid 'Modify'/);
  assert.match(ci,/SetAccessRuleProtection\(\$true,\$false\)/);
  assert.match(ci,/REPARSE_MEMBER_CLEANUP_REFUSED/);
  assert.match(svc,/DISPOSABLE_PROGRAMDATA_LAB_ROOT_ONLY/);
});
test('SCM service requires LocalService identity, read-only transport, and refuses all mutations',()=>{
  assert.match(svc,/ServiceBase\.Run/);
  assert.match(svc,/S-1-5-19/);
  assert.match(svc,/LOCALSERVICE_IDENTITY_REQUIRED/);
  assert.match(svc,/StatusPipeAcl\(\)/);
  assert.match(svc,/READ_ONLY_PIPE_NO_MUTATION/);
  assert.doesNotMatch(svc,/Process\.Start|ProcessStartInfo|CreateProcessWithLogonW|ExecuteTool|LaunchCli/);
  assert.match(svc,/"BLOCKED"/);
  assert.match(svc,/"NOT_ATTESTED"/);
  assert.match(svc,/launchAuthorized = false/);
  assert.match(svc,/toggleAvailable = false/);
});
test('worker attempts actual guarded access and validates both read-only pipe and workspace',()=>{
  for (const term of ['protectedPolicyRead','protectedPolicyWrite','protectedStateWrite','workspaceWrite','pipeStatus','pipeToggle','pipePolicyChange'])
    assert.match(probe,new RegExp(term));
  assert.match(probe,/PASS_WINDOWS_BOUNDARY_LAB_ONLY/);
  assert.match(probe,/ACCESS_DENIED/);
});
test('trust state and policy are hashed and compared after probe; service unreachable is blocked',()=>{
  assert.match(svc,/SHA256\.Create/);
  assert.match(svc,/POLICY_SHA256_MISMATCH/);
  assert.match(ci,/originalPolicyUntouched/);
  assert.match(ci,/originalStateUntouched/);
  assert.match(ci,/STOPPED_SERVICE_PIPE_STILL_REACHABLE/);
  assert.match(ci,/CLIENT_DID_NOT_FAIL_CLOSED_ON_STOP/);
  assert.match(readClient,/SUPERVISOR_UNREACHABLE/);
  assert.match(readClient,/launchAuthorized=\$false/);
  assert.match(readClient,/UNTRUSTED_SERVICE_REPLY_BLOCKED/);
});
test('build does not install or start service, runner does with teardown',()=>{
  assert.match(build,/COMPILED_ONLY/);
  assert.match(build,/serviceInstalled=\$false/);
  assert.doesNotMatch(build,/sc\.exe create|New-Service|Start-Service/);
  assert.match(ci,/sc\.exe create/);
  assert.match(ci,/sc\.exe delete/);
  assert.match(ci,/Stop-Service/);
  assert.match(ci,/Remove-Item -LiteralPath \$parent/);
});
test('no production enforcement claim, no owner credentials, no repo write in CI',()=>{
  assert.doesNotMatch(workflow,/contents: write|id-token: write|gh pr merge|gh release|git push/);
  assert.match(workflow,/contents: read/);
  assert.match(ci,/release='NO_GO'/);
  assert.match(ci,/NO_CLI_ENFORCEMENT/);
  assert.doesNotMatch(svc,/"ENFORCED"|"MANAGED"/);
});
