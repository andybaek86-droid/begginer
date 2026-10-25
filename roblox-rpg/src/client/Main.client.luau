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
