# PROJECT ETERNAL — Roblox MVP domain profile (reference only)

This is a **project-specific example**, not a globally activated Harness policy. Requirements originate from the user's Roblox MMORPG planning conversations; v7 should route to this file only for PROJECT ETERNAL.

## Locked design
- 3D third-person MMORPG; manual and automatic monster hunting
- Unique original meme/brainrot-inspired monsters — **no unauthorized copying** of existing game assets
- Very low chance of capturing a hunted monster as a collectible
- Place owned collectible monsters in a personal hideout; each produces gold over time
- **Stealing or raiding other users' hideouts is prohibited**
- Offline hideout income is capped at **8 hours = 28,800 seconds**
- Weapon/armor enhancement using scrolls and success/failure rules to be specified, with every result and gold balance owned by the server.

## Primary implementation modules
PlayerDataService; MonsterService; CombatService; AutoHuntService; LootService; CaptureService;
InventoryService; EnhancementService; HideoutService; EconomyService; AntiExploitService.

## Red-gate tests
1. After 12 hours offline, credit at most 28,800 seconds of each eligible generator.
2. Two simultaneous claims against the same checkpoint must not double-credit.
3. Other users cannot modify or collect from another owner's hideout.
4. Client-provided capture successes, damage, gold amounts, item IDs or rates are ignored/rejected.
5. Save/reconnect retains player-owned monster UIDs and placements.
6. Session locks/failed DataStore writes preserve recoverability; publish only after manual approval.
7. Actual mobile view and a live two-player session are required before calling multiplayer COMPLETE.

## Art and economy safeguards
3D art direction, avatar rigs, topology budgets, UI scaling and licensing must be reviewed.
No Robux-paid random item mechanic without Roblox policy, odds disclosure and region restrictions review.
