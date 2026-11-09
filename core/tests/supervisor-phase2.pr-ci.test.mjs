import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const workflow=read('.github/workflows/v8-supervisor-phase2-windows-ci.yml');
const script=read('windows/phase2/Invoke-Phase2WindowsCILab.ps1');
const worker=read('windows/phase2/Invoke-Phase2WorkerProbe.ps1');

test('owner-only PR CI includes source integration on main without a dispatch dependency',()=>{
  assert.match(workflow,/^on:\s*\n\s+pull_request:/m);
  assert.match(workflow,/branches:\s*\n\s+- feature\/v8-environment-bootstrap-phase2/);
  assert.match(workflow,/github\.event\.pull_request\.head\.ref == 'feature\/v8-supervisor-phase2-windows-ci'/);
  assert.match(workflow,/branches:\s*\n\s+- feature\/v8-environment-bootstrap-phase2\s*\n\s+- main/);
  assert.match(workflow,/github\.event\.pull_request\.base\.ref == 'main'/);
  assert.match(workflow,/Test-Phase2CleanupContract\.ps1/);
  assert.match(workflow,/github\.event\.pull_request\.head\.repo\.full_name == github\.repository/);
  assert.match(workflow,/github\.event\.pull_request\.user\.login == 'hacker943410-debug'/);
  assert.doesNotMatch(workflow,/workflow_dispatch:|pull_request_target:|\n\s+push:/);
});
test('PR workflow uses hosted Windows only, immutable action permissions and no credentials',()=>{
  assert.match(workflow,/runs-on: windows-2022/);
  assert.match(workflow,/permissions:\s*\n\s+contents: read/);
  assert.match(workflow,/persist-credentials: false/g);
  assert.match(workflow,/if: always\(\)/);
  assert.match(workflow,/if-no-files-found: error/);
  assert.doesNotMatch(workflow,/contents: write|id-token: write|git push|gh release|pull_request_target:/);
});
test('Windows runner script validates repository/event identity and source revision before setup',()=>{
  assert.match(script,/GITHUB_REPOSITORY -ne 'hacker943410-debug\/ai-harness'/);
  assert.match(script,/GITHUB_EVENT_NAME -ne 'pull_request'/);
  assert.match(script,/ExpectedGithubSha -ne \$env:GITHUB_SHA/);
  assert.match(script,/Assert-TrustStoreAcl \$protected \$workspace \$serviceDir \$agentSid/);
  assert.match(script,/aclEvidence='PASS_TRUSTED_RUNNER_DACL_CHECK'/);
});
test('non-admin worker attacks existing policy and state plus launch/deploy IPC',()=>{
  for(const item of ['protectedPolicyOverwrite','protectedStateRead','pipeLaunch','pipeDeploy']) assert.match(worker,new RegExp(item));
  assert.match(worker,/AppendAllText\(\(Join-Path \$LabRoot 'protected\\policy.json'\)/);
  assert.match(worker,/PipeRequest 'launch'/);
  assert.match(worker,/PipeRequest 'deploy'/);
  assert.match(script,/ACTUAL_RESTRICTED_ACCOUNT_PROBE_FAILED/);
});
