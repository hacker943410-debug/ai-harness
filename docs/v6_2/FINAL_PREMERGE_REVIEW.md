# AI Harness v6.2 — Final Pre-Merge Review

Status: **RELEASE CANDIDATE — automated integration verification expanded; provider/real Codex E2E still NOT_RUN**, 2026-10-12 (Asia/Seoul).
Source: https://github.com/hacker943410-debug/ai-harness/pull/3
For operators joining from Codex/GitHub CLI: [CLI Access and Operations Guide](CLI_ACCESS_AND_OPERATIONS_GUIDE.md) provides copy/paste onboarding, branch safety, test commands, Jev, managed guard limitations and troubleshooting.
Target: `main`; candidate: `upgrade/v6.2`.
This is a review checklist, **not** release certification. Do not merge, retag or change production without explicit user/Codex approval.

## Branch ancestry and preservation
- `upgrade/v6.1` (SHA `fbcc7fe26d0fc53374d668d2c6cc5aea52f58343`) is a strict ancestor of `upgrade/v6.2`: comparison shows ahead commits and **0 behind**.
- No open PR targets v6.1 at time of review. Deleting the v6.1 branch **after confirmation** loses no code commits from v6.2, but does not merge v6.2 into main.
- `main` remains at `d0503b0f6aa07db4cdb5429e03b428f86d6f68e7` at review time.
- Preserve the 26 policies, managed/unmanaged adapter separation, project-specific rules/Skills, verified 6.0 baseline and rollback plan.

## Included changes
- v6.1: Codex adapter metadata, CLI probe, Office instruction Skill candidates (DOCX/PPTX/XLSX/PDF).
- v6.2: opt-in managed `codex exec --json` guard, source-pin preflight, real completed-turn usage to the existing `evaluateTokenBudget`, post-run verification and evidence, hard-budget continuation checkpoint.
- Jev: reuse `jev-decision.mjs`; `POST https://ai-gateway.vercel.sh/v1/evaluate`; explicit project activation following one synthetic live canary; `shadow` only, no change to deterministic routes; filtered synthetic non-sensitive metadata only; fail-safe fallback.
- Security hardening: activation verifies pinned root/version/source SHA **before paid canary**; `status` exposes pin validity; no implicit Windows user-scope key discovery; no API key written to Git or project state.

## Findings and release gates
| Gate | State in candidate | What Codex must prove before approval |
|---|---|---|
| GitHub static Linux/Windows CI | Verify latest head Actions | Both jobs green and linked to the **current commit**, not an older one |
| Jev offline tests | Added | Run `node --test scripts/test-jev-v6-2.mjs` and `node scripts/test-jev-scenarios.mjs` |
| Guard regression | Added | Run `node --test scripts/test-harness-guard-v6-2.mjs` |
| Harness v6.0 regression | Existing | Run `node scripts/validate-harness-v6.mjs`, `node --test scripts/test-harness-v6.mjs`, PowerShell release validation |
| Actual Vercel authentication | **NOT_RUN** | Authorized API key, successful synthetic canary, real billing/entitlement; redact logs |
| Jev shadow on real managed Codex | **NOT_RUN** | Demonstrate eligible low-risk task yields bounded shadow evidence and fallback on errors; no sensitive task text transmitted |
| Provider token usage and economic value | **NOT_MEASURED** | Compare same tasks with Jev ON/OFF, collect actual tokens/cost/latency/success. No invented savings |
| Direct interactive `codex` hooks | **NOT_INSTALLED** | Do not claim managed guard intercepts direct sessions. An opt-in trusted hook is separate scope |
| Token budget mid-turn | **NOT_ENFORCED** | Budget is evaluated after a completed turn. Next managed turn may require checkpoint |
| Actual JIT policy read evidence | **UNOBSERVED** | References are provided, not guaranteed file reads; an external trace/attestation may be needed |
| 6.1 Office Skill quality | **REVIEW REQUIRED** | These four are *original short instruction files*, **not** independently validated third-party Office engines. Choose removal, replacement, or accept as limited candidates explicitly |
| 6.2 release pin/version | **NOT UPDATED BY DESIGN** | Only after tests: align `HARNESS_VERSION`, manifest, `POLICY_INDEX.yaml`, plugin/adapters, tag `v6.2.0`, immutable source hash and compatible migration |
| Migration/rollback | **NOT_RUN ON REAL USER PROJECT** | Test on disposable project, check hash pin, drift rejection, existing custom rules and regression, then restore |

## Codex verification commands
```powershell
git fetch origin
git switch upgrade/v6.2
node --test scripts/test-jev-v6-2.mjs
node scripts/test-jev-scenarios.mjs
node --test scripts/test-harness-guard-v6-2.mjs
node --test scripts/test-codex-compat-v6-1.mjs
node scripts/validate-office-skills-v6-1.mjs
node scripts/validate-harness-v6.mjs
node --test scripts/test-harness-v6.mjs
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRelease.ps1
```

## Approved rollout sequencing
1. Review PR diff and code ownership. Decide the four **unvalidated bundled Office instruction Skills** separately.
2. Run all offline CI tests from the exact candidate SHA, then use disposable test projects for Windows guard, Jev shadow and source pin tests.
3. Only after explicit authorization, register the Jev API key in a trusted **process environment** and run synthetic live canary; do not commit, paste, or log credentials.
4. Compare actual token/latency/cost and test quality. Verify that deterministic routes retain control.
5. Codex prepares a **separate release finalization change** to set v6.2.0 identity, update/pin manifest and distribution ref, and verify hashes/rollback. No automatic git tagging from this review.
6. Human decides whether to merge Draft PR #3. If approved, merge and install into projects one by one using safe checkpoint/migration.

## v6.1 cleanup
`upgrade/v6.1` can be deleted once confirmed no independent consumer/PR relies on that branch and v6.2 is backed up. Suggested operator command:
```powershell
git push origin --delete upgrade/v6.1
```
This does not delete any of its ancestors from `upgrade/v6.2`. Branch deletion is not required for v6.2 correctness; keep it until review if unsure.

## 2026-10-12 release-candidate delta
- Corrected the installed snapshot path false-positive: immutable source matching now uses digest+version rather than absolute path identity.
- Added installed-project managed-guard integration tests with mocked Codex JSONL, plus failure, missing telemetry, budget and checkpoint cases.
- Release metadata 6.2.0 is staged for CI; tag will point to final merge commit, not candidate branch.
- Explicit limitations: provider-billed canary and full real Codex E2E remain NOT_RUN; do not claim fully verified provider interoperability or measured token savings.
