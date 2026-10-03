# v6.0.0 build and release evidence

Date: 2026-10-03 UTC. Source baseline: v5.1, Git commit `8ebab0087b228c0203a202bead8fb56853d9cb27`. Work mode: MIGRATION / H3 / R3, isolated `upgrade/v6.0` worktree. The installed v5 source and consuming product were preserved.

## Acceptance and result

Implement the supplied [final Bootstrap specification](../docs/v6/AI_HARNESS_V6_FINAL_UPGRADE_INSTRUCTION_v3.md) in the GitHub source, retain existing capabilities, and make one-line project installation/adoption/update requests invoke the complete safe procedure. A binding transaction cannot assert product release or production completion.

Inventory, Gap Analysis and file migration plan preceded implementation. [Traceability](../docs/v6/REQUIREMENTS_TRACEABILITY.md) maps sections 0–200 to runtime behavior or agent protocols. Protocol mapping is distinct from measured product outcomes.

| Check | Actual result | Evidence |
|---|---|---|
| v5 repository baseline | PASS_WITH_WARNING; existing markitdown prerelease warning | [v5 repo](../docs/v6/evidence/v5-repo-check.json) |
| v5 native install/Skill baseline | 28/28 PASS | [v5 release](../docs/v6/evidence/v5-release-check.txt) |
| v5 Jev offline scenarios | 22/22 PASS | [v5 Jev](../docs/v6/evidence/v5-jev-check.txt) |
| v6 structural + repository validator | PASS_WITH_WARNING; same existing warning | [v6 repo](../docs/v6/evidence/v6-repo-check.json) |
| v6 native install/Skill/source-major staging | 29/29 PASS | [v6 release](../docs/v6/evidence/v6-release-check.txt) |
| v6 Jev offline scenarios | 22/22 PASS; no provider calls | [v6 Jev](../docs/v6/evidence/v6-jev-check.txt) |
| Runtime behavior and negative gates | 40/40 PASS; 0 skipped; 252.625 seconds | [full TAP](../docs/v6/evidence/v6-tests.txt) |
| Independent safety review | PASS; no unresolved Critical/High in scope | [review and reviewed hashes](../docs/v6/evidence/INDEPENDENT_REVIEW.md) |
| Existing policy/Skill reuse | All recorded byte hashes match baseline | [reuse hashes](../docs/v6/evidence/reuse-integrity.json) |
| Same-input local Benchmark | 14/14 PASS; 0 fixture regressions | [v5](benchmark/baseline/v5.json), [v6](benchmark/results/v6.json) |

Commands: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Test-HarnessRepo.ps1 -Json`; same interpreter for `scripts/Test-HarnessRelease.ps1`; `node scripts/test-jev-scenarios.mjs`; `node scripts/validate-harness-v6.mjs`; `node --test scripts/test-harness-v6.mjs`; `node scripts/benchmark-harness-v6.mjs --baseline-root <unchanged-v5> --out harness/benchmark`.

Executed on Windows, PowerShell 5.1 and Node v24.13.0. Minimum supported Node is 22; this run does not establish a complete OS/Node version matrix. Verification commands execute with explicit argv and `shell:false`; command output is hashed rather than copied into transition state.

## Before / after and regression scope

Before: prose JIT policy router, machine installers and Skill validation; no executable project phase engine, project transition transaction or same-input benchmark. After: sixteen phase contracts; four project modes; independent development state; immutable project source pins; read-only plan; checkpoint/freeze; preservation; regression; backfill; transition audit; verified resume and rollback. Known v5.1 templates migrate; unknown custom blocks create a preserved conflict.

Full tests exercise true empty GREENFIELD, MAINTENANCE, HOTFIX and MIGRATION flows; one-line adoption; active development goal/phase/decisions preservation; unsafe-operation deferral; transition audit/resume; source pin drift; forged/stale plans; product/instruction/artifact drift; exact rollback; interrupted recorded writes; baseline failure; UTF-16 refusal; symlink/junction boundaries and synthetic credential refusal. All sixteen phase gates execute locally; simulated deployment is rejected as production evidence.

## Measured benchmark and trade-off

Fourteen identical requests use the same deterministic policy selection for both context payloads. `tiktoken 0.3.3`, encoding `cl100k_base`, measured v5 **583,860** and v6 **591,911** context tokens: **+8,051 (+1.38%)**. UTF-8 bytes: 1,896,037 → 1,946,076 (**+50,039**). Added lifecycle/evidence/update contracts explain the growth. No reduction in provider billing is claimed. JIT, compaction and model tiers are implemented, but their economic benefit requires provider task replay.

V6 local fixtures took **140.045 seconds**, made **100 public Harness API calls** and **144 verification subprocess calls**, with **0 runner retries** and **0 runner manual interventions**. These counters describe this runner, not implementation effort or novice behavior. V5 executable outcomes are unavailable because its source has no v6 engine; no synthetic v5 timing or success rate is assigned. Exact input/provenance hashes, per-case checks and raw measurements are retained in JSON. Benchmark run-time payload hash and final distribution hash are separately recorded because a later README correction does not alter measured CORE/ROUTER/Index/policy inputs.

## Known limitations and activation

No real product deployment, novice user study, paid model replay, billed API token measurement or post-merge defect study occurred. Beginner completion and production metrics remain null with explicit reasons. Phase artifacts and logical reviewer labels are freshness checks, not identity or truth attestation. Custom legacy YAML remains ACTIVE_LOCAL_CONSTRAINTS and requires agent semantic reconciliation. Credential scanning is defense in depth. Interrupted-write fixtures do not prove physical power-loss durability or protection against adversarial concurrent filesystem changes. V4 format recognition is declared; only v5.1 and v6 historical bindings were tested.

Source activation requires all checks above, unchanged reviewed executable files, secret guard PASS, and a verified published ref. Published-ref verification is recorded separately in [release evidence](../docs/v6/evidence/release-validation.json). Missing deployment/user-study evidence prevents those specific outcome claims, rather than silently becoming PASS. Product and machine authentication remain separate workflows.
