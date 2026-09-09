local DailyRewardSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local dailyRewardFolder = events.DailyRewards

local claimRewardEvent = dailyRewardFolder.ClaimReward
local updateUIEvent = dailyRewardFolder.UpdateUI
local requestUpdateEvent = dailyRewardFolder.RequestUpdate

local REWARDS = {
	[1] = { type = "cash", amount = 5000 },
	[2] = { type = "cash", amount = 10000 },
	[3] = { type = "building", building = "Mansion" },
	[4] = { type = "cash", amount = 25000 },
	[5] = { type = "building", building = "LuxuryCondo" },
	[6] = { type = "cash", amount = 100000 },
	[7] = { type = "building", building = "AuroraTower" },
}

local function getTimeUntilNextClaim(player)
	local dailyRewards = player:WaitForChild("Data").PlayerInfo.DailyRewards
	local lastClaimTime = dailyRewards.LastClaimTime.Value

	if lastClaimTime == 0 then
		return 0
	end

	local nextClaimTime = lastClaimTime + 86400 -- Exactly 24 hours
	local currentTime = os.time()

	return math.max(0, nextClaimTime - currentTime)
end

local function canClaimReward(player)
	local dailyRewards = player.Data.PlayerInfo.DailyRewards
	local lastClaimTime = dailyRewards.LastClaimTime.Value
	local currentTime = os.time()

	local timeSinceLastClaim = currentTime - lastClaimTime
	return timeSinceLastClaim >= 86400 or lastClaimTime == 0
end

local function getCurrentDay(player)
	local dailyRewards = player.Data.PlayerInfo.DailyRewards
	return math.clamp(dailyRewards.CurrentCycle.Value, 1, 7)
end

local function giveReward(player, day)
	local reward = REWARDS[day]
	if not reward then
		return false
	end

	if reward.type == "cash" then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Cash") then
			leaderstats.Cash.Value = leaderstats.Cash.Value + reward.amount
			return true, "Received $" .. tostring(reward.amount)
		end
	elseif reward.type == "building" then
		local backpack = player:FindFirstChild("Backpack")
		if not backpack then
			return false
		end
		local BuildingSystem = require(script.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem"))
		local tool = BuildingSystem.createToolWithBuilding(reward.building, false, 1, 0)
		if tool then
			tool.Parent = backpack
			return true, "Received " .. reward.building
		end
	end

	return false
end

function DailyRewardSystem.claimReward(player)
	if not Guard.ready(player) then
		return false
	end
	if not canClaimReward(player) then
		return false, "Already claimed today!"
	end

	local dailyRewards = player.Data.PlayerInfo.DailyRewards
	local previousClaimTime = dailyRewards.LastClaimTime.Value
	local currentDay = getCurrentDay(player)

	-- Give reward
	local success, message = giveReward(player, currentDay)
	if not success then
		return false, "Failed to give reward"
	end

	dailyRewards["Day" .. currentDay].Value = true
	dailyRewards.LastClaimTime.Value = os.time()

	local timeSinceLastClaim = os.time() - previousClaimTime

	if previousClaimTime > 0 and timeSinceLastClaim <= 172800 then
		dailyRewards.CurrentStreak.Value = dailyRewards.CurrentStreak.Value + 1
	else
		dailyRewards.CurrentStreak.Value = 1
	end

	-- Move to next day
	if currentDay >= 7 then
		-- Reset cycle
		dailyRewards.CurrentCycle.Value = 1
		for i = 1, 7 do
			dailyRewards["Day" .. i].Value = false
		end
	else
		dailyRewards.CurrentCycle.Value = currentDay + 1
	end

	return true, message
end

function DailyRewardSystem.updatePlayerUI(player)
	if not Guard.ready(player) then
		return
	end
	local dailyRewards = player.Data.PlayerInfo.DailyRewards

	local data = {
		currentDay = getCurrentDay(player),
		canClaim = canClaimReward(player),
		timeUntilNext = getTimeUntilNextClaim(player),
		streak = dailyRewards.CurrentStreak.Value,
		claimedDays = {},
	}

	for i = 1, 7 do
		data.claimedDays[i] = dailyRewards["Day" .. i].Value
	end

	updateUIEvent:FireClient(player, data, REWARDS)
end

function DailyRewardSystem.init()
	claimRewardEvent.OnServerEvent:Connect(function(player)
		local success, message = Guard.run(player, "DailyReward", DailyRewardSystem.claimReward)

		if success then
			ReplicatedStorage.Events.Notifications.ItemBought:FireClient(player, message)
		else
			ReplicatedStorage.Events.Notifications.ErrorEvent:FireClient(
				player,
				message or "Please wait and try claiming again."
			)
		end

		DailyRewardSystem.updatePlayerUI(player)
	end)

	local requestUpdateEvent = dailyRewardFolder.RequestUpdate

	requestUpdateEvent.OnServerEvent:Connect(function(player)
		DailyRewardSystem.updatePlayerUI(player)
	end)

	task.spawn(function()
		while true do
			wait(60)
			for _, player in pairs(Players:GetPlayers()) do
				if player:FindFirstChild("Data") then
					DailyRewardSystem.updatePlayerUI(player)
				end
			end
		end
	end)
end

return DailyRewardSystem
