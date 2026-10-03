# AI Harness v6.0.0 implementation report

The GitHub source implements the final [Bootstrap / Upgrade Specification v3](AI_HARNESS_V6_FINAL_UPGRADE_INSTRUCTION_v3.md). [Inventory](INVENTORY.md) → [Gap Analysis](GAP_ANALYSIS.md) → [File Migration Plan](FILE_MIGRATION_PLAN.md) was completed before runtime changes. [Build log](../../harness/build-log.md) is the acceptance/evidence record; [release verification](evidence/release-validation.json) identifies the distributed source.

## Runtime changes

- `HARNESS_VERSION` and `harness/manifest.yaml` provide canonical 6.0.0 identity, capability, payload and compatibility contracts; Index/plugin versions agree.
- `scripts/harness-engine.mjs` executes sixteen phase contracts, four project modes, development state, H1/H2/H3 timing, risk, dynamic model tiers, budgets and resume gates.
- `scripts/harness-project.mjs` diagnoses and plans without writes, pins a verified immutable release, compares local/upstream rules, preserves product/custom bytes and decisions, journals changes, runs configured regression, audits and resumes. Unsafe deployment/DB/incident work defers major updates. Stale/forged plans and modified known baselines block safely.
- `scripts/harness-v6.mjs` exposes inspect/diagnose/route/plan/apply/verify/rollback/phase. The thin global CORE/router and project bridge make a one-line update request invoke the complete protocol without this specification being pasted again.
- `install.ps1` stages a separate major-version candidate before mutating the legacy shared source. Existing machine installers, authentication boundaries, native client integration, dashboard Skill and optional disabled Jev remain in their original layer.
- Runtime/update protocols cover acceptance-first, vertical slices, beginner briefings, material decisions, separate builder/reviewer roles, safe checkpoints, progressive rules, critical gate backfill, production checks and learning. [Requirements traceability](REQUIREMENTS_TRACEABILITY.md) distinguishes executable behavior from instruction protocols.

Existing 26 policies and recorded Skill assets were retained byte for byte. No tracked source file was deleted. Root CORE/ROUTER/Index/initializer/Doctor/README/patch notes, plugin version metadata and repository/release validators were extended. New runtime/update protocols, version/manifest, CLI engines, validation, benchmark, migration/changelog documents and evidence are listed in the file plan. No consuming project product or machine credential state is migrated as a side effect of publishing source.

## Beginner and token behavior

Beginner Mode defaults ON and survives adoption/update. The agent asks the next material question, explains effects/defaults/verification, preserves existing framework and deployment choices, and briefs on phases, failures and decisions. Fixtures validate routing and recovery; a live novice study is still needed to measure comprehension or first deployment success.

JIT retains current-phase policies, compaction saves goal/criteria/evidence/next task, and model tiers resolve from the current runtime catalog. Budgets never waive verification or release gates. The controlled benchmark measured **583,860 → 591,911** `cl100k_base` context tokens, **+1.38%**, because new safety contracts add text. Billed-token savings and model quality were not measured.

## Evidence and benchmark

Runtime **40/40**, benchmark **14/14**, existing install/Skill/source-release **29/29**, Jev **22/22**, structural validator **PASS**, and independent safety review **PASS** with no unresolved Critical/High findings in its scope. Repository validation retains the baseline markitdown prerelease warning. Commands, exact checks, hashes and environment are linked from the [build log](../../harness/build-log.md).

Fresh GitHub bootstrap succeeded. The normalized distribution passed **5/5** critical runtime scenarios and **29/29** native regressions; all independently reviewed executable hashes remained unchanged. The source payload identity and final-tag release attestation are linked from the build log.

Benchmark: **140.045 seconds**, **100 Harness API calls**, **144 verification commands**, zero runner retries/manual interventions and zero fixture regressions. Raw [v5 baseline](../../harness/benchmark/baseline/v5.json) and [v6 results](../../harness/benchmark/results/v6.json) retain per-case outputs and explicit unavailable metrics. Cases include beginner/empty new projects, bug/UI/API/auth/DB work, adoption, migration, active work and incident recovery. These are Harness fixtures, not AI product-development or real operational trials.

## Compatibility, risk and next validation

Tested bindings: v5.1 → v6.0 and v6.0 → v6.0. Recognized v4 formats are declared without a historical v4 test fixture. Unknown/custom managed instructions, incompatible encoding and ambiguous legacy active state require a preserved, reviewable reconciliation. Rollback restores owned instruction/binding bytes and rechecks commands; later edits prevent destructive restoration.

No real production deployment, user study, paid provider replay or complete cross-platform matrix was performed. Evidence digests detect changed artifacts but cannot authenticate arbitrary artifact contents. Secret detection is defense in depth; concurrent adversarial filesystem mutation and physical crash durability are unproven. Semantic legacy YAML migration remains an operator/agent obligation.

Recommended follow-up is a separately authorized real novice task study, provider token/cost replay, Node22/Linux matrix and product-specific deployment/DB recovery exercises. They are recorded as unmeasured outcomes and do not become fabricated completion evidence for this source release.
