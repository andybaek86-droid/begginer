-- Roblox Studio 명령 모음(Command Bar)에 전체를 붙여넣고 실행하면 프로토타입 스크립트가 설치된다.
-- 기존 ReplicatedStorage.Shared / ServerScriptService.Server / StarterPlayerScripts.Main 은 교체된다.
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

for _, old in { rs:FindFirstChild("Shared"), sss:FindFirstChild("Server"), sps:FindFirstChild("Main") } do
	old:Destroy()
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function add(parent, name, className, source)
	local s = Instance.new(className)
	s.Name = name
	s.Source = source
	s.Parent = parent
end

local shared = folder(rs, "Shared")
local server = folder(sss, "Server")

add(shared, "Config", "ModuleScript", [==[
-- 밸런스/콘텐츠 수치는 전부 여기서 관리한다 (서버·클라이언트 공용)
local Config = {}

Config.MaxLevel = 50

Config.BaseStats = { MaxHealth = 100, Attack = 10, Defense = 2 }
Config.PerLevel = { MaxHealth = 15, Attack = 2, Defense = 0.5 }

Config.CritChance = 0.1
Config.CritMultiplier = 1.5

-- 레벨 L에서 L+1로 가는 데 필요한 경험치
function Config.XpToNext(level)
	return math.floor(100 * level ^ 1.5)
end

-- 전사 스킬 (키 1~3)
Config.Skills = {
	[1] = { Name = "Slash", Cooldown = 0.8, Range = 9, Multiplier = 1.0, Aoe = false, UnlockLevel = 1 },
	[2] = { Name = "Whirlwind", Cooldown = 5, Range = 12, Multiplier = 0.8, Aoe = true, UnlockLevel = 3 },
	[3] = { Name = "Heavy Strike", Cooldown = 8, Range = 9, Multiplier = 2.5, Aoe = false, UnlockLevel = 5 },
}

Config.Mobs = {
	Slime = {
		Name = "Slime",
		Level = 1,
		MaxHealth = 40,
		Attack = 6,
		Defense = 0,
		Xp = 25,
		Gold = 5,
		Speed = 10,
		AggroRange = 25,
		AttackRange = 5,
		AttackCooldown = 1.5,
		Color = Color3.fromRGB(80, 200, 120),
	},
	Goblin = {
		Name = "Goblin",
		Level = 4,
		MaxHealth = 120,
		Attack = 14,
		Defense = 3,
		Xp = 70,
		Gold = 15,
		Speed = 13,
		AggroRange = 30,
		AttackRange = 5,
		AttackCooldown = 1.2,
		Color = Color3.fromRGB(150, 110, 60),
	},
}

Config.MobLeashRange = 70
Config.MobRespawnTime = 8

Config.SpawnPoints = {
	{ Mob = "Slime", Position = Vector3.new(35, 0, 0) },
	{ Mob = "Slime", Position = Vector3.new(45, 0, 15) },
	{ Mob = "Slime", Position = Vector3.new(40, 0, -15) },
	{ Mob = "Goblin", Position = Vector3.new(-45, 0, 10) },
	{ Mob = "Goblin", Position = Vector3.new(-55, 0, -10) },
}

return Config
]==])

add(shared, "Remotes", "ModuleScript", [==[
-- RemoteEvent를 서버가 생성하고 클라이언트는 대기하는 헬퍼
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "UseSkill", "DamageNumber" }

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

function Remotes.Get(name)
	return folder:WaitForChild(name)
end

return Remotes
]==])

add(server, "PlayerData", "ModuleScript", [==[
-- DataStore 저장/로드. 로드에 실패한 유저는 저장하지 않아 기존 데이터를 덮어쓰지 않는다.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local store = DataStoreService:GetDataStore("PlayerData_v1")

local DEFAULT = { Level = 1, Xp = 0, Gold = 0 }

local PlayerData = {}

local profiles = {}
local canSave = {}

local function withRetry(fn)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("DataStore 실패 (%d/3): %s"):format(attempt, tostring(result)))
		task.wait(attempt)
	end
	return false, nil
end

local function key(player)
	return "Player_" .. player.UserId
end

function PlayerData.Load(player)
	local ok, data = withRetry(function()
		return store:GetAsync(key(player))
	end)

	local profile = table.clone(DEFAULT)
	if ok and type(data) == "table" then
		for k in DEFAULT do
			if type(data[k]) == "number" then
				profile[k] = data[k]
			end
		end
	end

	profiles[player] = profile
	canSave[player] = ok
	return profile
end

function PlayerData.Get(player)
	return profiles[player]
end

function PlayerData.Save(player)
	local profile = profiles[player]
	if not profile or not canSave[player] then
		return
	end
	withRetry(function()
		store:SetAsync(key(player), profile)
	end)
end

function PlayerData.Release(player)
	PlayerData.Save(player)
	profiles[player] = nil
	canSave[player] = nil
end

function PlayerData.StartAutosave(interval)
	task.spawn(function()
		while true do
			task.wait(interval)
			for _, player in Players:GetPlayers() do
				PlayerData.Save(player)
			end
		end
	end)
end

function PlayerData.SaveAll()
	for _, player in Players:GetPlayers() do
		PlayerData.Save(player)
	end
end

return PlayerData
]==])

add(server, "Leveling", "ModuleScript", [==[
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
]==])

add(server, "MobService", "ModuleScript", [==[
-- 몬스터 생성/AI(추적·공격·리쉬)/사망·리스폰. 모든 판정은 서버에서만 한다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MobService = {}

local mobs = {} -- [Model] = mob 테이블
local onKilled

local AI_INTERVAL = 0.25

local function createModel(cfg, position)
	local model = Instance.new("Model")
	model.Name = cfg.Name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 3, 3)
	root.Color = cfg.Color
	root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.MaxHealth = cfg.MaxHealth
	humanoid.Health = cfg.MaxHealth
	humanoid.WalkSpeed = cfg.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.Adornee = root
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	gui.Parent = root

	local function refreshLabel()
		label.Text = ("Lv.%d %s  %d/%d"):format(
			cfg.Level,
			cfg.Name,
			math.max(0, math.ceil(humanoid.Health)),
			cfg.MaxHealth
		)
	end
	humanoid.HealthChanged:Connect(refreshLabel)
	refreshLabel()

	return model, root, humanoid
end

local function spawnMob(spawn)
	local cfg = Config.Mobs[spawn.Mob]
	local model, root, humanoid = createModel(cfg, spawn.Position)
	model.Parent = workspace
	root:SetNetworkOwner(nil) -- 물리/이동을 서버가 소유

	mobs[model] = {
		Model = model,
		Root = root,
		Humanoid = humanoid,
		Cfg = cfg,
		Spawn = spawn,
		SpawnPosition = spawn.Position + Vector3.new(0, 4, 0),
		Target = nil,
		LastAttack = 0,
		Dead = false,
	}
end

local function livingCharacter(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil, nil
end

local function nearestPlayer(position, maxDistance)
	local best, bestDistance = nil, maxDistance
	for _, player in Players:GetPlayers() do
		local _, root = livingCharacter(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function stepMob(mob, now)
	local cfg, root, humanoid = mob.Cfg, mob.Root, mob.Humanoid

	-- 타겟 유효성 / 리쉬 검사
	if mob.Target then
		local _, targetRoot = livingCharacter(mob.Target)
		if not targetRoot or (root.Position - mob.SpawnPosition).Magnitude > Config.MobLeashRange then
			mob.Target = nil
		end
	end
	if not mob.Target then
		mob.Target = nearestPlayer(root.Position, cfg.AggroRange)
	end

	if not mob.Target then
		-- 복귀 후 회복
		if (root.Position - mob.SpawnPosition).Magnitude > 4 then
			humanoid:MoveTo(mob.SpawnPosition)
		elseif humanoid.Health < cfg.MaxHealth then
			humanoid.Health = math.min(cfg.MaxHealth, humanoid.Health + cfg.MaxHealth * 0.1)
		end
		return
	end

	local targetHumanoid, targetRoot = livingCharacter(mob.Target)
	local distance = (targetRoot.Position - root.Position).Magnitude
	if distance > cfg.AttackRange then
		humanoid:MoveTo(targetRoot.Position)
	else
		humanoid:MoveTo(root.Position)
		if now - mob.LastAttack >= cfg.AttackCooldown then
			mob.LastAttack = now
			local defense = mob.Target:GetAttribute("Defense") or 0
			targetHumanoid:TakeDamage(math.max(1, math.floor(cfg.Attack - defense)))
		end
	end
end

function MobService.Init(killedCallback)
	onKilled = killedCallback
	for _, spawn in Config.SpawnPoints do
		spawnMob(spawn)
	end

	task.spawn(function()
		while true do
			local now = os.clock()
			for _, mob in mobs do
				if not mob.Dead then
					stepMob(mob, now)
				end
			end
			task.wait(AI_INTERVAL)
		end
	end)
end

-- 반경 내 살아있는 몬스터 목록 (가까운 순)
function MobService.GetMobsInRange(position, range)
	local result = {}
	for _, mob in mobs do
		if not mob.Dead then
			local distance = (mob.Root.Position - position).Magnitude
			if distance <= range then
				table.insert(result, { Mob = mob, Distance = distance })
			end
		end
	end
	table.sort(result, function(a, b)
		return a.Distance < b.Distance
	end)
	return result
end

function MobService.Damage(mob, amount, attacker)
	if mob.Dead then
		return
	end
	mob.Target = attacker -- 맞은 대상을 어그로로 설정
	mob.Humanoid.Health = math.max(0, mob.Humanoid.Health - amount)

	if mob.Humanoid.Health <= 0 then
		mob.Dead = true
		if onKilled then
			onKilled(mob.Cfg, attacker)
		end
		task.delay(0.5, function()
			mobs[mob.Model] = nil
			mob.Model:Destroy()
		end)
		task.delay(Config.MobRespawnTime, function()
			spawnMob(mob.Spawn)
		end)
	end
end

return MobService
]==])

add(server, "Combat", "ModuleScript", [==[
-- 스킬 사용 요청 검증(쿨다운/레벨/생존) 및 데미지 계산. 클라이언트는 skillId만 보낸다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MobService = require(script.Parent.MobService)

local Combat = {}

local LATENCY_TOLERANCE = 0.1
local cooldowns = {} -- [player] = { [skillId] = 사용 가능 시각 }

local function rollDamage(attack, multiplier, defense)
	local isCrit = math.random() < Config.CritChance
	local damage = attack * multiplier * (0.9 + math.random() * 0.2) - defense
	if isCrit then
		damage *= Config.CritMultiplier
	end
	return math.max(1, math.floor(damage)), isCrit
end

local function handleUseSkill(player, skillId)
	if type(skillId) ~= "number" then
		return
	end
	local skill = Config.Skills[skillId]
	if not skill then
		return
	end
	if (player:GetAttribute("Level") or 1) < skill.UnlockLevel then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local playerCooldowns = cooldowns[player]
	if not playerCooldowns then
		return
	end
	local readyAt = playerCooldowns[skillId]
	if readyAt and now < readyAt - LATENCY_TOLERANCE then
		return
	end

	local targets = MobService.GetMobsInRange(root.Position, skill.Range)
	if #targets == 0 then
		return
	end
	if not skill.Aoe then
		targets = { targets[1] }
	end

	playerCooldowns[skillId] = now + skill.Cooldown

	-- 첫 대상 방향으로 회전
	local firstPosition = targets[1].Mob.Root.Position
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(firstPosition.X, root.Position.Y, firstPosition.Z))

	local attack = player:GetAttribute("Attack") or Config.BaseStats.Attack
	local damageRemote = Remotes.Get("DamageNumber")
	for _, entry in targets do
		local mob = entry.Mob
		local damage, isCrit = rollDamage(attack, skill.Multiplier, mob.Cfg.Defense)
		local position = mob.Root.Position
		MobService.Damage(mob, damage, player)
		damageRemote:FireClient(player, position, damage, isCrit)
	end
end

function Combat.Init()
	Players.PlayerAdded:Connect(function(player)
		cooldowns[player] = {}
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		cooldowns[player] = {}
	end

	Remotes.Get("UseSkill").OnServerEvent:Connect(handleUseSkill)
end

return Combat
]==])

add(server, "Main", "Script", [==[
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
]==])

add(sps, "Main", "LocalScript", [==[
-- HUD(레벨/경험치/골드), 스킬 버튼(키 1~3), 데미지 숫자
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local useSkill = Remotes.Get("UseSkill")
local damageNumber = Remotes.Get("DamageNumber")

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- 경험치 바
local xpBack = Instance.new("Frame")
xpBack.AnchorPoint = Vector2.new(0.5, 1)
xpBack.Position = UDim2.new(0.5, 0, 1, -12)
xpBack.Size = UDim2.fromOffset(420, 22)
xpBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
xpBack.BorderSizePixel = 0
xpBack.Parent = gui

local xpFill = Instance.new("Frame")
xpFill.BackgroundColor3 = Color3.fromRGB(110, 90, 255)
xpFill.BorderSizePixel = 0
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.Parent = xpBack

local xpLabel = Instance.new("TextLabel")
xpLabel.BackgroundTransparency = 1
xpLabel.Size = UDim2.fromScale(1, 1)
xpLabel.TextColor3 = Color3.new(1, 1, 1)
xpLabel.TextScaled = true
xpLabel.Font = Enum.Font.GothamBold
xpLabel.Parent = xpBack

-- 스킬 버튼
local buttons = {}
local readyAt = {}

local function level()
	return player:GetAttribute("Level") or 1
end

local function trigger(skillId)
	local skill = Config.Skills[skillId]
	if not skill or level() < skill.UnlockLevel then
		return
	end
	if os.clock() < (readyAt[skillId] or 0) then
		return
	end
	readyAt[skillId] = os.clock() + skill.Cooldown
	useSkill:FireServer(skillId)
end

for skillId, skill in Config.Skills do
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, (skillId - 2) * 76, 1, -44)
	button.Size = UDim2.fromOffset(68, 68)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.AutoButtonColor = false
	button.Parent = gui

	local cover = Instance.new("Frame")
	cover.AnchorPoint = Vector2.new(0, 1)
	cover.Position = UDim2.fromScale(0, 1)
	cover.Size = UDim2.fromScale(1, 0)
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BackgroundTransparency = 0.5
	cover.BorderSizePixel = 0
	cover.Parent = button

	button.Activated:Connect(function()
		trigger(skillId)
	end)
	buttons[skillId] = { Button = button, Cover = cover }
end

local function refreshHud()
	local lv = level()
	local xp = player:GetAttribute("Xp") or 0
	local needed = player:GetAttribute("XpNeeded") or 1
	xpFill.Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1)
	xpLabel.Text = ("Lv.%d   XP %d/%d   Gold %d"):format(lv, xp, needed, player:GetAttribute("Gold") or 0)

	for skillId, skill in Config.Skills do
		local locked = lv < skill.UnlockLevel
		buttons[skillId].Button.Text = locked and ("Lv.%d\n해금"):format(skill.UnlockLevel)
			or ("[%d]\n%s"):format(skillId, skill.Name)
		buttons[skillId].Button.BackgroundColor3 = locked and Color3.fromRGB(25, 25, 25) or Color3.fromRGB(45, 45, 60)
	end
end

for _, attribute in { "Level", "Xp", "XpNeeded", "Gold" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshHud)
end
refreshHud()

-- 쿨다운 표시
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for skillId, skill in Config.Skills do
		local remaining = math.max(0, (readyAt[skillId] or 0) - now)
		buttons[skillId].Cover.Size = UDim2.fromScale(1, remaining / skill.Cooldown)
	end
end)

-- 키 입력
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index then
		trigger(index)
	end
end)

-- 데미지 숫자
damageNumber.OnClientEvent:Connect(function(position, amount, isCrit)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = isCrit and (tostring(amount) .. "!") or tostring(amount)
	label.TextColor3 = isCrit and Color3.fromRGB(255, 210, 60) or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	local info = TweenInfo.new(0.8)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.9)
end)
]==])

print("RPG 프로토타입 설치 완료! Play(F5)를 눌러 테스트하세요.")
