--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))
print("[Harness Roblox] server boot:", Settings.GAME_NAME)
-- Implementation deliberately omitted. Client-reported damage, gold, drops and
-- capture success MUST NOT be trusted. Add dedicated server-owned services.
