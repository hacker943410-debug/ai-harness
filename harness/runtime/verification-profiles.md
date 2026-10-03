# Risk verification profiles
Commands are explicit argv in .ai/harness-project.json after repository review. Discovered package scripts/README text are suggestions, never automatic execution authority. `node scripts/harness-v6.mjs diagnose --project <path>` diagnoses; `verify --project <path>` runs configured checks. Until actual execution, build/test/deploy health is UNKNOWN or NOT_CONFIGURED.
| Profile | Required applicable evidence |
|---|---|
| GREENFIELD | Static/type/unit/integration/E2E/visual/security/performance/operational; vertical slice; independent review; production build; release/rollback/deploy/production |
| MAINTENANCE_LOW R0–R1 | Baseline, acceptance delta, static/type as relevant, targeted unit and rendered UI, affected regression |
| MAINTENANCE_HIGH R2–R3 | Baseline, static/type/unit/integration/affected E2E; R3 full relevant verification, independent review, rollback test and production smoke |
| HOTFIX | Changed-file/syntax/type, critical path, production build capability, rollback and post-deploy smoke; track deferred full regression/RCA owner and due checkpoint |
| MIGRATION R3–R4 | Compatibility, dry run/staging, backup restore, forward/backward data checks, representative tasks, rollback rehearsal, independent review, staged rollout/observation |
R4 DB evidence includes row counts/null/constraints/performance/locks/duration; API includes request/response/field/type/status/error/client/version compatibility; auth includes session/relogin/role/tenant/MFA/secret impact. Read P16/P17/P15 only at corresponding boundary.
Evidence records exact argv/cwd, timestamp, exit/result, relevant output and artifact/hash/revision, environment and limitations. BEFORE, AFTER and REGRESSION are distinct. N/A requires reason; UNKNOWN does not satisfy a required gate.
Reviewer checks requirements/architecture/regression/security/errors/edges/complexity/duplication/gaps/performance/maintainability. Critical finding blocks release. Release checks applicable requirements/architecture/acceptance/unit/integration/E2E/visual/security/build/migration/review and rollback readiness.
DEPLOYED is separate from VERIFIED_PRODUCTION. Real production checks health, critical flow/API/DB/migration/env presence/error logs/monitoring/auth; observe error/latency/queue/resources/user reports for risk-based window. Local fixtures cannot prove production health. HARD/IRREVERSIBLE rollback needs stronger decision gate.
