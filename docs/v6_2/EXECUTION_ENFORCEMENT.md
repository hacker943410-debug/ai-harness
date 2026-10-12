# AI Harness v6.2 — Execution Enforcement Plan (UNRELEASED)

## Findings from v6.0 source
- \`evaluateTokenBudget()\` was only called in unit tests; core product CLI paths did not invoke it per task.
- The model-router selected an advisory tier but did not force the current Codex model.
- Phase Gate \`phase\` was a callable command, not a universal pre/post execution interceptor.
- The thin project AGENTS.md is an instruction bridge, not proof that other documents were read.
- 14-fixture benchmark reports context text size and deterministic checks, **not Codex provider usage or product quality**.

## v6.2 remedy: deterministic guarded execution
Entry point: \`node scripts/harness-guard-v6-2.mjs\`. This is an **opt-in, auditable wrapper** for \`codex exec --json\`, not an always-on interceptor for \`codex\` interactive sessions.

1. PRE-FLIGHT: validate installed project binding, immutable pinned source identity, current mode/state, route, required JIT paths and migration freeze.
2. TASK: invoke \`codex exec --json\` with \`shell:false\` and explicit project CWD. Pass a short managed preamble and selected JIT **references** to agent; the wrapper does not falsely claim actual reads.
3. USAGE: parse only real \`turn.completed.usage\` counters. Do not infer billed tokens from bytes or include cached inputs twice. Unknown metrics remain UNKNOWN and a missing provider usage event prevents run-level PASS.
4. BUDGET: require explicitly configured soft/hard token limits. Apply \`COMPACT_NEXT_TURN\` / \`CHECKPOINT_REQUIRED\` **after the completed turn**. Before the following managed run, hard-limit requires an existing project checkpoint artifact. Budget does not interrupt an in-flight turn.
5. COMPLETION: after an otherwise successful run call existing \`verifyProject()\`; missing/failed verification gives **FAIL**, never PASS. Store compact JSON evidence in \`.ai/harness-guard/\` without raw model output, credentials or secret-filled logs.
6. REPORT: distinguish planned JIT references, actual agent reads (UNOBSERVED), model selected (UNKNOWN), real token usage, fixture results, verification and enforcement scope.

## Commands on an immutable verified local release
\`\`\`powershell
node scripts/harness-guard-v6-2.mjs preflight --project C:/project --request "Fix the bug"
node scripts/harness-guard-v6-2.mjs run --project C:/project --request "Fix the bug" --soft-limit 80000 --hard-limit 110000
node scripts/harness-guard-v6-2.mjs verify --project C:/project
node scripts/harness-guard-v6-2.mjs report --project C:/project

node --test scripts/test-harness-guard-v6-2.mjs
node --test scripts/test-harness-v6.mjs
node scripts/validate-harness-v6.mjs
node --test scripts/test-codex-compat-v6-1.mjs
node scripts/validate-office-skills-v6-1.mjs
\`\`\`
For Windows npm .cmd shims, Codex subprocess compatibility must be validated; direct \`spawn(shell:false)\` may fail with ENOENT/EINVAL. Report NOT_RUN rather than silently using a shell fallback.

\`guard_v6_2.token_budget\` may be configured in \`.ai/harness-project.json\` explicitly:
\`\`\`json
{"guard_v6_2":{"token_budget":{"soft_limit":80000,"hard_limit":110000}}}
\`\`\`
This JSON is an **additional property example**, not a replacement for other required project configuration. Existing project bind versions and custom rules remain unchanged.

## Boundary: what is and is not enforced
| Invariant | Guarded exec | Direct interactive Codex |
|---|---|---|
| Verified Harness source / Preflight | Enforced | Advisory unless separate hook/launcher |
| Per-run actual usage if exposed | Measured | Not intercepted |
| Hard budget checkpoint before next guarded run | Enforced | Not intercepted |
| Test/verification after guarded run | Enforced | Not intercepted |
| Actual JIT file reads | UNOBSERVED; selected references given | UNOBSERVED |
| Actual model tier | UNKNOWN; router recommendation only | Not controlled |
| Mid-turn budget interruption | Not supported | Not supported by wrapper |

## Correctness, privacy and rollout
- No automatic installation or activation of Hooks: Codex hooks have version/trust/loader differences; see https://developers.openai.com/plugins/build/plugins and https://developers.openai.com/docs/hooks. A Hook-enabled path may be proposed later but must be tested against installed CLI and explicitly trusted by user.
- This wrapper does not assume Codex supports a model command beyond tested \`exec --json\`; model routing remains advisory pending runtime capability verification.
- Structured evidence reports no user prompts or raw stdout. Do not upload raw logs automatically. Local .ai path must be gitignored; verify on release.
- Release version remains 6.0.0 on this **candidate** branch until source_ref/tag/adapter/index/manifest versions can be published consistently. Do not distribute mutable branch as a stable version.
- Office Skills from v6.1 remain optional and **not** auto-installed; whether to replace first-party instructions with validated external tools is a separate review item.

## Acceptance and negative tests before merging
- Unit: actual usage parse, unknown usage handling, invalid/project/budget fail-closed.
- Integration on disposable project: real pinned source, configured build/test/critical regression, successful fake Codex JSONL stream, malformed/missing stream, failing project test, two-run hard budget checkpoint, modification of tracked managed file, symlink path rejection, Windows PowerShell and .cmd compatibility.
- Real Codex E2E: one small bug, one feature, one migration. Collect actual token/time; compare against identical unguarded work with comparable approval/model settings.
- Confirm no claim of reduced tokens until real provider measurements support it. \`verifyProject\` tests the **configured** commands, not every possible unconfigured application test. Document gaps and unverified evidence.
- Fail release if regression fails. Codex independently reviews and merges PR; this branch never auto-merges.

## Suggested next enforcement phase
A trusted opt-in project/plugin Hook or a controlled managed-launch integration can cover interactive start/end and tool events, but Hooks may be skipped when untrusted or in unsupported modes; they MUST report their activation state. Neither Hook nor wrapper can guarantee an LLM will *semantically* follow all policies; enforce deterministically checkable gates and measure adherence separately.

### Windows binary selection
On Windows, if `codex` resolves only to an npm `.cmd` shim, some Node `spawn(shell:false)` builds cannot launch it. Supply a verified absolute path to `codex.exe` with `--codex-bin`. The wrapper intentionally does not enable `shell:true` or shell-interpolate user prompts. An unresolved binary or unsupported shim must fail closed and be reported; Codex E2E on the target Windows host is still pending.

### Structured checkpoint evidence for hard budget
A previous managed run with `CHECKPOINT_REQUIRED` cannot be bypassed with an arbitrary existing file. The next `run --checkpoint-evidence .ai/harness-guard/checkpoint.json` accepts a JSON contract only when `kind` is `harness-budget-checkpoint`, `previous_run_id` equals `.ai/harness-guard/latest.json.run_id`, `source_hash` equals the currently pinned Harness source hash, and `goal`, `current_phase`, `acceptance_criteria` (non-empty array), and `next_task` are provided. Record relevant decisions, known failures, worktree revision and rollback information when applicable; never include credentials. Codex must inspect the checkpoint before approving the next managed run. This is a logical continuation checkpoint, not proof of a filesystem backup.

Example structure (populate with actual evidence, not placeholders in production):

```json
{"kind":"harness-budget-checkpoint","previous_run_id":"<actual-run-id>","source_hash":"<actual-pinned-source-hash>","goal":"<current-goal>","current_phase":"08_FEATURE_IMPLEMENTATION","acceptance_criteria":["<actual-acceptance>"],"next_task":"<next-action>"}
```
