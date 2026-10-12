# AI Harness v6.2.0 — Release Notes

Release scope: v6.1 Codex compatibility and optional Office authoring guidance, v6.2 managed Codex execution/measurement/verification, Jev opt-in Shadow integration, CLI operations handbook.

## What changed
- Codex adapter compatibility discovery and safe native Skill catalog improvements.
- Four opt-in, project-scoped initial Office instruction skills for DOCX/PPTX/XLSX/PDF. **These are AI Harness-authored instructions, not externally validated document generation engines or Vercel-authored Office Skills.** They are not installed automatically.
- Managed Codex guard `scripts/harness-guard-v6-2.mjs`: fail-closed version/hash validation against installed immutable snapshots, real `turn.completed` usage instrumentation when available, existing v6 `evaluateTokenBudget` policy evaluation, scoped checkpoint gate and post-execution project verification.
- Jev `typesafe-ai/jev` through Vercel AI Gateway: modern API contract, explicit per-project synthetic live canary followed by Shadow opt-in, no credential persistence, non-sensitive synthetic enums only, deterministic router fallback.
- Comprehensive [CLI/GitHub/Codex runbook](CLI_ACCESS_AND_OPERATIONS_GUIDE.md), [execution enforcement design](EXECUTION_ENFORCEMENT.md) and [Jev setup](JEV_RUNTIME_INTEGRATION.md).

## Known scope restrictions — do not overclaim
- The guard affects **opt-in noninteractive managed** Codex invocations, NOT ordinary interactive `codex` sessions. No native always-on hook is installed.
- Token limits are evaluated **after completed turns**. There is no mid-turn compaction nor verified automatic Context reduction.
- Router model tier is advisory; actual Codex model choice and physical policy document reads remain unverified.
- Jev is OFF by default and opt-in Shadow only; no provider authorization or production approvals. Actual Jev live canary requires an independently supplied credential/authorization and may cost money. A green offline suite is **not** provider availability verification.
- No assertion of measured overall token savings or real-user workflow acceleration. The prior v6 benchmark is fixture-only.
- The bundled Office instructions do not provide third-party renderers or establish professional visual quality.
- Windows `.cmd` shim compatibility for `codex exec` requires testing in the target Windows environment.
- Do not point existing working projects at mutable GitHub branches; install from this immutable tag with safe plan/checkpoint/verification.

## Verification evidence
- Automated Windows and Ubuntu matrix checks: enhanced guard installed-project integration tests with mock Codex, negative tests, Jev offline tests, v6 full regression, static validators; Windows native PowerShell release/installation regression included in v6.2 release candidate CI.
- Real provider/API billed canary, user-host Codex E2E, semantic policy-read attestation, token savings measurement and deployment remain `NOT_RUN` unless independently evidenced.
- Test logs are associated with candidate PR [#3](https://github.com/hacker943410-debug/ai-harness/pull/3).

## Rollback
- Release immutable tag `v6.2.0` remains available after any rollback; prior stable `v6.0.0` is preserved.
- Before migrating an existing project, take recoverable checkpoint and preserve its pinned source, rules and custom Skills. Failed verification must not be labeled PASS.
