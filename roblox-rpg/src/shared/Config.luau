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
