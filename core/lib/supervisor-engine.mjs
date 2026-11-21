/**
 * J Harness v8 supervisor decision kernel (Phase 0 / TEST CANDIDATE).
 *
 * NO OS enforcement, credential verification, privileged UI or tool interception.
 * The caller MUST NOT treat boolean evidence supplied by an AI as trusted.
 * Readiness is NOT an authorization to launch a real CLI.
 */
const REQUIRED_BOUNDARIES = Object.freeze([
  'supervisorProcessIsolated',
  'policyStoreReadOnlyToAgent',
  'toggleStoreReadOnlyToAgent',
  'ownerCredentialAbsentFromAgent',
  'executorSandboxVerified',
  'trustedPolicyIntegrityVerified',
  'trustedVerifierSeparated',
  'ownerAuthenticatedRelease',
]);
const VALID_ACTIONS = new Set(['read_workspace', 'write_workspace', 'execute_tool', 'network', 'push', 'deploy', 'toggle', 'change_policy']);
const MUTATING_ACTIONS = new Set(['write_workspace', 'execute_tool', 'network', 'push', 'deploy', 'toggle', 'change_policy']);

export function examineBoundary({desired, entry, evidence} = {}) {
  if (desired === 'OFF') return Object.freeze({
    state: 'UNMANAGED', reason: 'EXPLICIT_USER_OFF', candidateReady: false,
    enforcement: 'NOT_ATTESTED', launchAuthorized: false,
  });
  if (desired !== 'ON') return Object.freeze({
    state: 'BLOCKED', reason: 'UNKNOWN_OR_UNRESOLVED_TOGGLE', candidateReady: false,
    enforcement: 'NOT_ATTESTED', launchAuthorized: false,
  });
  if (entry !== 'jh-managed') return Object.freeze({
    state: 'UNMANAGED', reason: 'DIRECT_CLI_NOT_INTERCEPTED', candidateReady: false,
    enforcement: 'NOT_ATTESTED', launchAuthorized: false,
  });
  const missing = REQUIRED_BOUNDARIES.filter(key => evidence?.[key] !== true);
  if (missing.length) return Object.freeze({
    state: 'BLOCKED', reason: 'TRUST_BOUNDARY_NOT_VERIFIED', missing,
    candidateReady: false, enforcement: 'NOT_ATTESTED', launchAuthorized: false,
  });
  // Even eight booleans can be forged by the untrusted agent. Never return ENFORCED.
  return Object.freeze({
    state: 'READY_CANDIDATE', reason: 'EXTERNAL_ATTESTATION_REQUIRED',
    candidateReady: true, enforcement: 'NOT_ATTESTED', launchAuthorized: false,
  });
}

/** Only proposes a decision; it deliberately DOES NOT invoke an OS command. */
export function assessTool({boundary, action, agentRequestedApproval = false} = {}) {
  if (!VALID_ACTIONS.has(action)) return Object.freeze({decision: 'DENY', reason: 'UNKNOWN_ACTION'});
  if (action === 'toggle' || action === 'change_policy' || action === 'push' || action === 'deploy')
    return Object.freeze({decision: 'DENY', reason: 'OWNER_ONLY_OR_SEPARATE_APPROVAL_REQUIRED'});
  if (boundary?.state !== 'READY_CANDIDATE' || boundary?.enforcement !== 'NOT_ATTESTED')
    return Object.freeze({decision: 'DENY', reason: 'NO_TRUSTED_MANAGED_EXECUTOR'});
  if (MUTATING_ACTIONS.has(action))
    return Object.freeze({decision: 'DENY', reason: 'OS_EXECUTOR_NOT_IMPLEMENTED'});
  // Read-only is a proposal, not proof of isolation or execution permission.
  return Object.freeze({decision: 'PREVIEW_ONLY', reason: 'NO_TOOL_EXECUTION', agentRequestedApproval: Boolean(agentRequestedApproval)});
}

/** Session epochs prevent treating a changed toggle/policy as the same session. */
export function inspectSession({session, currentEpoch, policyHash, boundary} = {}) {
  if (!session || !Number.isSafeInteger(session.epoch) || !Number.isSafeInteger(currentEpoch))
    return Object.freeze({decision: 'STOP', reason: 'SESSION_IDENTITY_MISSING'});
  if (session.epoch !== currentEpoch) return Object.freeze({decision: 'STOP', reason: 'STATE_CHANGED_RESTART_REQUIRED'});
  if (!/^[a-f0-9]{64}$/.test(policyHash ?? '') || session.policyHash !== policyHash)
    return Object.freeze({decision: 'STOP', reason: 'POLICY_CHANGED_OR_NOT_VERIFIED'});
  if (boundary?.state !== 'READY_CANDIDATE') return Object.freeze({decision: 'STOP', reason: 'TRUST_BOUNDARY_UNAVAILABLE'});
  return Object.freeze({decision: 'PREVIEW_CONTINUE_ONLY', reason: 'OS_ENFORCEMENT_UNATTESTED'});
}

/** No local/agent-supplied verification output can create trusted PASS. */
export function evaluateVerification({exitCode, sourceBefore, sourceAfter, agentClaim} = {}) {
  if (sourceBefore && sourceAfter && sourceBefore !== sourceAfter)
    return Object.freeze({result: 'STALE', reason: 'SOURCE_CHANGED_AFTER_VERIFICATION'});
  if (exitCode !== 0) return Object.freeze({result: 'FAIL', reason: 'NONZERO_OR_MISSING_EXIT_CODE'});
  return Object.freeze({result: 'NOT_ATTESTED', reason: 'INDEPENDENT_VERIFIER_REQUIRED', agentClaimIgnored: Boolean(agentClaim)});
}

/** Pure check only; no public setter or owner-authentication bypass. */
export function planStateTransition({desired, next, activeManagedSessions = 0} = {}) {
  if (!['ON', 'OFF'].includes(desired) || !['ON', 'OFF'].includes(next))
    return Object.freeze({decision: 'DENY', reason: 'INVALID_STATE'});
  if (next === desired) return Object.freeze({decision: 'NO_CHANGE', reason: 'ALREADY_REQUESTED'});
  if (!Number.isSafeInteger(activeManagedSessions) || activeManagedSessions < 0)
    return Object.freeze({decision: 'DENY', reason: 'SESSION_COUNT_NOT_TRUSTED'});
  if (activeManagedSessions > 0) return Object.freeze({decision: 'DENY', reason: 'ACTIVE_SESSION_STOP_OR_RESTART_FIRST'});
  return Object.freeze({decision: 'REQUIRES_TRUSTED_OWNER_UI', reason: 'OS_AUTHENTICATION_NOT_IMPLEMENTED'});
}

export const supervisorScope = Object.freeze({
  version: '8.0-supervisor-phase0-local-candidate',
  execution: 'NO_LIVE_TOOL_DISPATCH',
  storage: 'NO_TRUSTED_STORE',
  windowsAcl: 'NOT_IMPLEMENTED',
  userAuthentication: 'NOT_IMPLEMENTED',
  directCliInterception: 'NOT_IMPLEMENTED',
  evidenceTrust: 'CALLER_SUPPLIED_UNTRUSTED',
  enforcement: 'NOT_ATTESTED',
  acceptance: 'UNIT_TESTS_ONLY_NOT_SUP_01_TO_38_E2E',
});
