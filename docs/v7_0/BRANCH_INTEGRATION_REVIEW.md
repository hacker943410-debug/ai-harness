# v7.0 branch integration review — 2026-10-13

Release decision: **NO_GO pending real Studio verification**. This review prepares the existing draft PR #4; it does not publish v7.0.0 or attest a live Studio session. The user has requested publication after all required checks pass.

## Branch inputs

| Branch | Observed head | Integration |
|---|---|---|
| main | fffae28e3b3381af3eb541e3a05193e6379a9530 | Already the v7 candidate base; published v6.2.0 |
| upgrade/v6.1 | fbcc7fe26d0fc53374d668d2c6cc5aea52f58343 | Already an ancestor of v7 |
| upgrade/v6.2 | 4bdbc977947355634e367a8f127bac286fac3d64 | Already an ancestor of v7 |
| upgrade/v7.0 | 7ccb7bda55bb5d1a95c1f21be692555f4f3a65a4 | Integration target |
| release/v5.0.0 | 65d2bb1246d3779ac724e57ab3f75f6e2675d127 | Separate ancestry merge; current implementations retained |
| fix/v5.0.1-skill-install-integrity | bb03b61dc949858a5230e53485b34d76a39b61d9 | Merge with deliberate conflict reconciliation |

The older v5 release changes are already represented by the later source. Its dashboard Skill content, Claude wrapper, client descriptor schema, AGY and Claude descriptors match the current source exactly. The newer Codex path, installer, doctor, routing and metadata supersede the older versions. A separate `ours` strategy merge retains that diverged release history without reverting the verified current implementations. The integrity-fix branch is merged separately with its missing behavior ported. No remote branch is deleted. PR #2 remains pending until its commits actually reach main.

## Conflict resolution

- Keep the current staged, atomic Skill installer, modified-file protection, safe path checks and rollback. Port separate-client path preservation into that implementation.
- Store integrity metadata per installation. Preserve untargeted recorded hashes, deduplicate the shared Codex/AGY destination and omit the aggregate full-bundle hash when versions differ.
- Retain the current v6 full-manifest hash serialization. The older v5 helper used a different serialization with the same algorithm label; it is superseded rather than installed alongside the current helper.
- Migrate existing full-manifest and SKILL.md-only locks from recorded metadata. Unknown legacy integrity remains informational until reinstallation; migration never certifies current files by recomputing and blessing their hashes.
- Preserve project/machine/client capability scopes and the existing schema requirement for complete full-manifest metadata. Validate path summaries, duplicate paths, every installed path and aggregate manifests.
- Adapt the old branch's regression scenarios to the current shared native paths, Force protection and hash contract. Add PowerShell 7 checks on Ubuntu/Windows and native PowerShell 5.1 on Windows.
- Keep all 26 policy files and the published v6.2.0 tag unchanged. Keep the Roblox capability opt-in and the live release gates in effect.

## Observed local checks

- Existing v7/v6/guard/Jev/Codex tests: 67 tests passed on Windows, Node 24.19.0 before integration. Repeat against the completed candidate and check GitHub Node 22 jobs at the final head.
- Separate-client regression reproduced the missing-path defect before the fix. After the fix, 27 assertions passed on native Windows PowerShell 5.1.
- Current installer/bootstrap release regression: 29/29 passed, including rollback and junction protection; zero external AI calls.
- Official tool release archives were fetched from their publishers and verified against GitHub SHA-256 asset digests. Rokit 1.2.0, Rojo 7.7.0, StyLua 2.5.2 and Selene 0.31.0 executed on this Windows host.
- The starter template passed actual StyLua check, Selene lint and Rojo build. Result: `PASS_LOCAL_TOOLS_ONLY`, with Studio playtest and data integrity explicitly `NOT_RUN`.
- The local Doctor found no registered Roblox_Studio MCP and no MCP launcher. No Studio process, selected session or live tool schema was observed.

## Remaining release work

1. Confirm every final-head Windows/Ubuntu CI job passes, including actual pinned template lint/build and migrated installation regression.
2. Complete R05–R12 and R14 in [VERIFICATION_MATRIX.md](VERIFICATION_MATRIX.md) on a backed-up, scoped private test Place: official MCP connection, read/edit/play/console/screenshots, source reconciliation, rollback, multiple clients and permission boundaries. Original private evidence stays outside the public repository.
3. After those gates pass, prepare a single consistent 7.0.0 identity commit and adapt the release workflow; rerun final-head checks and merge PR #4 into main.
4. Create the immutable v7.0.0 tag on the resulting main merge commit, publish accurate release notes and verify installer/snapshot identity. Do not move v6.2.0 or silently update active consumer projects.
