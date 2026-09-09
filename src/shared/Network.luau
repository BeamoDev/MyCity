-- The server owns remote creation. Clients wait for every descendant to replicate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = {}

local function events(names)
	local result = {}
	for name in string.gmatch(names, "%S+") do
		result[name] = "RemoteEvent"
	end
	return result
end

local schema = {
	Events = {
		TutorialFinished = "RemoteEvent",
		Loading = events("LoadingProgress LoadingComplete ClientReady IntroFinished"),
		Friends = events("FriendBoostUpdate"),
		Likes = events("AlertClient"),
		CitySign = events("UpdateCityName RequestCityNameEdit"),
		DailyRewards = events("ClaimReward UpdateUI RequestUpdate"),
		DailyQuests = events("Request Update Claim Result"),
		Shop = events("ShopEvent PurchaseEvent"),
		Sell = events(
			"SellItem OpenUI SellUICurrentTool ErrorEvent MustBuildBuilding SoldWithProfit Sold CantSellBank"
		),
		Movement = events("CollectBuilding Delete Move CleanupPreview Unauthorized DeletedBuilding CannotPlace"),
		Notifications = events(
			"CollectIncome ErrorEvent BuildingComplete BuildingStarted ItemBought BuildingDeleted GroupReward Purchased BrokeAhh BuilderLimitReached BuildingLevelUp BuildingCollected BuildingStole BuildAllComplete StockRefreshed RarityAnnounce PlaceSound"
		),
		UI = events(
			"CodeFeeback ToggleOverheadUI OpenItemShop ShowBuildingUI CloseBuildingInfo UpdateBuilderUI UpdateConstructionUI MaxReached DealShown"
		),
		Rebirth = events("RequestRebirth RebirthSuccess RebirthFailed UpdateRebirthUI"),
		PostTutorialQuest = events("UpdateQuest QuestComplete AllQuestsDone"),
		StealBuilding = events("Stole Recieved"),
		Weather = events("TimeUpdate UpdateUI"),
		VFX = events("CameraShake"),
		Teleport = events("TeleportError"),
		Tutorial = events(
			"GiveBank ToolEquipped BankPlaced ConstructionComplete IncomeCollect ShackPurchased ShackPlaced ShopOpened RequestStart StartTutorial ShackConstructionStarted WaitToBuild DisplayPlace"
		),
	},
	Functions = {
		PlaceBlock = "RemoteFunction",
		Friends = { GetFriendBoost = "RemoteFunction" },
	},
}

local function resolve(parent, entries, create, deadline)
	for name, entry in pairs(entries) do
		local className = if type(entry) == "table" then "Folder" else entry
		local child
		if create then
			child = parent:FindFirstChild(name)
			if not child then
				child = Instance.new(className)
				child.Name = name
				child.Parent = parent
			end
		else
			child = parent:FindFirstChild(name)
			if not child then
				local remaining = math.max(0, deadline - os.clock())
				child = parent:WaitForChild(name, remaining)
			end
			assert(
				child,
				string.format(
					"[Network] Startup timed out waiting for %s.%s. Check server startup errors and sync server/shared together.",
					parent:GetFullName(),
					name
				)
			)
		end
		assert(
			child:IsA(className),
			string.format("[Network] %s must be a %s (found %s)", child:GetFullName(), className, child.ClassName)
		)
		if type(entry) == "table" then
			resolve(child, entry, create, deadline)
		end
	end
end

function Network.start()
	assert(RunService:IsServer(), "[Network] Only the server can create remotes")
	-- No yielding: independent server entry points can safely call this repeatedly.
	resolve(ReplicatedStorage, schema, true)
end

function Network.wait()
	-- Waiting for just Events/Functions is insufficient during partial replication.
	resolve(ReplicatedStorage, schema, false, os.clock() + 60)
end

return Network
