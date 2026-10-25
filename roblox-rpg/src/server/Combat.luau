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
