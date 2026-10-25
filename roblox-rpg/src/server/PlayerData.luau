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
