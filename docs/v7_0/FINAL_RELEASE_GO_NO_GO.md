# AI Harness v7.0 — Final Go / No-Go & Release Handoff

Status: **NO_GO — actual Roblox Studio execution not attested**.
Branch: `upgrade/v7.0` · PR: https://github.com/hacker943410-debug/ai-harness/pull/4
Stable release: `v6.2.0`.

## What is code-reviewed/CI-testable
- Official plugin provenance from Roblox Corporation, runtime discovery design.
- Non-mutating Codex MCP registration Doctor; no claim that registration proves connectivity.
- Scaffolding on explicit opt-in, local Rojo manifest/path/symlink checks.
- Luau build/lint wrapper with explicit tool invocation and NOT_RUN on absent tools.
- Studio read-only evidence consistency and expanded live-operator evidence consistency with **untrusted** receipt labeling.
- Tests for malformed, stale, contradictory and incomplete Studio evidence.
- Core Harness 26 policies, token/Jev guards, managed-source snapshot behavior preserved through v6 regression.
- Full Linux and Windows GitHub Actions must be checked on **the latest head SHA**, not older runs.

## Blocking evidence still required on user workstation
1. First-party plugin installed and Studio MCP setting enabled; actual `list_roblox_studios`, `get_studio_state`, `search_game_tree` transcript inspected.
2. Unique, user-confirmed `studio_id` and disposable **private test** Place selected.
3. Prior recoverable Place backup and Git source checkpoint.
4. A small authorized `multi_edit` (or equivalent discovered tool schema) with observed game object change.
5. Playtest start+stop with console evidence, plus screen capture and reviewer observation.
6. No live game / production datastore mutation, saved source reconciliation and full restoration evidence.
7. At least two connected clients or StudioTestService multiplayer run showing server/client separation.
8. Actual `rokit`/Rojo/StyLua/Selene tool execution in target environment (if not available, remain NOT_RUN).
9. Approval from the user to complete release with any residual risks explicitly acknowledged.

The tool `scripts/roblox/verify-live-evidence.mjs` only checks local JSON **consistency**. Its successful result is **exit code 3** and is not an automated claim of genuine MCP execution. Original MCP transcript, Studio screenshot and Source/Place revision must be independently reviewed and kept outside public repo.

## When ALL above are fulfilled — exact next steps
1. Inspect PR #4 diff and provenance. Ensure all branch checks PASS on the final SHA.
2. Bump `HARNESS_VERSION`, `harness/manifest.yaml` version/source_ref, `POLICY_INDEX.yaml`, Claude plugin/marketplace, README and change notes consistently to `7.0.0` in a **single release-preparation commit**.
3. Migrate Roblox candidate manifest entry from candidate designation to stable **only after** the live integration is proven. Keep it opt-in; never auto-install MCP nor auto-publish a game.
4. Re-run all v7 and v6.2 regression checks (Windows/Linux plus Windows PowerShell) on the exact new SHA.
5. Mark PR #4 ready, merge into `main` with an expected head SHA guard only after passing latest checks and final authorization.
6. Tag the **resulting main merge commit** `v7.0.0` as immutable and create GitHub Release notes accurately separating automated CI, witnessed Studio, and user-approved scopes. Confirm tag target and version match.
7. Update each actual game project separately via Harness migration plan → source hash checkpoint → verification → safe resume; preserve prior v6.2 snapshots.

## Do NOT
- Mark all verifications PASS because GitHub CI is green.
- Copy fabricated `studio_id`, test receipts or screenshots from example documentation into a report.
- Merge, tag or update production projects while R05–R14 in VERIFICATION_MATRIX.md remain NOT_RUN.
- Ship with inconsistent source pin/hash or move the existing v6.2.0 tag.
- Claim token savings or semantic policy adherence based only on fake-agent/offline tests.

For step-by-step setup see [INSTALLATION_AND_OPERATIONS.md](INSTALLATION_AND_OPERATIONS.md) and [VERIFICATION_MATRIX.md](VERIFICATION_MATRIX.md).
