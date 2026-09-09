local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeSystem = require(script.Parent.BadgeModule)
local Factory = require(script.Parent.Parent.Parent.services.ToolFactory)
local GROUP_ID = 1050526813
local GROUP_REWARD_BUILDING = "PoliceStation"
local MIN_RANK_FOR_REWARD = 0
local cashConnections = {}
local Rewards = {}
local function checkMillionaire(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local cash = leaderstats:FindFirstChild("Cash")
	if not cash then
		return
	end
	if cash.Value >= 1000000 then
		BadgeSystem.AwardBadge(player, 3222065584134306)
	end
end

function Rewards.trackMillionaire(player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		return
	end
	local cash = leaderstats:WaitForChild("Cash", 5)
	if not cash then
		return
	end
	checkMillionaire(player)
	cashConnections[player.UserId] = cash:GetPropertyChangedSignal("Value"):Connect(function()
		if cash.Value >= 1000000 then
			checkMillionaire(player)
			if cashConnections[player.UserId] then
				cashConnections[player.UserId]:Disconnect()
				cashConnections[player.UserId] = nil
			end
		end
	end)
end

function Rewards.giveGroupReward(player)
	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return
	end

	-- Check if already claimed
	local hasGroupReward = playerInfo:FindFirstChild("GroupRewardClaimed")
	if not hasGroupReward then
		hasGroupReward = Instance.new("BoolValue")
		hasGroupReward.Name = "GroupRewardClaimed"
		hasGroupReward.Parent = playerInfo
		hasGroupReward.Value = false
	end

	if hasGroupReward.Value then
		return
	end

	-- Check if player is in group
	local success, isInGroup = pcall(function()
		return player:IsInGroup(GROUP_ID)
	end)
	if not success or not isInGroup then
		return
	end

	-- Check player's rank in group
	local success2, rank = pcall(function()
		return player:GetRankInGroup(GROUP_ID)
	end)
	if not success2 or rank < MIN_RANK_FOR_REWARD then
		return
	end

	-- Check if already has the building in inventory
	local inventory = player:FindFirstChild("Data") and player.Data:FindFirstChild("Inventory")
	if not inventory then
		return
	end
	if inventory:FindFirstChild(GROUP_REWARD_BUILDING) then
		return
	end

	-- Give the group reward building
	local tool = Factory.create(GROUP_REWARD_BUILDING, false, 1, 0)
	if tool then
		tool.Parent = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack")
		hasGroupReward.Value = true

		-- Fire notification event if it exists
		if ReplicatedStorage.Events.Notifications:FindFirstChild("GroupReward") then
			ReplicatedStorage.Events.Notifications.GroupReward:FireClient(player)
		end
	end
end

function Rewards.cleanup(player)
	local connection = cashConnections[player.UserId]
	if connection then
		connection:Disconnect()
	end
	cashConnections[player.UserId] = nil
end
return Rewards
