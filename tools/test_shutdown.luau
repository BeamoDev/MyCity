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
	function t:GetAttribute(k)
		return self[k]
	end
	function t:SetAttribute(k, v)
		self[k] = v
	end
	return t
end
local function harness()
	local threads = {}
	local function spawn(fn, ...)
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, ...)
		assert(ok, err)
		if coroutine.status(thread) ~= "dead" then
			table.insert(threads, thread)
		end
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
					spawn(fn, ...)
				end
			end,
		}
	end
	local player = node({
		Parent = true,
		UserId = 7,
		Name = "Tester",
		Character = {},
		Data = node({ PlayerInfo = node({ CityName = { Value = "City" } }), PlotInfo = { Plot = { Value = 1 } } }),
	})
	local players = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		GetPlayers = function()
			return { player }
		end,
	}
	local binds, closing, rejected = 0, nil, false
	local game = {
		GetService = function()
			return players
		end,
		BindToClose = function(_, fn)
			binds += 1
			if rejected then
				error("model already closing")
			end
			closing = fn
		end,
	}
	local shutdown = load("src/server/bootstrap/Shutdown.luau", { game = game })
	local function drain()
		for _ = 1, 10 do
			local pending = threads
			threads = {}
			for _, thread in pending do
				local ok, err = coroutine.resume(thread)
				assert(ok, err)
				if coroutine.status(thread) ~= "dead" then
					table.insert(threads, thread)
				end
			end
			if #threads == 0 then
				return
			end
		end
		error("Shutdown work did not finish")
	end
	return {
		shutdown = shutdown,
		player = player,
		players = players,
		signal = signal,
		spawn = spawn,
		drain = drain,
		game = game,
		close = function()
			spawn(closing)
		end,
		binds = function()
			return binds
		end,
		reject = function()
			rejected = true
		end,
	}
end
local early = harness()
assert(early.shutdown.start() and early.shutdown.start() and early.binds() == 1)
early.close()
assert(early.shutdown.isClosing() and early.player.MyCityLeaving)
assert(not early.shutdown.bind(function()
	error("Late save registration ran")
end) and early.binds() == 1)
local rejected = harness()
rejected.reject()
assert(not rejected.shutdown.start() and rejected.shutdown.isClosing())

-- Real bootstrap exits if closing begins during preview preparation.
local boot = harness()
local rep = node({
	shared = node({ Network = { start = function() end } }),
	Events = { Loading = { IntroFinished = { OnServerEvent = boot.signal() } } },
})
local bootstrap = load("src/server/bootstrap/ServerBootstrap.luau", {
	game = {
		GetService = function()
			return rep
		end,
	},
	script = {
		Parent = {
			Shutdown = boot.shutdown,
			SpawnGuard = {
				start = function()
					assert(boot.binds() == 1)
				end,
				release = function() end,
			},
			WorldRuntime = {
				start = function()
					boot.close()
				end,
			},
		},
	},
	require = function(m)
		assert(m, "Startup continued after close")
		return m
	end,
	print = function() end,
})
bootstrap.start()
assert(boot.binds() == 1 and boot.shutdown.isClosing())

for _, scenario in { "canceled", "normal", "buildings_error", "badge_error", "quest_error" } do
	local delayed = scenario == "canceled"
	local h = harness()
	assert(h.shutdown.start())
	local loads, saves, abandoned, kicks, loaded = 0, 0, 0, 0, false
	function h.player:Kick()
		kicks += 1
	end
	local data = {
		setBeforeSave = function() end,
		loadPlayerData = function()
			loads += 1
			loaded = true
			if delayed then
				coroutine.yield()
			end
			return true
		end,
		isLoaded = function()
			return loaded
		end,
		abandon = function()
			abandoned += 1
			loaded = false
		end,
		savePlayerData = function(_, release)
			assert(release)
			saves += 1
			loaded = false
		end,
		forget = function() end,
	}
	local function noop() end
	local systems = {
		PlayerDataModule = data,
		InventorySystem = {
			saveInventory = noop,
			loadInventory = function()
				return true
			end,
			startPlayer = noop,
			cleanup = noop,
		},
		CityNameSystem = {
			loadCityName = function()
				return "City"
			end,
			applyCityNameToPlot = noop,
		},
		PlotManager = { assignPlot = noop, resetPlot = noop },
		BuildingSystem = { loadPlayerBuildings = noop, updatePlotStats = noop },
		ConstructionSystem = { loadPlayerConstructions = noop, clearPlayerConstructions = noop },
		ExpansionSystem = { updateExpansionTiles = noop },
		IncomeSystem = { setupPlayerIncome = noop, collectPendingIncome = noop, cleanupPlayer = noop },
		RebirthSystem = { initializePlayer = noop },
		TutorialSystem = { prepareForJoin = noop, resume = noop },
		PostTutorialQuest = { initializePlayer = noop },
		DailyQuests = { initializePlayer = noop },
		BadgeSystem = { AwardBadge = noop },
	}
	local expectedStage = if scenario == "buildings_error" then "Buildings" else "Quests"
	local failedLoad = scenario == "buildings_error" or scenario == "quest_error"
	if scenario == "buildings_error" then
		systems.BuildingSystem.loadPlayerBuildings = function()
			error("Missing authored building: Bank")
		end
	elseif scenario == "quest_error" then
		systems.DailyQuests.initializePlayer = function()
			error("Quest setup failed after readiness")
		end
	elseif scenario == "badge_error" then
		systems.BadgeSystem.AwardBadge = function()
			error("Optional badge failure")
		end
	end
	local root = {
		systems = {
			security = { RequestGuard = {
				isBusy = function()
					return false
				end,
			} },
			progression = { PlayerRewards = { trackMillionaire = noop, cleanup = noop } },
		},
		services = { RestoreBudget = { checkpoint = noop } },
	}
	local loading = {
		ClientReady = { OnServerEvent = h.signal() },
		LoadingProgress = { FireClient = noop },
		LoadingComplete = {
			FireClient = noop,
		},
	}
	local lifecycle = load("src/server/bootstrap/PlayerLifecycle.luau", {
		game = {
			GetService = function(_, name)
				return if name == "Players" then h.players else { Events = { Loading = loading } }
			end,
		},
		script = { Parent = { Parent = root, Shutdown = h.shutdown } },
		require = function(m)
			assert(m)
			return m
		end,
		workspace = { Plots = { Plot1 = {} } },
		task = { spawn = h.spawn, defer = h.spawn, wait = coroutine.yield },
		tick = function()
			return 0
		end,
		warn = function(message, _, stage, traceback)
			if failedLoad then
				assert(message == "[Lifecycle] Load failed for" and stage == "stage=" .. expectedStage)
				assert(type(traceback) == "string" and traceback:find("luau.load", 1, true), tostring(traceback))
			elseif scenario == "badge_error" then
				assert(message == "[Lifecycle] Join badge setup failed for")
			else
				error("Unexpected lifecycle warning")
			end
		end,
	})
	lifecycle.start(systems)
	lifecycle.start(systems)
	assert(loads == 1 and h.binds() == 1)
	if failedLoad then
		assert(h.player.MyCityLoadFailed and h.player.MyCityLoadErrorCode == "CITY_" .. expectedStage)
		assert(not h.player.MyCityLoaded and not h.player.MyCityInventoryReady)
	elseif not delayed then
		assert(h.player.MyCityLoaded and h.player.MyCityLoadStage == "Ready")
	end
	h.players.PlayerRemoving:Fire(h.player) -- Parent deliberately remains present during this signal.
	h.close()
	h.drain()
	assert(kicks == (if failedLoad then 1 else 0))
	if delayed or failedLoad then
		assert(abandoned == 1 and saves == 0 and not h.player.MyCityLoaded, "Canceled load saved partial data")
	else
		assert(saves == 1 and abandoned == 0, "Normal loaded player did not save exactly once")
	end
	h.players.PlayerAdded:Fire(h.player)
	assert(loads == 1, "Queued join restarted after departure/close")
end
print(
	"PASS: early shutdown, canceled loads, normal saves, stage/traceback diagnostics, readiness revoked on failure and optional badges cannot fail a join"
)
