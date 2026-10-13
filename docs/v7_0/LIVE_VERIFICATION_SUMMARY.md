# AI Harness v7.0.0 — local Studio verification

Decision: **GO for the opt-in Harness capability and starter template**. Original private evidence was reviewed by the user on 2026-10-13. [Release review record](RELEASE_ACCEPTANCE.json) binds this decision to the unchanged Roblox runtime/source files; changed runtime bytes require renewed review.

The test ran on the user's Windows PC with Node 24.19.0, Codex CLI 0.162.1, Roblox Studio 0.742.0.7421053 and Roblox's official Agent Plugin 0.2.1. The official Studio MCP process negotiated protocol 2025-03-26. One explicitly selected, backed-up **unpublished local** starter Place was used. No production game or DataStore was changed.

| Check | Observed result |
|---|---|
| Registry and connection | Single Roblox_Studio registration; actual list_roblox_studios, get_studio_state and search_game_tree responses |
| Source identity | All three starter scripts matched their canonical Rojo source |
| Editing | Temporary server/client scripts created and updated with actual multi_edit; source read-back matched local test files |
| Playtest | Actual start_stop_play start and stop; Client/Server modes observed; return to Edit confirmed |
| Console and visuals | Original server/client boot messages; actual MCP edit/play captures inspected |
| Context separation | Server execution verified; client could not see ServerScriptService scripts; frozen shared settings loaded |
| Multiplayer | ExecuteMultiplayerTestAsync(2, ...) returned two players, two distinct client handshakes and a server-side PASS through EndTest |
| Source reconciliation and rollback | Temporary scripts matched Rojo test source, then only owned fixtures were removed. Complete recorded before/after inventory matched, original script bytes were unchanged and saved Place/backup SHA-256 matched |
| Tools | StyLua 2.5.2, Selene 0.31.0 and Rojo 7.7.0 checks ran successfully; Rokit 1.2.0 executed. Official archives were checked against publisher release asset digests |
| Permissions | The scoped verification driver denied another session, an unknown tool and asset insertion without separate approval before an MCP call |

The source/runtime hash is recorded in RELEASE_ACCEPTANCE.json. Its runtime files are unchanged from tested candidate `596729d054a6ff1a15daef16aa710520de26d972`; release preparation changes version metadata, documentation and publication gates.

## Evidence boundaries

Original transcripts, screenshots, local file paths and private Studio IDs remain on the user's PC. The public record contains no session IDs or credentials. Offline CI and JSON consistency validators do not attest a live connection. The local review used actual official MCP responses and rendered screenshots, followed by user confirmation; no example receipts were promoted to PASS.

This verifies the Harness capability and starter. PROJECT ETERNAL remains a design reference; its economy, capture, persistence, anti-exploit and production DataStore behavior are not implemented or tested. No live Vercel/Jev connectivity, Office rendering quality, model-selection enforcement or universal interactive Codex control is implied. Permissions remain scoped user/agent responsibilities; the temporary audit driver's denials are not a claim that every client is intercepted.

Final publication additionally requires consistent 7.0.0 identity, final-head Windows/Linux CI, a main merge and an immutable tag on that merge commit. See [final release procedure](FINAL_RELEASE_GO_NO_GO.md).
