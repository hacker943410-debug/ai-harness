# Jev integration in AI Harness v6.2 (candidate, not released)

## Diagnosis
The existing Harness already contained `scripts/jev-decision.mjs`, `scripts/test-jev-scenarios.mjs`, provider `vercel_ai_gateway`, model `typesafe-ai/jev`, and a historical **22/22 offline test**. However Global `enabled_by_default: false`, a user API key alone did not activate project mode, and normal Codex/v6.2 guard execution did not call Jev. The old adapter called a legacy `/v4/ai/evaluation-model` URL. Vercel's currently documented HTTP endpoint is `POST https://ai-gateway.vercel.sh/v1/evaluate`, with `model`, `state` and keyed `questions` in JSON.

Official references:
- https://vercel.com/i/jev-integrations
- https://vercel.com/changelog/ai-gateway-now-supports-typesafe-clients-and-http-api-for-jev
- https://vercel.com/ai-gateway/models/jev

## Scope and operational authority
Jev is a bounded decision advisor, NOT a replacement for the Codex implementation/review model. Default project state remains OFF. Only a project explicitly activated after **a successful live synthetic canary** may call Jev automatically, and only in `shadow` mode. Until calibration establishes reliable decision thresholds, do NOT automatically accept Jev choices or enable advisory mutation.

Every eligible managed `codex exec --json` guard run executes at most one Jev shadow evaluation with synthetic, **enumerated** task metadata only. Actual request text, filenames, customer content, code, credentials and sensitive project content are never included in the Jev request. If Jev times out, errors, lacks a key or returns an unexpected shape, the existing deterministic router remains authoritative and the task continues. Security, production, migration, HOTFIX, permissions, budget and deployment gates never delegate authority.

Normal interactive `codex` sessions are **not** intercepted or integrated by this patch.

## Set up on Windows (local machine, no key committed)
Get a **Vercel AI Gateway** API key for `typesafe-ai/jev`. A direct TypeSafe-issued API key is NOT interchangeable with a Vercel Gateway key.

Load an existing key in the **current CLI process environment** using an approved credential mechanism. Example PowerShell entry without writing the plaintext into the command history:

```powershell
$secure = Read-Host "Vercel AI Gateway API key" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $env:AI_GATEWAY_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}
```

Environment variables are inherited by child processes; use a trusted local host. Do not paste keys into ChatGPT, GitHub, `AGENTS.md`, `config.toml`, `.ai/` JSON, terminal transcripts or ordinary commit logs. Re-enter a process-scoped key in a new PowerShell window or use an approved system Secret Store. If API key is invalid or provider access is unavailable, authentication alone is insufficient.

## CLI usage

```powershell
# From a verified, installed and release-pinned Harness root:
node scripts/jev-runtime-v6-2.mjs status --project C:/your/project
# Does NOT call provider; should show READY_NOT_ACTIVATED when key exists.

# Explicit one-time consent for a small LIVE synthetic canary, then saves
# mode=shadow / enabled=true in the existing project config (no key saved):
node scripts/jev-runtime-v6-2.mjs activate --project C:/your/project --live true

# Optional, standalone canary without activating:
node scripts/jev-runtime-v6-2.mjs canary --project C:/your/project --live true

# Disable without live call:
node scripts/jev-runtime-v6-2.mjs disable --project C:/your/project

# After activation, opt-in managed Codex run:
node scripts/harness-guard-v6-2.mjs preflight --project C:/your/project --request "Fix a small UI bug"
node scripts/harness-guard-v6-2.mjs run --project C:/your/project --request "Fix a small UI bug" --soft-limit 80000 --hard-limit 110000
node scripts/harness-guard-v6-2.mjs report --project C:/your/project
```

The preflight report indicates Jev activation status; managed `run` stores a sanitized `jev` block:
`SHADOW_OBSERVED` (including agreement and token usage if exposed), `SKIPPED_BY_POLICY`, `READY_NOT_ACTIVATED`, `MISSING_API_KEY` or `FALLBACK`. It does **not** claim to have changed the runtime Codex model or that Jev governed a decision.

**Activation is one command after API key registration**, not an automatic paid call merely because an environment variable exists. This protects projects sharing the same developer account. Once activated, eligible managed runs call Jev automatically without another prompt.

## Limitations and security
- The platform's published model price / availability / token schema can change. Do not hardcode prices or threshold claims.
- The Vercel Gateway may require a payment method/provider entitlement; a key may authenticate but live Jev may return 403 or unavailable. Activation then stays OFF.
- `shadow` is **measurement only**; it may cost money and cannot demonstrate savings until controlled replay against baseline.
- `liveCanary()` checks reachability, typed schema and authentication with synthetic data; one successful call does not establish probabilistic calibration or privacy law compliance.
- Historical 22/22 provider-mock tests are NOT a real 2026-10-12 provider canary.
- Secrets are never written to project state by this module; provider request is non-sensitive synthetic enum metadata.
- The managed guard currently requires the requested Harness source to be correctly pinned. A candidate branch with `HARNESS_VERSION=6.0.0` is **not** automatically active in projects. Codex must validate, then prepare release 6.2.0 tag/source manifest/index/plugins and migrate projects safely.

## Merge gates
1. `node --test scripts/test-jev-v6-2.mjs`
2. `node scripts/test-jev-scenarios.mjs` (existing 22 offline cases)
3. `node --test scripts/test-harness-guard-v6-2.mjs`
4. `node scripts/validate-harness-v6.mjs` + full Harness release regression
5. Disposable project activation/disable test, no secret in filesystem, verified source pin and actual Jev shadow in managed JSON report.
6. **Explicit live canary with an approved API key** on the user's machine. No CI secret or live calls are required for standard PR checks; if not executed, mark LIVE_PROVIDER=NOT_RUN.
7. Compare actual tokens/cost and error/decision quality against deterministic-only guard run. Do not merge if unresolved regressions.
