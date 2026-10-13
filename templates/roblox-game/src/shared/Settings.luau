--!strict
-- All game progression must be verified on the server.
local Settings = {
    GAME_NAME = "RobloxHarnessStarter",
    OFFLINE_INCOME_CAP_SECONDS = 8 * 60 * 60,
    HIDEOUT_STEALING_ENABLED = false,
}
return table.freeze(Settings)
