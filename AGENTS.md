# AI Harness runtime entry

Version source: `HARNESS_VERSION`; require agreement with `harness/manifest.yaml` and `POLICY_INDEX.yaml`.
Read CORE.md, ROUTER.md and POLICY_INDEX.yaml first. Preserve Layer A (source), Layer B (PC shared runtime), Layer C (project bindings). Select only current Task/Phase/Risk/Boundary policies; never preload P01–P26 or all Skills. Jev remains disabled by default, advisory only, with existing-router fallback.

Harness upgrade invariant: install/update/upgrade/version/latest-Harness requests route to `harness/runtime/harness-update-router.md` and `harness/update/UPDATE_PROTOCOL.md`. Detect current/target version, project mode, development state, custom rules/Skills/policies, checkpoint, compatibility/gap, transition manifest, migration, harness validation, regression, critical backfill, transition audit, resume and benchmark. Never directly replace rules inside an active implementation phase for a major update. Preserve existing behavior and unmanaged project instructions; no retroactive refactor without an explicit migration decision.

For product work route to `harness/runtime/orchestrator.md`; set acceptance before implementation, retain phase gates, decision gates and beginner briefing, and require execution evidence before PASS. Resolve actual runtime model choices by economy/balanced/frontier tier; logically separate Builder and Reviewer. Do not fabricate commands/results, ignore failed gates or critical findings, weaken verification for token savings, silently break contracts, or load every document.
