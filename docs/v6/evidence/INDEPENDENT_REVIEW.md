# Independent v6 safety review

**Result: PASS — no unresolved critical or high findings in this focused review.**

Reviewer: independent review agent, logically separate from implementation and broad regression execution. Review completed 2026-10-03 UTC. Implementation files were not edited by this reviewer; this report is the only authorized repository write.

Scope: Inventory/Gap/Migration Plan and bootstrap requirements, project migration transactions, phase gates and their CLI persistence, legacy preservation, immutable source bindings, rollback, credential handling, path boundaries, and major source update behavior. This is a scoped code and local runtime review, not a production deployment certification.

## Findings, fixes and evidence

| Finding reproduced during review | Final disposition and verification |
|---|---|
| Supplied state could clear an observed active deployment and permit migration. | Fixed. Final direct reproduction rejects the override with `STATE_OVERRIDE_CONFLICT`. |
| Same-version pinned source changes were reported current and not checked before phase writes. | Fixed by pinned source identity checks in inspection and the phase command. Final source review verified version and content hash checks before persistence; broad regression evidence is recorded separately. |
| A second write to state replaced the only recoverable intermediate hash. | Fixed by write-ahead hash history. Independently ran the focused interrupted-state regression: PASS, including restoration of original instruction bytes. This simulates an interrupted recorded write; it is not a physical power-loss test. |
| Unknown legacy managed instructions and a bridge with a recognized heading were overwritten. | Fixed by exact known-template comparison; final custom-block reproduction is BLOCKED. Independently ran the actual v5.1-template upgrade and exact rollback regression: PASS. The implementation retains original YAML in `legacy_local_contract` with `ACTIVE_LOCAL_CONSTRAINTS`; this preservation mechanism was also inspected in source. |
| Snapshot parent ancestors could contain a junction. | Fixed. Final direct reproduction rejects an ancestor junction with `SNAPSHOT_SYMLINK_BOUNDARY`. |
| UTF-16 instructions could be silently corrupted by UTF-8 rewriting. | Fixed. Final direct reproduction rejects them with `ENCODING_CONFLICT`, preserving the input file. Standard UTF-8 unmanaged CRLF prefix and suffix preservation was independently observed. |
| YAML credential scalars and separate credential argv flags could enter plans. | Fixed for the reported cases. Final synthetic YAML-password and `--token value` reproductions reject with `SECRET_IN_STATE` and `CREDENTIAL_ARGUMENT_FORBIDDEN`. Phase persistence now calls the shared scanner. No real credentials were used in review. |
| An evidence object with a reference and failed command exit code was accepted. | Fixed. Final direct engine reproduction rejects `exit_code: 1` even with an artifact reference. |
| CLI evidence references had no existence/freshness binding. | Fixed with local artifact digests, prerequisite revalidation, and product fingerprints on verification/review/release/deployment gates. Final source inspection included canonical and compressed prerequisite paths. The separate validation suite owns the complete artifact/product-drift regression results. |
| Supplying a legacy-state mapping accidentally skipped its comparison. | Fixed by recording whether canonical state existed before merging supplied values. Final direct reproduction with a different goal, phase and next task is BLOCKED with `STATE_PRESERVATION_CONFLICT`. Legacy state reference hashes are compared before application. |
| A reviewed plan could be edited to claim version 7 while installing v6 and still return PASS. | Fixed by comparing fresh semantic fields and using the fresh payload. Final direct reproduction rejects the edited target with `PLAN_SEMANTIC_DRIFT`. |
| Upstream acceptance changes left compressed verification/review aliases reusable. | Fixed centrally in the phase engine. Final direct reproduction confirms both aliases become `NOT_STARTED`. |
| Comparing all Git status entries rejected the documented saved-plan workflow because saving `.ai/v6-plan.json` creates an untracked entry. | Fixed by comparing commit/branch while retaining product, managed-file and state-reference hashes. Independent clean-Git reproduction: save the exact READY plan under `.ai`, apply it, immediately verify — **PASS / PASS**. |
| The source bootstrap could move a legacy mutable checkout across a major version before project migration. | Fixed by staging a separate candidate on a detected major boundary. Final source inspection verified this guard in both branch and detached update paths. The implementation owner separately reported the local source-release regression as 29/29 PASS; this reviewer did not perform a live network update or publication. |

## Independently executed focused command

```text
node --test --test-name-pattern='actual registered v5.1|intermediate recorded state write' scripts/test-harness-v6.mjs
tests 2; pass 2; fail 0; exit 0
```

Other reproductions used isolated temporary projects and direct imports of `planProject`, `applyPlan`, `verifyProject`, `transitionPhase`, and the actual phase CLI. The final saved-plan fixture is `%TEMP%/harness-final-review-vRMW88`; the final grouped boundary checks are under `%TEMP%/harness-final-review-qRWGn5`. These contain synthetic local test data and were retained for troubleshooting. No network publication occurred during this review.

## Reviewed implementation identities

SHA-256 recorded at the final review checkpoint:

| File | SHA-256 |
|---|---|
| `scripts/harness-project.mjs` | `b3480853633bb9fa17372107e73d4c52309a3a477a2afb7e8ad8b9a90101d5d5` |
| `scripts/harness-v6.mjs` | `9f057b159203567beaf121cc26a52a93b0b28ca61665e563d4d90c350883a0d7` |
| `scripts/harness-engine.mjs` | `85f3b11a69b625c27b8f6edf79404c2b44367249f952b3a5253de4ceecd9af6b` |
| `install.ps1` | `411399e1f67eff21ae2adf42bd4139162bbc5f3044f6eb5fa4b748c1df670b9b` |

## Limits and activation condition

- Artifact existence, digests and subject fingerprints detect missing or changed evidence; they do not independently authenticate the truth of arbitrary human-authored artifact contents or prove production execution. Logical review-role labels are not identity attestation.
- Legacy free-form decisions and unknown YAML retain their original references and require semantic reconciliation by the operator/agent. The runtime is not a general YAML semantic migration engine.
- Credential scanning is defense in depth for the checked formats, not a proof that every possible secret representation can be recognized.
- Filesystem checks and simulated interruption tests do not constitute adversarial concurrent filesystem or physical crash durability testing.
- No broad test suite or benchmark result is invented or repeated here. Source activation remains conditional on the separate final validator, regression and benchmark results being satisfactory and on these reviewed implementation files remaining unchanged.

Within these stated boundaries, the reported critical/high issues are resolved and this independent review does not block source activation.
