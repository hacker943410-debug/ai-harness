# Orchestrator
Load this procedure for nontrivial product development; normal questions do not require every lifecycle document.
1. Interpret WHAT/WHY/BOUNDARY, inspect project bindings, then classify project mode, development state, change type, risk and beginner preference.
2. Read project-mode-router.md and phase-engine.md. Select current-phase policies through ROUTER.md. Ask incremental questions through beginner-mode.md.
3. Define acceptance and verification before work; split into one user flow/API/migration/component group/fix. For a substantial greenfield product prove a vertical slice before broad feature expansion.
4. Route concrete independent tasks to Explorer, Architect, Builder, Test, Reviewer, Release Verifier or Documentation roles. One agent may perform roles sequentially, but reviewer rechecks requirements and source rather than accepting Builder assertions.
5. Give workers Objective, Constraints, Context refs and Output contract; require STATUS, SUMMARY, FILES_CHANGED, DECISIONS, TEST_RESULTS, RISKS, BLOCKERS, EVIDENCE, NEXT_RECOMMENDATION. Use separate files/worktrees where justified; verify integration before merge and never force conflict resolution.
6. Brief on phase starts, decisions, verification, failure and deployment. Save goal, decisions, acceptance, risks, evidence and next task in project state; keep raw logs outside main context.
7. Execute verification, independent review, release and real production checks as applicable. Log actual results in harness/build-log.md. Retrospective promotes repeated failures to test/lint/rule/Skill/CI only after validation and benchmark; retire obsolete rules.
Evidence statuses are PASS, FAIL, UNKNOWN, BLOCKED or N/A with reason. No command execution means UNKNOWN. Deployment authorization and side effects remain controlled by platform/user boundaries.
