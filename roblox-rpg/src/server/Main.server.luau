local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Leveling = require(script.Parent.Leveling)
local MobService = require(script.Parent.MobService)
local Combat = require(script.Parent.Combat)

local function onPlayerAdded(player)
	PlayerData.Load(player)
	Leveling.Setup(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
end)

game:BindToClose(function()
	PlayerData.SaveAll()
end)

PlayerData.StartAutosave(60)

Combat.Init()
MobService.Init(function(mobConfig, killer)
	if killer and killer.Parent == Players then
		Leveling.AddXp(killer, mobConfig.Xp)
		Leveling.AddGold(killer, mobConfig.Gold)
	end
end)
