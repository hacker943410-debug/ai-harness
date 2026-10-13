# Roblox Capability Pack — v7.0 Architecture

## Preservation contract
AI Harness v7.0.0 preserves the existing 26 policies and workflows and adds one opt-in domain extension. The previous v6.2.0 release remains immutable. Source hash, project state, snapshots, rollback, Codex budget and Jev Shadow stay independent. Prevent all accidental implicit document/tool loading. Actual local Studio verification and release review are recorded separately in `LIVE_VERIFICATION_SUMMARY.md` and `RELEASE_ACCEPTANCE.json`.

## Layers and ownership
| Layer | Authoritative source | Guard |
|---|---|---|
| Codex CLI agent | existing Harness rules, v6.2 work guards | no claim of always-on interactive enforcement |
| Official Roblox Studio Plugin | Roblox/roblox-studio-agent-plugin | use official first-party skill, no duplication |
| Studio MCP | user-local Studio MCP stdio server | runtime tool-schema discovery, explicit studio_id |
| Source | Rojo-managed files in Git | no silent Studio-script divergence |
| Scene and assets | saved Studio place + version/asset registry | backups and explicit changes |
| Static verification | StyLua, Selene, Rojo, Lune | unavailable/NOT_RUN != PASS |
| Live verification | Studio Playtest, console, screenshots, multiplayer | requires real workstation |
| Publication | Roblox approvals, Open Cloud if appropriate | user approval and explicit stage gate |

## Developer task router categories
`connect`: environment detection → official plugin → enumerate Studio sessions.
`code`: determine authoritative module → edit `.luau` → lint/format/build.
`world`: backup place → Studio instance edit with approval → visual and performance checks.
`ui`: responsive ScreenGui/layout → PC/mobile screenshot.
`combat`: server damage and anti-exploit tests.
`economy`: server-only gold/drops/capture, profile locks and transaction idempotency.
`data`: test universe and DataStore failure scenarios.
`release`: explicit publish authorization after separate review.

## Evidence and permissions
Every status result must distinguish `NOT_RUN`, `FAIL`, `PASS_STATIC_ONLY`, `PASS_LOCAL_TOOLS_ONLY` and `LIVE_STUDIO_VERIFIED`. No helper implemented here returns LIVE_STUDIO_VERIFIED: the real Studio connection needs a trusted client and independent verification. The evidence JSON verifier only checks internal consistency and labels its output UNATTESTED.

Tool policy classifies known read-only vs mutation-oriented Studio methods; deny unknown write methods until their signatures are reviewed. A Studio read-only MCP probe should not accidentally call `execute_luau`. Snapshot/back up before writes.

## 12 specialized domains
Connect; Luau engineering; client/server authority; world construction; character assets;
animations/VFX; HUD/shop/inventory; combat/AI; persistence; economy/capture; playtest QA; publishing.
These are Capability *areas*, not 12 independently invented Roblox official Skills. On demand fetch the officially provided `skill` documentation.

## Isolation
Do not pass PROJECT ETERNAL's specific game rules into unrelated Roblox projects.
Do not automatically install external packages or request permissions on every CLI startup.
Keep the v6 original release usable and migrate existing projects only after v7 tag validation.
