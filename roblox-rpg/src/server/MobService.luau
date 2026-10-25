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
