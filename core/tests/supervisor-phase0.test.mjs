import test from 'node:test';
import assert from 'node:assert/strict';
import {examineBoundary,assessTool,inspectSession,evaluateVerification,planStateTransition,supervisorScope} from '../supervisor/decision-engine.mjs';
const good = () => Object.fromEntries([
  'supervisorProcessIsolated','policyStoreReadOnlyToAgent','toggleStoreReadOnlyToAgent',
  'ownerCredentialAbsentFromAgent','executorSandboxVerified','trustedPolicyIntegrityVerified',
  'trustedVerifierSeparated','ownerAuthenticatedRelease',
].map(key=>[key,true]));
const ready=()=>examineBoundary({desired:'ON',entry:'jh-managed',evidence:good()});
const sha='a'.repeat(64);

test('SUP-27 mock: missing or ambiguous ON evidence fails closed (never auto OFF)',()=>{
  for(const desired of [undefined,null,'UNKNOWN','on','BROKEN']){
    const s=examineBoundary({desired,entry:'jh-managed',evidence:good()});
    assert.equal(s.state,'BLOCKED');assert.equal(s.launchAuthorized,false);
  }
  const s=examineBoundary({desired:'ON',entry:'jh-managed'});
  assert.equal(s.state,'BLOCKED');assert.ok(s.missing.length>=8);
});
test('SUP-28 mock: explicit OFF is UNMANAGED not an enforced managed session',()=>{
  const s=examineBoundary({desired:'OFF',entry:'jh-managed',evidence:good()});
  assert.equal(s.state,'UNMANAGED');assert.equal(s.launchAuthorized,false);
});
test('SUP-04/36 mock: directly launched CLI must be UNMANAGED even when ON',()=>{
  for(const entry of ['codex','claude','agy','',null]){
    const s=examineBoundary({desired:'ON',entry,evidence:good()});
    assert.equal(s.state,'UNMANAGED');assert.equal(s.enforcement,'NOT_ATTESTED');
  }
});
test('every boundary matters and nothing is ENFORCED just because caller says PASS',()=>{
  const fields=Object.keys(good());
  for(const field of fields){
    const evidence=good();evidence[field]=false;
    const s=examineBoundary({desired:'ON',entry:'jh-managed',evidence});
    assert.equal(s.state,'BLOCKED',field);assert.ok(s.missing.includes(field));
  }
  assert.deepEqual({state:ready().state,launch:ready().launchAuthorized,enforcement:ready().enforcement},
    {state:'READY_CANDIDATE',launch:false,enforcement:'NOT_ATTESTED'});
});
test('SUP-22/23 mock: agent-requested toggle and policy edit cannot be dispatched',()=>{
  for(const action of ['toggle','change_policy','push','deploy']){
    const x=assessTool({boundary:ready(),action,agentRequestedApproval:true});
    assert.equal(x.decision,'DENY',action);
  }
});
test('SUP-09/17 mock: blocked supervisor never authorizes tools',()=>{
  const b=examineBoundary({desired:'ON',entry:'jh-managed',evidence:{}});
  for(const action of ['read_workspace','write_workspace','execute_tool','network'])
    assert.equal(assessTool({boundary:b,action}).decision,'DENY');
});
test('SUP-05/07/08 mock: no shell/network/write can start without isolated executor',()=>{
  for(const action of ['write_workspace','execute_tool','network'])
    assert.deepEqual(assessTool({boundary:ready(),action}),{decision:'DENY',reason:'OS_EXECUTOR_NOT_IMPLEMENTED'});
});
test('unknown actions fail closed',()=>{
  assert.equal(assessTool({boundary:ready(),action:'new-rpc'}).decision,'DENY');
  assert.equal(assessTool({boundary:null,action:'read_workspace'}).decision,'DENY');
});
test('read previews do not invoke tools or claim privileged execution',()=>{
  const x=assessTool({boundary:ready(),action:'read_workspace',agentRequestedApproval:true});
  assert.equal(x.decision,'PREVIEW_ONLY');assert.equal(x.reason,'NO_TOOL_EXECUTION');
});
test('SUP-29/37 mock: epoch mismatch stops a session',()=>{
  const session={epoch:1,policyHash:sha};
  assert.equal(inspectSession({session,currentEpoch:2,policyHash:sha,boundary:ready()}).decision,'STOP');
  assert.equal(inspectSession({session,currentEpoch:1,policyHash:'b'.repeat(64),boundary:ready()}).decision,'STOP');
  assert.equal(inspectSession({session,currentEpoch:1,policyHash:sha,boundary:ready()}).decision,'PREVIEW_CONTINUE_ONLY');
});
test('SUP-10/11/12 mock: agent claims never create a verified PASS',()=>{
  assert.equal(evaluateVerification({exitCode:0,sourceBefore:sha,sourceAfter:sha,agentClaim:'PASS'}).result,'NOT_ATTESTED');
  assert.equal(evaluateVerification({exitCode:1,sourceBefore:sha,sourceAfter:sha,agentClaim:'PASS'}).result,'FAIL');
  assert.equal(evaluateVerification({exitCode:0,sourceBefore:sha,sourceAfter:'b'.repeat(64)}).result,'STALE');
  assert.equal(evaluateVerification({agentClaim:'PASS'}).result,'FAIL');
});
test('SUP-33/34 mock: no interactive confirmation can be satisfied with input alone',()=>{
  assert.equal(planStateTransition({desired:'ON',next:'OFF',activeManagedSessions:0}).decision,'REQUIRES_TRUSTED_OWNER_UI');
  assert.equal(planStateTransition({desired:'ON',next:'OFF',activeManagedSessions:1}).decision,'DENY');
  assert.equal(planStateTransition({desired:'ON',next:'OFF',activeManagedSessions:-1}).decision,'DENY');
  assert.equal(planStateTransition({desired:'ON',next:'OFF',activeManagedSessions:NaN}).decision,'DENY');
});
test('default operation is always non-enforced until independently verified',()=>{
  assert.equal(supervisorScope.enforcement,'NOT_ATTESTED');
  assert.equal(supervisorScope.windowsAcl,'NOT_IMPLEMENTED');
  assert.equal(supervisorScope.directCliInterception,'NOT_IMPLEMENTED');
  assert.equal(supervisorScope.userAuthentication,'NOT_IMPLEMENTED');
});
