# Roblox Harness Starter (sample template)

This folder is an **original minimal Rojo scaffold**, not a fully playable game.
It is intentionally free of Roblox credentials, paid assets and production code.

- Run `rokit install` only after reviewing pinned tool versions.
- Run `rojo plugin install` to install the matching Rojo Studio plugin, then `rojo serve`.
- Use the official Roblox Studio Agent Plugin for Codex MCP connectivity.
- Keep `.luau` source in Git as canonical. Inspect and reconcile direct Studio MCP script mutations before syncing.
- `ServerScriptService` controls economy, combat, capture, save, inventory and awards; clients send requests, never authoritative amounts.
- Use dedicated *test* DataStore IDs/universes before persistent state or monetization.
- The initial project prints boot messages only. No combat, capture, datastore, asset or UI engine is generated.
