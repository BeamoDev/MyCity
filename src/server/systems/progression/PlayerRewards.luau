local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeSystem = require(script.Parent.BadgeModule)
local Factory = require(script.Parent.Parent.Parent.services.ToolFactory)
local GROUP_ID = 1050526813
local GROUP_REWARD_BUILDING = "PoliceStation"
local Guard = require(script.Parent.Parent.security.RequestGuard)
local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local pending = setmetatable({}, { __mode = "k" })
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

local function eligible(player)
	if not Guard.ready(player) then
		return nil
	end
	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlayerInfo")
	local tutorial = info and info:FindFirstChild("Tutorial")
	local active = tutorial and tutorial:FindFirstChild("IsInTutorial")
	local claimed = info and info:FindFirstChild("GroupRewardClaimed")
	if not active or active.Value or not claimed or claimed.Value then
		return nil
	end
	return claimed
end

-- Called after ClientReady: tutorial presentation has observed completion before the alert.
function Rewards.giveGroupReward(player)
	if pending[player] or not eligible(player) then
		return
	end
	pending[player] = true
	local ok, err = pcall(function()
		local checked, member
		for attempt = 1, 3 do
			checked, member = pcall(player.IsInGroup, player, GROUP_ID)
			if checked then
				break
			end
			task.wait(attempt)
			if not eligible(player) then
				return
			end
		end
		if not checked or not member then
			return
		end
		-- Tutorial completion/respawn may still hold the inventory guard for a moment.
		for _ = 1, 20 do
			if not eligible(player) then
				return
			end
			local granted = Guard.run(player, "GroupReward", function()
				local claimed = eligible(player)
				local backpack = player:FindFirstChild("Backpack")
				if not claimed or not backpack then
					return false
				end
				local tool = Factory.create(GROUP_REWARD_BUILDING, false, 1, 0)
				if not tool then
					return false
				end
				if not eligible(player) or backpack.Parent ~= player then
					tool:Destroy()
					return false
				end
				tool.Parent = backpack
				claimed.Value = true
				-- The existing beforeSave hook snapshots the tool and claim in one profile.
				Data.savePlayerData(player)
				-- Keep the marker on transient save failure; autosave retries without a second grant.
				if player.Parent and not player:GetAttribute("MyCityLeaving") then
					ReplicatedStorage.Events.Notifications.GroupReward:FireClient(player)
				end
				return true
			end)
			if granted then
				return
			end
			task.wait(0.5)
		end
	end)
	pending[player] = nil
	if not ok then
		warn("[GroupReward] Grant failed for", player.UserId, err)
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
