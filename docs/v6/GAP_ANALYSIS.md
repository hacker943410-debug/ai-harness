# v5.1 → v6.0 Gap Analysis

Prepared after Inventory, before runtime edits. Normative input: [Bootstrap specification](AI_HARNESS_V6_FINAL_UPGRADE_INSTRUCTION_v3.md).

| Capability | v5.1 status | Disposition | v6 acceptance / verification |
|---|---|---|---|
| CORE / precedence / JIT / 26 policies | ALREADY_IMPLEMENTED | KEEP + EXTEND | Same 26 policies and opt-in advisor; old regressions pass |
| Layer A/B/C and client manifests | ALREADY_IMPLEMENTED | KEEP | Machine installers and native Skills remain compatible |
| Environment diagnosis / beginner escort | PARTIAL | EXTEND | Project commands/capabilities inventoried without leaking environment values |
| Project init / linked instructions | PARTIAL | EXTEND | One-line install and adoption preserve unmanaged text and project commands |
| Full SDLC / acceptance-first / evidence / role review | PARTIAL (prose policies) | EXTEND | Executable gate rejects missing contracts, failed prior gates, critical findings and unverified production |
| Project modes / risk profiles | MISSING | EXTEND | Four mode flows plus adoption, risk-sensitive context/test selection |
| Development state / H1-H3 / freeze | MISSING | EXTEND | Active work checkpointed; unsafe deploy/DB/hotfix timing deferred |
| Transition / backfill / resume | MISSING | EXTEND | Complete manifest; goals/criteria/decisions/phase preserved; regression required |
| Version / manifest / source integrity | PARTIAL | EXTEND | Pin+index+adapter versions agree; required files and payload hashes validated |
| Local customization preservation | PARTIAL (Skill and Git refusal) | EXTEND | Managed-text conflict refusal and three-way base comparison; no product rewrite |
| Transaction / checkpoint / rollback | PARTIAL (machine installer) | EXTEND | Separate project-binding transaction; exact byte rollback, drift refusal and interrupted recovery |
| Token / context / model routing | PARTIAL | EXTEND | Dynamic tier catalog; budget actions and measurable JIT context; unknown token counts explicit |
| Verification / visual / production | PARTIAL | EXTEND | Applicable profiles, Evidence artifacts, N/A reasons, review role and production gate |
| Benchmark / learning | PARTIAL (Jev canary only) | EXTEND | Identical 14 representative cases, v5 baseline, v6 scenarios, actual times/calls, tokenizer provenance, regression limits |
| Build / patch / migration / changelog | PARTIAL | EXTEND | Evidence links, supported sources, limitations and release instructions |

Compatibility: retain policies, scripts, Skills and adapter layout. Legacy 4.x/5.x bindings are detected, but only available legacy formats are migrated; unknown/inconsistent versions block. No dependency swap, destructive product change or automatic project-wide refactor. Shared-source version mismatch blocks normal task loading and routes to migration. Current authorization covers this additive v6 upgrade; unresolved customization conflicts and external product deployment still need a concrete decision.

Stop conditions: baseline deterioration unexplained, incomplete transition state, custom rule conflict, missing rollback, unsafe active deployment/data transform, unresolved critical review, structural/behavioral test failure, or benchmark regression without an explained trade-off. Source activation follows validation, independent review and benchmark. Product production verification is N/A for this source-only release with a reason; benchmark simulations cannot claim real production success.
