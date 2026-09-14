local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local environment = { Instance = r.Instance }
local codec =
	luau.load(fs.readFile("src/server/persistence/PlayerDataModule/ProfileCodec.luau"), { environment = environment })()
local schema =
	luau.load(fs.readFile("src/server/persistence/PlayerDataModule/DataSchema.luau"), { environment = environment })()
local migrate = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/SchemaMigration.luau"), {
	environment = {
		Instance = r.Instance,
		script = { Parent = { DataSchema = schema } },
		require = function(module)
			return module
		end,
	},
})()
-- No authored template instances or ModuleScript children are provided.
local data, stats = codec.restore({ NewProfile = true })
migrate({ Name = "NewPlayer" }, data, stats)
assert(data.PlayerInfo.Tutorial.IsInTutorial.Value and data.PlayerInfo.Tutorial.ServerStage.Value == 0)
assert(
	stats.Cash.Value == 500
		and data.PlayerInfo.Population.Value == 0
		and not stats:FindFirstChild("Population")
		and stats.Rebirths.Value == 0
)
assert(
	data.PlayerInfo.Quests.QuestProgression.Value == 0 and not data.PlayerInfo.Quests.PostTutorialQuestComplete.Value
)
assert(data.PlayerInfo.DailyRewards.CurrentCycle.Value == 1 and not data.PlayerInfo.DailyRewards.Day7.Value)
for _, name in { "Inventory", "CurrentBuildings", "CurrentConstructions", "OwnedTiles" } do
	assert(data[name]:IsA("Folder"))
end
local function saved(class, value)
	return { ClassName = class, Value = value }
end
local old = {
	PlayerData = {
		PlayerInfo = {
			IsInTutorial = saved("BoolValue", false),
			GroupRewardClaimed = saved("BoolValue", true),
			LastUpdate = saved("StringValue", "12345"),
			SchemaVersion = saved("IntValue", 2),
			Quests_1 = { QuestProgression = saved("IntValue", 3) },
		},
		Inventory = { Tool_one = saved("StringValue", "original descriptor") },
		CurrentBuildings = { Bank_id = saved("StringValue", "original building") },
		OwnedTiles = { Tile9 = saved("IntValue", 9) },
	},
	LeaderBoardData = {
		Cash = saved("IntValue", 123456),
		Population = saved("IntValue", 20),
		Rebirths = saved("IntValue", 4),
	},
}
data, stats = codec.restore(old)
migrate({ Name = "Returning" }, data, stats)
assert(stats.Cash.Value == 123456 and stats.Rebirths.Value == 4)
assert(data.PlayerInfo.Population.Value == 20 and #stats:GetChildren() == 2)
assert(not data.PlayerInfo.Tutorial.IsInTutorial.Value and data.PlayerInfo.GroupRewardClaimed.Value)
assert(
	data.PlayerInfo.Quests.QuestProgression.Value == 3 and data.PlayerInfo.Quests.PostTutorialQuestProgress.Value == 0
)
assert(
	data.PlayerInfo.LastUpdate.Value == 12345
		and data.PlayerInfo.LastUpdate:IsA("IntValue")
		and data.PlayerInfo.SchemaVersion.Value == schema.Version
)
assert(
	data.Inventory.Tool_one.Value == "original descriptor"
		and data.CurrentBuildings.Bank_id.Value == "original building"
)
assert(data.OwnedTiles.Tile9.Value == 9)
local snapshot =
	{ PlayerData = codec.encodeFolder(data), LeaderBoardData = codec.encodeFolder(stats), FolderEncoding = 2 }
local again, moreStats = codec.restore(snapshot)
migrate({ Name = "Returning" }, again, moreStats)
assert(moreStats.Cash.Value == 123456 and again.Inventory.Tool_one.Value == "original descriptor")
assert(again.PlayerInfo.Population.Value == 20 and not moreStats:FindFirstChild("Population"))
assert(not pcall(codec.restore, {}), "Missing saved data became a new city")

-- The real loader must expose restoration errors and release only the original record.
local broken = { PlayerData = false, LeaderBoardData = {} }
local released, warned, kicked = false, false, false
local player = {
	Parent = true,
	Name = "Failure",
	UserId = 1,
	SetAttribute = function() end,
	GetAttribute = function()
		return nil
	end,
	Kick = function()
		kicked = true
	end,
}
local store = {
	acquire = function()
		return broken
	end,
	release = function()
		released = true
	end,
	save = function()
		error("Failed restore attempted to write gameplay")
	end,
}
local ownerResetConfig = { OwnerUserId = 1790165114, ResetProgressEveryJoin = true }
local ownerReset = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/OwnerReset.luau"), {
	environment = {
		script = { Parent = { Parent = { Parent = { config = { TutorialConfig = ownerResetConfig } } } } },
		require = function(m)
			return m
		end,
	},
})()
local scriptMock = {
	OwnerReset = ownerReset,
	ProfileCodec = codec,
	DataSchema = schema,
	SchemaMigration = migrate,
	SessionStore = store,
	Parent = { Parent = { systems = { security = { RequestGuard = {} } } } },
}
local loader = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/init.luau"), {
	environment = {
		script = scriptMock,
		require = function(module)
			return module
		end,
		game = {
			GetService = function(_, name)
				if name == "HttpService" then
					return {
						GenerateGUID = function()
							return "test-session"
						end,
					}
				end
				return {}
			end,
		},
		warn = function(message, _, detail)
			if message == "[Data] Restore failed for" then
				warned = type(detail) == "string" and detail:find("Invalid saved folder", 1, true) ~= nil
			end
		end,
	},
})()
assert(not loader.loadPlayerData(player) and released and kicked and warned and not loader.isLoaded(player))
print(
	"PASS: template-free new profile, saved cash/items/flags preservation, missing nested defaults, round trip, malformed record rejection and safe diagnostic failure"
)

local missing = {
	FindFirstChild = function()
		return nil
	end,
	WaitForChild = function()
		error("Waited on failed player data")
	end,
}
local rebirth = { State = {}, RebirthSystem = {}, initialized = {} }
luau.load(fs.readFile("src/server/systems/progression/RebirthSystem/Lifecycle.luau"))()(rebirth)
rebirth.RebirthSystem.initializePlayer(missing)
assert(not rebirth.initialized[missing])
local quests = { PostTutorialQuest = {}, playerStates = {}, placedBuildingIds = {} }
luau.load(fs.readFile("src/server/systems/progression/PostTutorialQuest/Lifecycle.luau"))()(quests)
quests.PostTutorialQuest.initializePlayer(missing)
local plot = { State = {}, PlotManager = {}, plotsFolder = {} }
luau.load(fs.readFile("src/server/systems/world/PlotManager/Reset.luau"))()(plot)
plot.PlotManager.resetPlot(missing)
print("PASS: failed-data rebirth/quest initialization and plot cleanup return without waiting")

-- Reproduce legacy field representations before Roblox Instances are created.
for _, case in
	{
		{ class = "StringValue", raw = "", expected = 1700000000 },
		{ class = "StringValue", raw = "not-a-timestamp", expected = 1700000000 },
		{ class = "StringValue", raw = "12345", expected = 12345 },
		{ class = "BoolValue", raw = false, expected = 1700000000 },
		{ class = "NumberValue", raw = 12345.9, expected = 12345 },
		{ class = "IntValue", raw = 0, expected = 0 },
		{ class = "ObjectValue", expected = 1700000000 },
	}
do
	local original = {
		PlayerData = {
			PlayerInfo = { LastUpdate = { ClassName = case.class, Value = case.raw } },
			Inventory = { Saved = saved("StringValue", "keep") },
		},
		LeaderBoardData = { Cash = saved("StringValue", "42000"), Rebirths = saved("NumberValue", 4) },
		Receipts = { receipt = { Complete = true } },
		Transfers = { transfer = { Name = "Bank" } },
	}
	local normalized = schema.Normalize(original, "Legacy", 1700000000)
	assert(
		original.PlayerData.PlayerInfo.LastUpdate.ClassName == case.class,
		"Normalization modified the original acquired record"
	)
	assert(normalized.PlayerData.PlayerInfo.LastUpdate.ClassName == "IntValue")
	assert(normalized.PlayerData.PlayerInfo.LastUpdate.Value == case.expected)
	local city, leaders = codec.restore(normalized)
	migrate({ Name = "Legacy" }, city, leaders)
	assert(city.PlayerInfo.LastUpdate:IsA("IntValue") and leaders.Cash.Value == 42000 and leaders.Rebirths.Value == 4)
	assert(
		city.Inventory.Saved.Value == "keep"
			and normalized.Receipts.receipt.Complete
			and normalized.Transfers.transfer.Name == "Bank"
	)
end

-- Execute the actual load/save/rejoin API with an old blank-string timestamp.
local serde = require("@lune/serde")
local durable = {
	PlayerData = {
		PlayerInfo = { LastUpdate = saved("StringValue", ""), IsInTutorial = saved("StringValue", "false") },
		Inventory = { Tool_saved = saved("StringValue", "saved tool") },
	},
	LeaderBoardData = { Cash = saved("StringValue", "76543"), Rebirths = saved("IntValue", 2) },
	Receipts = { paid = { Complete = true } },
}
local http = {
	GenerateGUID = function()
		return "test-session"
	end,
	JSONEncode = function(_, object)
		return serde.encode("json", object)
	end,
	JSONDecode = function(_, encoded)
		return serde.decode("json", encoded)
	end,
}
scriptMock.SessionStore = {
	acquire = function()
		return durable
	end,
	save = function(_, _, snapshot)
		durable = http:JSONDecode(http:JSONEncode(snapshot))
		return true
	end,
}
local liveLoader = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/init.luau"), {
	environment = {
		script = scriptMock,
		require = function(module)
			return module
		end,
		game = {
			GetService = function(_, name)
				return if name == "HttpService" then http else {}
			end,
		},
	},
})()
local players = r.Instance.new("Folder")
local first = r.Instance.new("Player")
first.Name, first.UserId, first.Parent = "Legacy", 1234, players
assert(liveLoader.loadPlayerData(first))
assert(first.Data.PlayerInfo.LastUpdate:IsA("IntValue") and first.leaderstats.Cash.Value == 76543)
assert(not first.Data.PlayerInfo.Tutorial.IsInTutorial.Value)
first.leaderstats.Cash.Value += 100
assert(liveLoader.savePlayerData(first, true))
assert(durable.PlayerData.PlayerInfo.LastUpdate.ClassName == "IntValue" and durable.LeaderBoardData.Cash.Value == 76643)
assert(durable.Receipts.paid.Complete and durable.PlayerData.Inventory.Tool_saved.Value == "saved tool")
local second = r.Instance.new("Player")
second.Name, second.UserId, second.Parent = "Legacy", 1234, players
assert(liveLoader.loadPlayerData(second) and second.leaderstats.Cash.Value == 76643)
assert(second.Data.PlayerInfo.LastUpdate:IsA("IntValue") and second.Data.Inventory.Tool_saved.Value == "saved tool")
print(
	"PASS: legacy timestamp classes normalized; real loader/save/rejoin keeps cash, tools, tutorial and receipt history"
)

-- The owner starts fresh on every join; regular players above retain their real progress.
for join = 1, 2 do
	local owner = r.Instance.new("Player")
	owner.Name, owner.UserId, owner.Parent = "Owner", 1790165114, players
	assert(liveLoader.loadPlayerData(owner))
	assert(
		owner:GetAttribute("MyCityFreshStart")
			and owner.leaderstats.Cash.Value == 500
			and owner.leaderstats.Rebirths.Value == 0
	)
	assert(#owner.Data.Inventory:GetChildren() == 0 and #owner.Data.CurrentBuildings:GetChildren() == 0)
	assert(owner.Data.PlayerInfo.Tutorial.IsInTutorial.Value and owner.Data.PlayerInfo.Tutorial.ServerStage.Value == 0)
	assert(liveLoader.getRecord(owner).Receipts.paid.Complete, "Fresh start cleared purchase receipt history")
	owner.leaderstats.Cash.Value = 999999
	assert(liveLoader.savePlayerData(owner, true))
end
print("PASS: owner-only full fresh start repeats each join while preserving transaction receipts")

-- A successful acquisition returning after PlayerRemoving must release the untouched record.
local departing = r.Instance.new("Player")
departing.Name, departing.UserId, departing.Parent = "Departing", 9876, players
local acquired, releasedOriginal = 0, false
scriptMock.SessionStore.acquire = function()
	acquired += 1
	departing:SetAttribute("MyCityLeaving", true)
	return durable
end
scriptMock.SessionStore.release = function()
	releasedOriginal = true
	return true
end
scriptMock.SessionStore.save = function()
	error("Departing load attempted to write gameplay")
end
assert(not liveLoader.loadPlayerData(departing))
assert(
	acquired == 1 and releasedOriginal and not departing:FindFirstChild("Data") and not liveLoader.isLoaded(departing)
)
assert(not liveLoader.loadPlayerData(departing) and acquired == 1)
print(
	"PASS: departure during profile acquisition releases original without restoring instances, kicking or starting another load"
)
