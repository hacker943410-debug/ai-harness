# Harness install/update router
Triggered by install/update/upgrade/latest/version/migration requests, including Korean equivalents. This procedure is built in: users need only request an update.
1. `node scripts/harness-v6.mjs inspect --project <path>` reads versions, source manifest, project config/state, transitions and custom binding inventory.
2. `node scripts/harness-v6.mjs route --project <path> --request '<one line>'` classifies intent, mode, state, H1/H2/H3, risk, safe timing and profiles.
3. No Harness + empty project: INSTALL. No Harness + application/history: EXISTING_PROJECT_ADOPTION. Existing Harness same version: REPAIR/RECONCILE assessment. Different major/rules: MIGRATION; compatible smaller change: UPDATE. An install word does not authorize overwrite.
4. H1 documentation/reference/briefing patch: preserve active phase, validate narrow changes. H2 workflow/gate/JIT/model/token/review changes: checkpoint and normally apply next phase. H3 major/core/agent/phase-engine transition: checkpoint→freeze→migration→audit→regression→resume.
5. HOTFIX, active DB migration, data conversion and production deployment defer major updates to stable named checkpoint. HARNESS_BLOCKER permits only minimal fix with recorded inability to continue.
6. Read UPDATE_PROTOCOL.md, and ADOPTION_PROTOCOL.md or TRANSITION_PROTOCOL.md only when relevant. Choose verification-profiles.md, token-policy.md and model-router.md. Detect pending transitions/deferred target before making a new plan.
Outputs retain current/target versions, intent/mode/state/change/update class/risk/checkpoint/verification/token/model routing, conflicts, deferred reason/target and next action. Missing facts remain UNKNOWN; ambiguity involving destructive or protected behavior invokes decision-gate.md.
