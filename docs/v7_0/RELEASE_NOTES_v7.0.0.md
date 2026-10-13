# AI Harness v7.0.0

AI Harness 7.0 adds an opt-in Roblox Studio capability and consolidates the six existing branch histories while preserving the 26 policies, JIT routing, project lifecycle, immutable snapshots, safe migrations, rollback and v6.2 guards.

## Changes

- Reference Roblox's first-party Studio Agent Plugin and discover its actual MCP tools at runtime. Registering a server remains separate from connecting to a Studio session.
- Add a read-only Doctor, explicit session evidence checks, safe Rojo scaffolding, pinned local lint/build checks and project-specific reference requirements.
- Preserve each native Skill installation's paths, hashes and file manifest across separate-client updates. Different installed versions retain their own hashes. Shared Codex/AGY destinations are deduplicated, and existing Force protection, staged installation and rollback remain in place.
- Migrate existing Skill locks without certifying unverified files. Detect modified, missing, duplicate and contradictory installation records.
- Synchronize Harness, source pin, policy index and Claude plugin/marketplace identity to 7.0.0. Release automation requires Windows/Linux verification, the reviewed acceptance record and immutable tagging of the main merge commit.
- Support current 7.x project repair/update and stop planning before writes when an explicit requested Harness version differs from the selected source.

## Verification

Windows/Ubuntu Node 22 CI exercises core, guard, installed-project, Jev offline, Codex compatibility and Roblox regression. PowerShell 7 installation tests run on both platforms, with native Windows PowerShell 5.1 and installer/rollback checks on Windows. Pinned StyLua, Selene and Rojo checks execute on both CI platforms.

On the user's Windows PC, the official Studio MCP performed actual session discovery, tree/source reads, temporary edits, play start/stop, console output and screenshots. A real StudioTestService run observed two players and two distinct client handshakes. Temporary changes were removed; the recorded original inventory, source bytes and saved Place backup matched. The user confirmed review of the original private evidence. See [live verification summary](LIVE_VERIFICATION_SUMMARY.md).

JSON validators and offline fixtures remain explicitly separate from genuine live evidence. Original private sessions and screenshots are not included in the release.

## Updating

Use the existing installer with the immutable `v7.0.0` ref, then request a project-specific Harness update. Existing project bindings and v6.2.0 snapshots remain pinned until a reviewed migration is applied. Major updates stage a separate source candidate and preserve active work, unmanaged instructions and product files. Keep a checkpoint and verify each consuming project before resuming.

## Scope and known limits

Roblox is opt-in. Installation, mutation, publishing and production data access require their relevant user scope. PROJECT ETERNAL is a design reference; game systems and production DataStore integrity are not shipped or certified. Jev stays disabled by default; its live paid provider, Office rendering quality and plain interactive Codex enforcement remain separately unverified. The existing markitdown 0.0.1a4 prerelease-pin warning is retained.

The existing v6.2.0 release is immutable. The v7.0.0 tag identifies the verified main merge commit.
