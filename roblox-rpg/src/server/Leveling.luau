-- 경험치/레벨/스탯. 클라이언트 표시용 값은 Player Attribute로 복제한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Leveling = {}

local function syncAttributes(player)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Xp", profile.Xp)
	player:SetAttribute("XpNeeded", Config.XpToNext(profile.Level))
	player:SetAttribute("Gold", profile.Gold)
end

function Leveling.ApplyStats(player, healFull)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end
	local extra = profile.Level - 1
	local maxHealth = Config.BaseStats.MaxHealth + Config.PerLevel.MaxHealth * extra
	player:SetAttribute("Attack", Config.BaseStats.Attack + Config.PerLevel.Attack * extra)
	player:SetAttribute("Defense", Config.BaseStats.Defense + Config.PerLevel.Defense * extra)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = maxHealth
		if healFull then
			humanoid.Health = maxHealth
		end
	end
end

function Leveling.Setup(player)
	syncAttributes(player)
	Leveling.ApplyStats(player, true)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		Leveling.ApplyStats(player, true)
	end)
end

function Leveling.AddXp(player, amount)
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end

	local leveled = false
	profile.Xp += amount
	while profile.Level < Config.MaxLevel and profile.Xp >= Config.XpToNext(profile.Level) do
		profile.Xp -= Config.XpToNext(profile.Level)
		profile.Level += 1
		leveled = true
	end
	if profile.Level >= Config.MaxLevel then
		profile.Xp = 0
	end

	syncAttributes(player)
	if leveled then
		Leveling.ApplyStats(player, true)
	end
end

function Leveling.AddGold(player, amount)
	local profile = PlayerData.Get(player)
	if profile then
		profile.Gold += amount
		syncAttributes(player)
	end
end

return Leveling
