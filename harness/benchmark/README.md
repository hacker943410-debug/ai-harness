# Local harness benchmark

Run with Node 22 or later:

```powershell
node scripts/benchmark-harness-v6.mjs --baseline-root C:/path/to/unchanged-v5 --out harness/benchmark
```

The runner reads the v5 checkout without modifying it and uses isolated temporary product fixtures for v6. It writes `baseline/v5.json` and `results/v6.json`. Each of the fourteen identical requests exercises routing, negative phase gates, project installation or adoption, verified fixture commands, and exact rollback. Timings measure these local operations, including filesystem work and subprocess verification; they do not measure an AI developing a product.

Context is the UTF-8 content of CORE, ROUTER, POLICY_INDEX and the policies selected for each request. V5 has no executable v6 phase/transaction engine: those baseline capabilities are reported as unavailable, never assigned invented latency or success scores. V5 context uses the same deterministic policy selection as v6 so this comparison isolates payload growth rather than claiming historical routing behavior. An existing Python `tiktoken` installation optionally measures `cl100k_base` tokens; choose its executable with `HARNESS_BENCHMARK_PYTHON` or use `python` on PATH. Without it, only bytes and the explicitly named `ceil(UTF8 bytes / 4)` estimate are reported. Neither is billed API token usage.

Task success means a harness fixture check passed. Reviewer findings, post-merge defects, visual regression, product architecture, real user completion, first deployment and production outcomes remain unavailable. Beginner and recovery cases test local route/gate behavior; no users or production services participate. Retries, fixture command calls, rollback counts and manual interventions count only this runner's operations. The runner does not download packages or call model providers.

Release gating fails on a fixture regression or unexplained context growth. Additive v6 context cost is recorded with its explanation: executable lifecycle, evidence and update contracts add text to the existing always-loaded runtime. Inspect the raw JSON, run the full negative test suite, and retain existing v5 regression evidence before release. A local benchmark is insufficient to establish product quality or production readiness.
