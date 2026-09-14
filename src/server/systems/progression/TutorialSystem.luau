local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(script.Parent.Parent.security.RequestGuard)
local Factory = require(script.Parent.Parent.Parent.services.ToolFactory)
local Analytics = require(script.Parent.Parent.Parent.persistence.FunnelAnalytics)
local ReplayConfig = require(script.Parent.Parent.Parent.config.TutorialConfig)
local events = ReplicatedStorage.Events.Tutorial
local Tutorial = { createToolWithBuilding = Factory.create }
local boundTools = setmetatable({}, { __mode = "k" })

local function state(player)
	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlayerInfo")
	local tutorial = info and info:FindFirstChild("Tutorial")
	if not tutorial or not tutorial.IsInTutorial.Value then
		return nil
	end
	local stage = tutorial:FindFirstChild("ServerStage")
	if not stage then
		stage = Instance.new("IntValue")
		stage.Name = "ServerStage"
		stage.Parent = tutorial
	end
	return tutorial, stage
end

-- Called once after world/inventory restoration and before client readiness.
function Tutorial.prepareForJoin(player)
	if player:GetAttribute("MyCityTutorialPrepared") then
		return
	end
	player:SetAttribute("MyCityTutorialPrepared", true)
	local replay = ReplayConfig.ReplayEveryJoin and player.UserId == ReplayConfig.OwnerUserId
	player:SetAttribute("MyCityTutorialReplay", replay == true)
	if not replay then
		return
	end
	local quests = player.Data.PlayerInfo.Quests
	quests.QuestProgression.Value = 0
	quests.PostTutorialQuestProgress.Value = 0
	quests.PostTutorialQuestComplete.Value = false
	local tutorial = player.Data.PlayerInfo.Tutorial
	tutorial.IsInTutorial.Value = true
	tutorial.ServerStage.Value = 0
	tutorial.NewPlayer.Value = true
	tutorial.StarterBuilding.Value = false
	tutorial.TutorialBankPlaced.Value = false
	player:SetAttribute("TutorialBankTargetId", nil)
	player:SetAttribute("TutorialShackTargetId", nil)
end

function Tutorial.giveBankTool(player)
	local tutorial, stage = state(player)
	if not tutorial or stage.Value > 1 then
		return false
	end
	if stage.Value <= 1 then
		for _, container in { player:FindFirstChild("Backpack"), player.Character } do
			local existing = container and container:FindFirstChild("Bank")
			if existing then
				stage.Value = 1
				if not boundTools[existing] then
					boundTools[existing] = true
					existing.Equipped:Connect(function()
						events.ToolEquipped:FireClient(player)
					end)
				end
				if existing.Parent == player.Character then
					events.ToolEquipped:FireClient(player)
				end
				return true
			end
		end
		if stage.Value == 1 then
			return false
		end
	end
	local tool = Factory.create("Bank", false, 1, 0)
	local backpack = player:FindFirstChild("Backpack")
	if not tool or not backpack then
		return false
	end
	stage.Value = 1
	tool.Parent = backpack
	boundTools[tool] = true
	tool.Equipped:Connect(function()
		events.ToolEquipped:FireClient(player)
	end)
	Analytics.Tutorial.BankGiven(player)
	return true
end

function Tutorial.handleBuildingPlacement(player, buildingName, buildingId)
	local tutorial, stage = state(player)
	if not tutorial then
		return
	end
	if buildingName == "Bank" and stage.Value <= 1 then
		player:SetAttribute("TutorialBankTargetId", buildingId)
		stage.Value = 2
		tutorial.TutorialBankPlaced.Value = true
		events.BankPlaced:FireClient(player)
		Analytics.Tutorial.BankPlaced(player)
	elseif buildingName == "Shack" and stage.Value == 5 then
		player:SetAttribute("TutorialShackTargetId", buildingId)
		stage.Value = 6
		events.ShackConstructionStarted:FireClient(player)
	end
end

function Tutorial.handleConstructionComplete(player, buildingName, buildingId)
	local tutorial, stage = state(player)
	if not tutorial then
		return
	end
	if player:GetAttribute("MyCityTutorialReplay") then
		local target = player:GetAttribute("Tutorial" .. buildingName .. "TargetId")
		if not target or target ~= buildingId then
			return
		end
	end
	if buildingName == "Bank" and stage.Value <= 2 then
		stage.Value = 3
		events.ConstructionComplete:FireClient(player)
		Analytics.Tutorial.BankBuilt(player)
	elseif buildingName == "Shack" and stage.Value >= 5 and stage.Value < 7 then
		stage.Value = 7
		events.ShackPlaced:FireClient(player)
		Analytics.Tutorial.ShackPlaced(player)
	end
end

function Tutorial.handleIncomeCollection(player)
	local tutorial, stage = state(player)
	if not tutorial or stage.Value ~= 3 then
		return
	end
	stage.Value = 4
	events.IncomeCollect:FireClient(player)
	Analytics.Tutorial.IncomeCollected(player)
end

function Tutorial.handleShackPurchase(player)
	local tutorial, stage = state(player)
	if not tutorial or stage.Value ~= 4 then
		return
	end
	stage.Value = 5
	events.ShackPurchased:FireClient(player)
	Analytics.Tutorial.ShackPurchased(player)
end

function Tutorial.finishTutorial(player)
	local tutorial, stage = state(player)
	if not tutorial or stage.Value ~= 7 then
		return false
	end
	tutorial.IsInTutorial.Value = false
	tutorial.NewPlayer.Value = false
	tutorial.StarterBuilding.Value = true
	Analytics.Tutorial.Completed(player)
	return true
end

-- Infer progress for profiles created before ServerStage existed.
function Tutorial.resume(player)
	if player:GetAttribute("MyCityTutorialReplay") then
		return
	end
	local tutorial, stage = state(player)
	if not tutorial or stage.Value ~= 0 then
		return
	end
	local data = player.Data
	local function has(folder, name)
		if not folder then
			return false
		end
		for _, entry in folder:GetChildren() do
			if entry.Name:match("^([^_]+)_") == name then
				return true
			end
		end
		return false
	end
	local backpack = player:FindFirstChild("Backpack")
	local function hasTool(name)
		return (backpack and backpack:FindFirstChild(name))
			or (player.Character and player.Character:FindFirstChild(name))
	end
	if has(data.CurrentBuildings, "Shack") then
		stage.Value = 7
	elseif has(data.CurrentConstructions, "Shack") then
		stage.Value = 6
	elseif hasTool("Shack") then
		stage.Value = 5
	elseif has(data.CurrentBuildings, "Bank") then
		stage.Value = 3
	elseif has(data.CurrentConstructions, "Bank") then
		stage.Value = 2
	elseif hasTool("Bank") then
		stage.Value = 1
	end
end

function Tutorial.init()
	events.GiveBank.OnServerEvent:Connect(function(player)
		Guard.run(player, "TutorialBank", Tutorial.giveBankTool)
	end)
	ReplicatedStorage.Events.TutorialFinished.OnServerEvent:Connect(function(player)
		Guard.run(player, "TutorialFinished", Tutorial.finishTutorial)
	end)
	events.ShopOpened.OnServerEvent:Connect(function(player)
		if Guard.ready(player) then
			Analytics.Tutorial.ShopOpened(player)
		end
	end)
	events.ShackPurchased.OnServerEvent:Connect(function(player)
		local tutorial, stage = state(player)
		if tutorial and stage.Value == 4 then
			local Shop = require(script.Parent.Parent.economy.ShopSystem)
			Guard.run(player, "TutorialPurchase", Shop.purchase, "Shack", "Cash")
		end
	end)
	events.RequestStart.OnServerEvent:Connect(function(player)
		if Guard.ready(player) and state(player) then
			events.StartTutorial:FireClient(player)
		end
	end)
end
return Tutorial
