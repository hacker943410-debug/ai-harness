# Project mode and risk router
Inspect source/history, users/data/API contracts, deployment and request intent before selecting a mode. Missing production facts are UNKNOWN, not proof of GREENFIELD.
| Mode | Trigger | Procedure |
|---|---|---|
| GREENFIELD | No existing users/data/contracts/regression boundary | Intake, guided discovery/spec/design, acceptance, rendered UI, vertical slice, implementation, verify/review/release/deploy/production, retrospective/benchmark |
| MAINTENANCE | Existing application or working contract; bounded patch/feature/refactor | Baseline → delta discovery → impact → regression scope → patch plan → acceptance delta → minimal implementation → targeted and regression verification → review → release → deployment/production observation → retrospective |
| HOTFIX | Active outage/security incident/data damage/business interruption | Incident/severity → minimum root cause → minimal fix → critical verification → deployment decision → deploy/smoke → full regression/RCA/retrospective/follow-up |
| MIGRATION | Major Harness/framework/runtime/architecture/platform or DB/auth boundary change | Inventory/baseline/target/gap/compatibility → backup/rollback/plan → dry run/staging/representative tasks/regression/benchmark → decision → activate/production/observe |
Existing project adoption is installation intent, not a fifth product mode. Ask if mode uncertainty materially changes risk or verification.
Change types: PATCH, FEATURE, REFACTOR, DEPENDENCY, DATA, SECURITY, INFRA, HARNESS, HOTFIX.
Risk: R0 cosmetic; R1 limited UI behavior; R2 ordinary API/logic; R3 auth/payment/schema/deployment; R4 data transformation/security incident/production architecture/irreversible operation. Raise risk for confirmed boundaries. Reroute when patch reveals migration or incident; never lower mode/risk to evade gates.
Baseline records commit/branch/app/Harness/deployment/schema/migration versions, build/test/lint/type/critical E2E and production statuses, known failures. Impact covers direct/indirect/data/API/auth/UI/deployment/regression/rollback with unknowns explicit. Acceptance delta and regression criteria must both pass. Protect existing behavior; no unrelated cleanup, framework swap, env rename, broad formatting or retroactive refactor without a migration decision.
