local fs, luau = require("@lune/fs"), require("@lune/luau")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env })()
end
local function node(t)
	t = t or {}
	function t:FindFirstChild(k)
		return self[k]
	end
	t.WaitForChild = t.FindFirstChild
	return t
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local saveOk, filterOk, stored, input, writes = true, true, nil, nil, 0
local database = {
	SetAsync = function(_, _, value)
		writes += 1
		if not saveOk then
			error("storage unavailable")
		end
		stored = value
	end,
	GetAsync = function()
		return stored
	end,
}
local service = {
	Players = { PlayerRemoving = signal() },
	Workspace = node({ Plots = node({}) }),
	RunService = {
		IsStudio = function()
			return false
		end,
	},
	ReplicatedStorage = node({ Events = node({ CitySign = node({ UpdateCityName = {}, RequestCityNameEdit = {} }) }) }),
	DataStoreService = {
		GetDataStore = function(_, name)
			assert(name == "CityNames")
			return database
		end,
	},
	TextService = {
		FilterStringAsync = function(_, text)
			input = text
			if not filterOk then
				error("filter unavailable")
			end
			return {
				GetNonChatStringForBroadcastAsync = function()
					return input
				end,
			}
		end,
	},
}
local guard = {
	ready = function()
		return true
	end,
}
local names = load("src/server/systems/world/CityNameSystem.luau", {
	script = { Parent = { Parent = { security = { RequestGuard = guard } } } },
	require = function(m)
		return m
	end,
	game = {
		GetService = function(_, name)
			return service[name]
		end,
	},
	task = { wait = function() end },
})
local value = { Value = "Original" }
local player = node({
	UserId = 7,
	Name = "Tester",
	Parent = true,
	Data = node({ PlayerInfo = node({ CityName = value }), PlotInfo = node({ Plot = { Value = 0 } }) }),
})
function player:GetAttribute()
	return false
end
saveOk = false
assert(not names.setCityName(player, "Changed") and value.Value == "Original" and writes == 3)
saveOk = true
filterOk = false
assert(not names.setCityName(player, "Changed") and value.Value == "Original" and writes == 3)
filterOk = true
local text = string.rep(utf8.char(0x57CE), 60)
assert(names.setCityName(player, text) and utf8.len(value.Value) == 50 and stored == value.Value)
print("PASS: city-name save/filter failure preserves prior name; UTF-8 truncation preserves whole characters")

local players = { PlayerAdded = signal(), PlayerRemoving = signal() }
local roster, calls, now, fail, queue = {}, 0, 0, false, {}
function players:GetPlayers()
	return table.clone(roster)
end
for i = 1, 3 do
	local p = { UserId = i, Parent = players }
	function p:IsFriendsWith()
		calls += 1
		if fail then
			error("friend service unavailable")
		end
		return true
	end
	function p:SetAttribute(k, v)
		self[k] = v
	end
	table.insert(roster, p)
end
local friends = load(
	"src/server/systems/social/FriendBoost.luau",
	{
		game = {
			GetService = function()
				return players
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		task = {
			defer = function(fn)
				table.insert(queue, fn)
			end,
			spawn = function(fn)
				assert(coroutine.resume(coroutine.create(fn)))
			end,
			wait = coroutine.yield,
		},
		warn = error,
	}
)
local function flush()
	local batch = queue
	queue = {}
	for _, fn in batch do
		fn()
	end
end
friends.start()
friends.start()
assert(calls == 3 and roster[1].FriendBoost == 20, "Duplicate friend lookups or startup")
players.PlayerAdded:Fire()
flush()
assert(calls == 3)
now = 121
fail = true
players.PlayerAdded:Fire()
flush()
assert(calls == 6 and roster[1].FriendBoost == 20, "Failure erased successful friendship cache")
local removed = table.remove(roster, 1)
removed.Parent = nil
players.PlayerRemoving:Fire(removed)
flush()
assert(roster[1].FriendBoost == 10 and roster[2].FriendCount == 1)
print("PASS: symmetric friend cache, idempotent startup, failure retention and departure refresh")

local badgeCalls, attempts, badge = 0, 0, nil
local badgePlayer = { UserId = 7, Parent = true }
local badgeService = {
	UserHasBadgeAsync = function()
		return false
	end,
	AwardBadge = function()
		badgeCalls += 1
		assert(not badge.AwardBadge(badgePlayer, 123), "Concurrent badge call escaped pending guard")
		return badgeCalls == 3
	end,
}
badge = load(
	"src/server/systems/progression/BadgeModule.luau",
	{
		game = {
			GetService = function(_, name)
				return if name == "Players" then players else badgeService
			end,
		},
		task = {
			wait = function()
				attempts += 1
			end,
		},
	}
)
assert(badge.AwardBadge(badgePlayer, 123) and badgeCalls == 3 and attempts == 2)
assert(badge.AwardBadge(badgePlayer, 123) and badgeCalls == 3)
badgePlayer.Parent = nil
assert(not badge.AwardBadge(badgePlayer, 456))
print("PASS: bounded badge retries, concurrent deduplication, successful cache and departure guard")
