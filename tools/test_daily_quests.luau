local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env or {} })()
end
local function clone(value)
	return serde.decode("json", serde.encode("json", value))
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in callbacks do
				if entry.active then
					entry.fn(...)
				end
			end
		end,
	}
end
local function node(t)
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:GetChildren()
		return self.children or {}
	end
	function t:GetAttribute(name)
		return self[name]
	end
	function t:SetAttribute(name, v)
		self[name] = v
	end
	function t:GetPropertyChangedSignal(name)
		self.changed = self.changed or {}
		self.changed[name] = self.changed[name] or signal()
		return self.changed[name]
	end
	return t
end
local catalog = load("src/server/config/DailyQuestCatalog.luau")
local root = { config = { DailyQuestCatalog = catalog } }
local boardScript = { Parent = { Parent = { Parent = { Parent = root } } } }
local Board = load("src/server/systems/progression/DailyQuests/Board.luau", {
	script = boardScript,
	require = function(m)
		return m
	end,
})
assert(#catalog.List == 40)
for user = 1, 20 do
	local profile, previous = {}, {}
	for day = 20000, 20099 do
		local board, refreshed = Board.ensure(profile, user, day * 86400 + 1)
		assert(refreshed and #board.Entries == 6)
		local metrics, difficulty, ids = {}, { Easy = 0, Medium = 0, Hard = 0 }, {}
		for _, entry in board.Entries do
			local definition = catalog.ById[entry.Id]
			assert(not metrics[definition.Metric] and not ids[entry.Id] and not previous[entry.Id])
			metrics[definition.Metric], ids[entry.Id] = true, true
			difficulty[definition.Difficulty] += 1
		end
		assert(difficulty.Easy == 2 and difficulty.Medium == 2 and difficulty.Hard == 2)
		assert(Board.ensure(profile, user, day * 86400 + 86399) == board, "Same day rerolled")
		previous = ids
	end
end
for _, quest in catalog.List do
	local board = { Day = 3, Entries = { { Id = quest.Id, Progress = 0, Claimed = false } } }
	assert(not Board.progress(board, quest.Metric, 0 / 0))
	assert(not Board.progress(board, quest.Metric, -5))
	assert(not Board.progress(board, quest.Metric, math.huge))
	assert(not Board.claim(board, 3, quest.Id), "Incomplete quest paid out")
	Board.progress(board, quest.Metric, quest.Target / 2)
	Board.progress(board, quest.Metric, quest.Target / 2)
	assert(board.Entries[1].Progress == (if quest.Mode == "peak" then quest.Target / 2 else quest.Target))
	Board.progress(board, quest.Metric, quest.Target * 2)
	assert(board.Entries[1].Progress == quest.Target)
	assert(not Board.claim(board, 2, quest.Id) and not Board.claim(board, 3, {}))
	assert(Board.claim(board, 3, quest.Id) == quest.Reward)
	assert(not Board.claim(board, 3, quest.Id), "Claim paid twice")
end
local saved = {}
local initial = Board.ensure(saved, 7, 100 * 86400)
local first = catalog.ById[initial.Entries[1].Id]
Board.progress(initial, first.Metric, first.Target)
assert(Board.claim(initial, 100, first.Id))
local restored = clone(saved)
local rejoined, rerolled = Board.ensure(restored, 7, 100 * 86400 + 100)
assert(not rerolled and rejoined.Entries[1].Claimed)
assert(not Board.claim(rejoined, 100, first.Id))
local nextBoard = Board.ensure(restored, 7, 101 * 86400)
assert(nextBoard.Day == 101 and not Board.claim(nextBoard, 100, first.Id))
print(
	"PASS: 40 objectives, 2000 balanced daily boards, six distinct metrics, no previous-day repeats, bounded progress, all rewards, stale/duplicate claims and persisted rejoin"
)

-- Run the actual service and runtime against committed server-side city state.
local now, monotonic = 100 * 86400 + 100, 1
local models = {}
local placed = node({ children = models, ChildAdded = signal(), ChildRemoved = signal() })
for i = 1, 8 do
	table.insert(
		models,
		node({
			BuildingType = if i <= 3 then "Road" else "Bank",
			IsA = function(_, class)
				return class == "Model"
			end,
		})
	)
end
local workspace = node({ Plots = node({ Plot1 = node({ Buildings = node({ Placed = placed }) }) }) })
local Runtime = load(
	"src/server/systems/progression/DailyQuests/Runtime.luau",
	{ workspace = workspace, os = {
		time = function()
			return now
		end,
	} }
)
local player = node({
	UserId = 7,
	Parent = true,
	MyCityLoaded = true,
	MyCityInventoryReady = true,
	Data = node({
		PlotInfo = { Plot = { Value = 1 } },
		PlayerInfo = { Population = node({ Value = 100 }), Tutorial = { IsInTutorial = node({ Value = false }) } },
	}),
	leaderstats = { Cash = { Value = 500 } },
})
local record, durable, saves, failSave, pauseSave = {}, nil, 0, false, false
local function remote()
	return {
		OnServerEvent = signal(),
		calls = {},
		FireClient = function(self, _, ...)
			table.insert(self.calls, table.pack(...))
		end,
	}
end
local events = { Request = remote(), Update = remote(), Claim = remote(), Result = remote() }
local Data = {
	getRecord = function()
		return record
	end,
	savePlayerData = function()
		saves += 1
		assert(record.DailyQuests.Entries[1].Claimed and player.leaderstats.Cash.Value > 500)
		if pauseSave then
			coroutine.yield()
		end
		if failSave then
			return false
		end
		durable = clone({ DailyQuests = record.DailyQuests, Cash = player.leaderstats.Cash.Value })
		return true
	end,
}
local Guard =
	load("src/server/systems/security/RequestGuard.luau", { os = {
		clock = function()
			return monotonic
		end,
	} })
local Signals = load("src/server/services/QuestSignals.luau")
root.persistence, root.services = { PlayerDataModule = Data }, { QuestSignals = Signals }
root.systems = { Parent = root, security = { RequestGuard = Guard } }
local progression = { Parent = root.systems }
local timer
local service = load("src/server/systems/progression/DailyQuests/init.luau", {
	script = { Parent = progression, Board = Board, Runtime = Runtime },
	require = function(m)
		return m
	end,
	game = {
		GetService = function(_, name)
			return if name == "Players" then { PlayerRemoving = signal() } else { Events = { DailyQuests = events } }
		end,
	},
	os = {
		clock = function()
			return monotonic
		end,
		time = function()
			return now
		end,
	},
	task = {
		spawn = function(fn)
			timer = coroutine.create(fn)
		end,
		wait = coroutine.yield,
	},
})
service.init()
service.initializePlayer(player)
assert(#events.Update.calls[#events.Update.calls][1].Quests == 6)
assert(coroutine.resume(timer)) -- yield before first tick
now += 2
assert(coroutine.resume(timer))
local entry = record.DailyQuests.Entries[1]
local definition = catalog.ById[entry.Id]
player.Data.PlayerInfo.Tutorial.IsInTutorial.Value = true
local before = entry.Progress
Signals.emit(player, definition.Metric, definition.Target)
assert(entry.Progress == before, "Tutorial activity counted toward daily quest")
player.Data.PlayerInfo.Tutorial.IsInTutorial.Value = false
Signals.emit(player, definition.Metric, definition.Target)
assert(entry.Progress == definition.Target)
local reward = definition.Reward
pauseSave = true
local request = coroutine.create(function()
	events.Claim.OnServerEvent:Fire(player, record.DailyQuests.Day, entry.Id)
end)
assert(coroutine.resume(request))
assert(player.leaderstats.Cash.Value == 500 + reward)
monotonic += 1
events.Claim.OnServerEvent:Fire(player, record.DailyQuests.Day, entry.Id)
assert(saves == 1, "Concurrent request bypassed mutation guard")
assert(coroutine.resume(request))
assert(durable.Cash == 500 + reward and durable.DailyQuests.Entries[1].Claimed)
monotonic += 1
events.Claim.OnServerEvent:Fire(player, record.DailyQuests.Day, entry.Id)
assert(saves == 1 and player.leaderstats.Cash.Value == 500 + reward)
-- Failed save does not let retries mint a second reward.
entry.Claimed = false
pauseSave = false
failSave = true
monotonic += 1
events.Claim.OnServerEvent:Fire(player, record.DailyQuests.Day, entry.Id)
local credited = player.leaderstats.Cash.Value
monotonic += 1
events.Claim.OnServerEvent:Fire(player, record.DailyQuests.Day, entry.Id)
assert(player.leaderstats.Cash.Value == credited and entry.Claimed)
local oldDay = record.DailyQuests.Day
now = (oldDay + 1) * 86400 + 2
assert(coroutine.resume(timer))
assert(record.DailyQuests.Day == oldDay + 1)
for _, item in record.DailyQuests.Entries do
	local q = catalog.ById[item.Id]
	if q.Metric == "buildings" then
		assert(item.Progress == math.min(5, q.Target))
	end
	if q.Metric == "roads" then
		assert(item.Progress == math.min(3, q.Target))
	end
	if q.Metric == "play" then
		assert(item.Progress == 2, "Playtime leaked from yesterday")
	end
end
service.cleanup(player)
print(
	"PASS: server-only event tracking, tutorial exclusion, city/road counts, serialized claims, same-snapshot cash+marker, failed-save retry safety and online midnight rotation"
)
