# AI Harness v7.0.0 — Roblox Studio MCP Setup and Operations

> Status: **7.0.0 identity prepared; local Studio E2E and user review completed**. See [live verification summary](LIVE_VERIFICATION_SUMMARY.md). Each consuming project still needs its own scoped setup and validation.
> No automatic installation, Roblox publishing, paid API calls, model-based asset upload or changes to existing production projects.

## Scope
AI Harness v7 introduces a **Roblox opt-in Capability Pack**; the original 26 policy files, v6.2 guards and existing project bindings remain in place. Roblox-specific instructions and source templates are loaded only for Roblox jobs.

**Official components, do not duplicate or re-author as "Roblox official":**
- Studio built-in MCP docs: https://create.roblox.com/docs/studio/mcp
- Roblox's first-party Codex/Claude Agent Plugin: https://github.com/Roblox/roblox-studio-agent-plugin
- Rojo, Rokit: https://rojo.space/docs/v7/getting-started/installation/
- Roblox external tools: https://create.roblox.com/docs/projects/external-tools

## Step 1 — Windows prerequisites (safe / diagnostic)
- Roblox Studio installed locally on Windows or macOS, logged in, with an **unpublished test place** saved in advance.
- Codex CLI installed and logged in; Git and Node.js 22+ available.
- Run these **read-only** commands from AI Harness checkout:
```powershell
codex --version
codex mcp list --json
node scripts/roblox/doctor.mjs --project C:/dev/roblox-test-project
```
The doctor does NOT call Roblox Studio. `REGISTERED_UNVERIFIED` means the client entry exists, NOT that Studio is connected. A missing `mcp.bat` path on non-Windows hosts is diagnostic, not a reason to download random MCP binaries.

## Step 2 — Connect using the Roblox-official Plugin (manual user-approved)
```powershell
codex plugin marketplace add Roblox/roblox-studio-agent-plugin
```
Then run `codex`, open `/plugins`, install **Roblox Studio**, and open a new thread (`/new`). On a Korean Studio UI, open the top-right **AI 어시스턴트** icon, then **어시스턴트 → … → 설정 → MCP 서버**. The user enables the Studio MCP server and Quick Connect for Codex in this pane. Confirm the connected indicator. Labels vary by build; use the current official Creator Hub instructions. The user signs in and turns on the MCP setting; never read passwords or edit Studio settings files.

When adding the Windows client manually after checking for duplicates, preserve the standalone `'--'` argument and launch the official batch file from its own directory:
```powershell
codex mcp add Roblox_Studio '--' cmd.exe /c 'cd /d %LOCALAPPDATA%\Roblox && .\mcp.bat'
```

In Codex ask: **"List my open Roblox Studio windows using the official MCP tool. Show studio_id and place name; do not change anything."**

Check Studio MCP at runtime for the exact names and argument schema. For two or more Studio windows, ask the user to select the target `studio_id` **before any write**. Never silently use the most recently opened place. Select the actual test place; a production place must not be a mutation target.

## Step 3 — First live read-only proof
The agent should invoke these actual MCP tools in this order, adapting exact arguments to schema:
1. `list_roblox_studios`: discover Studio sessions and their IDs
2. `get_studio_state` using the chosen `studio_id`
3. `search_game_tree` using the **same** `studio_id`
4. Optionally `screen_capture`, `get_console_output`

The agent can save a concise **local, private** JSON report for cross-checking tool names and session IDs:
```json
{"schema_version":1,"observed_at":"2026-10-12T07:00:00Z","studio_id":"actual-session-id","session_count":1,"confirmed_selection":true,"discovered_studios":[{"studio_id":"actual-session-id"}],"calls":[{"tool":"list_roblox_studios","studio_id":"actual-session-id","success":true,"receipt_id":"actual-result-ref"},{"tool":"get_studio_state","studio_id":"actual-session-id","success":true,"receipt_id":"actual-result-ref"},{"tool":"search_game_tree","studio_id":"actual-session-id","success":true,"receipt_id":"actual-result-ref"}]}
```
The sample IDs/time above are EXAMPLES, not proof. Do not fabricate values.
```powershell
node scripts/roblox/verify-session.mjs --evidence C:/private/studio-readonly-proof.json
```
Status `EVIDENCE_STRUCTURALLY_VALID` means **agent-submitted consistency only**, not a cryptographically verified MCP call. We cannot independently certify a Studio connection in GitHub-hosted CI. Actual tool transcripts and Studio visual indicator are separate human-observed evidence.

## Step 4 — Create a Rojo-based local project
From the AI Harness repository (preview is read-only):
```powershell
node scripts/roblox/scaffold.mjs --out C:/dev/new-roblox-game
```
To actually create the new empty folder after reviewing the destination:
```powershell
node scripts/roblox/scaffold.mjs --out C:/dev/new-roblox-game --create
```
The generated starter includes a Rojo project mapping, pinned `rokit.toml`, StyLua/Selene config and 3 basic Luau bootstrap files. **It does not include a functioning MMORPG, PlayerDataService, auto-hunt, Roblox assets or DataStore integrations.** It does not download packages, add Roblox Studio objects or publish anything.

Check local inputs without contacting Studio:
```powershell
node scripts/roblox/verify-project.mjs --project C:/dev/new-roblox-game
```
After reviewing tool package versions and installing trusted tools from their official sources:
```powershell
# In the game project folder, after explicit approval and checking pinned versions:
# rokit install
# rojo plugin install
# rojo serve
```
To run only **local** lint/formatter and temporary `rojo build`:
```powershell
node scripts/roblox/verify-project.mjs --project C:/dev/new-roblox-game --run-tools
```
`PASS_LOCAL_TOOLS_ONLY` does NOT imply a successful Studio playtest or multiplayer test. CI does not install Roblox Studio or depend on Studio desktop graphics.

## Step 5 — Game development rules
- **Canonical Lua source:** Rojo-managed `.luau` files under Git. Studio direct `multi_edit` requires source reconciliation to avoid being overwritten at next sync.
- **Studio data:** scene/terrain/camera/rig assets are tracked by versions and references; do not embed private tokens.
- **Security:** authoritative server owns combat damage, drop rolls, rare capture outcome, inventory, enhancement, hideout gold production, offline income, DataStore and receipt idempotency.
- **Verification:** local Luau tests + static checks + REAL Studio Playtest + console evidence + screen capture when UI involved + multi-client test + saved profile/reconnect evidence.
- **Privacy:** Studio MCP tool results (scripts, screenshots, console) are visible to the assistant provider; never use confidential production data without review.
- **Mutation authority:** any `execute_luau`, `multi_edit`, insertion, generated assets or playtest control needs appropriate approval and a saved place version first. Roblox publish, purchases, public release and live DataStore writes require separate explicit user approval.

## MVP validation profile
Use `docs/v7_0/PROJECT_ETERNAL_REQUIREMENTS.md` only in PROJECT ETERNAL.
- No stealing/raiding other users' hideouts.
- At most **28,800 seconds** offline gold revenue.
- Combat→loot→rare monster capture→hideout placement→passive gold→equipment upgrade.
- Validate duplicate gold claims, forged RemoteEvents, session locking and reconnect recovery against a controlled test universe.

## v7.0 release gates
1. `node --test scripts/roblox/test-v7.mjs`; `node scripts/validate-roblox-v7.mjs`.
2. v6.2 regressions (Node, PowerShell, immutable source).
3. Windows host with actual official Roblox plugin + live Studio connection and session selection.
4. Safe temporary object creation and rollback in a **test place**, not automatic production editing.
5. Real `start_stop_play`, `get_console_output`, screenshot plus mobile/multi-client coverage for relevant work.
6. Verify tool pins/versions and Rojo source reconciliation; no surprise installation.
7. Explicit release metadata and original-evidence review, exact-final-head CI, then approved main merge and immutable tag creation. See [release acceptance](RELEASE_ACCEPTANCE.json). Consumer binding migrations remain per-project.

No change in tooling is considered "already installed" merely because a catalog lists it.
