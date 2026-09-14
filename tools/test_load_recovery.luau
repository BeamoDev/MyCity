-- Execute the real profile loader AND atomic store against a controllable clock/database.
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env })()
end
local function harness(options)
	options = options or {}
	local elapsed, calls, kicks, restores, releases = 0, 0, {}, 0, 0
	local raw = serde.encode("json", {
		PlayerData = { Inventory = { tool = "untouched" }, CurrentBuildings = { Bank_1 = "city" } },
		LeaderBoardData = { Cash = 12345 },
		Receipts = { paid = { Complete = true } },
		Session = if options.lock then { Id = "previous", Expires = 1000 + options.lock } else nil,
	})
	local player = { Parent = true, Name = "Returning", UserId = 42 }
	function player:SetAttribute(key, value)
		self[key] = value
	end
	function player:GetAttribute(key)
		return self[key]
	end
	function player:Kick(message)
		table.insert(kicks, message)
	end
	local clock = {
		time = function()
			return 1000 + math.floor(elapsed)
		end,
		clock = function()
			return elapsed
		end,
	}
	local taskMock = {
		wait = function(seconds)
			elapsed += seconds or 0.01
			if options.cancel and elapsed >= options.cancel then
				player.MyCityLeaving = true
			end
			if options.unlock and elapsed >= options.unlock then
				local record = serde.decode("json", raw)
				if record.Session and record.Session.Id == "previous" then
					record.Session = nil
					raw = serde.encode("json", record)
				end
			end
		end,
	}
	local http = {
		GenerateGUID = function()
			return "joining"
		end,
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, v)
			return serde.decode("json", v)
		end,
	}
	local db = {
		UpdateAsync = function(_, key, callback)
			assert(key == "42")
			calls += 1
			if options.outage or calls <= (options.errors or 0) then
				error("Storage unavailable")
			end
			local value = callback(raw)
			if value then
				local record = serde.decode("json", value)
				if not record.Session then
					releases += 1
					if releases <= (options.releaseErrors or 0) then
						error("Release throttled")
					end
				end
				raw = value
				if options.lostResponse and calls == 1 then
					error("Response lost after commit")
				end
			end
			return value
		end,
	}
	local gameMock = {
		GetService = function(_, name)
			if name == "HttpService" then
				return http
			end
			if name == "DataStoreService" then
				return {
					GetDataStore = function(_, namespace)
						assert(namespace == "Data_1")
						return db
					end,
				}
			end
			return {}
		end,
	}
	local store = load("src/server/persistence/PlayerDataModule/SessionStore.luau", { game = gameMock, os = clock })
	local loader = load("src/server/persistence/PlayerDataModule/init.luau", {
		game = gameMock,
		os = clock,
		task = taskMock,
		warn = function() end,
		require = function(m)
			return m
		end,
		script = {
			SessionStore = store,
			OwnerReset = {
				apply = function(_, record)
					if options.reset then
						record = table.clone(record)
						record.PlayerData = {}
					end
					return record
				end,
			},
			DataSchema = {
				Normalize = function(record)
					return record
				end,
			},
			SchemaMigration = function() end,
			ProfileCodec = {
				restore = function()
					restores += 1
					if options.restoreError then
						error("Bad saved city")
					end
					-- Plain objects allow parenting to the mock player.
					return { Destroy = function() end }, { Destroy = function() end }
				end,
			},
			Parent = { Parent = { systems = { security = { RequestGuard = {} } } } },
		},
	})
	return {
		loader = loader,
		store = store,
		player = player,
		kicks = kicks,
		elapsed = function()
			return elapsed
		end,
		calls = function()
			return calls
		end,
		restores = function()
			return restores
		end,
		releases = function()
			return releases
		end,
		record = function()
			return serde.decode("json", raw)
		end,
		raw = function()
			return raw
		end,
	}
end

-- Old six-second retry window could never recover either of these joins.
for _, options in { { lock = 180, unlock = 20 }, { lock = 180 } } do
	local h = harness(options)
	assert(h.loader.loadPlayerData(h.player) and #h.kicks == 0)
	assert(h.elapsed() >= (options.unlock or 180) and h.elapsed() <= 190)
	assert(h.restores() == 1 and h.record().LeaderBoardData.Cash == 12345)
	assert(h.record().Session.Id == "joining")
end

local busy = harness({ lock = 500 })
local original = busy.raw()
assert(not busy.loader.loadPlayerData(busy.player))
assert(busy.elapsed() == 190 and busy.restores() == 0 and busy.raw() == original)
assert(#busy.kicks == 1 and busy.kicks[1]:find("LOAD_SESSION", 1, true))
assert(busy.calls() <= 40, "Lock polling exceeded its bounded request budget")

local canceled = harness({ lock = 180, cancel = 0.5 })
assert(not canceled.loader.loadPlayerData(canceled.player))
assert(canceled.elapsed() == 0.5 and canceled.restores() == 0 and #canceled.kicks == 0)
assert(canceled.record().Session.Id == "previous")

local temporary = harness({ errors = 3 })
assert(temporary.loader.loadPlayerData(temporary.player) and temporary.elapsed() == 14 and #temporary.kicks == 0)
local outage = harness({ outage = true })
local untouched = outage.raw()
assert(not outage.loader.loadPlayerData(outage.player))
assert(outage.elapsed() < 40 and outage.restores() == 0 and outage.raw() == untouched)
assert(outage.kicks[1]:find("LOAD_SERVICE", 1, true))

local ambiguous = harness({ lostResponse = true })
assert(ambiguous.loader.loadPlayerData(ambiguous.player) and ambiguous.restores() == 1)
assert(ambiguous.calls() == 2 and ambiguous.record().Session.Id == "joining")

local failed = harness({ restoreError = true, releaseErrors = 2 })
assert(not failed.loader.loadPlayerData(failed.player) and failed.releases() == 3)
assert(failed.record().Session == nil and failed.record().PlayerData.Inventory.tool == "untouched")
assert(failed.kicks[1]:find("LOAD_RESTORE", 1, true))

local abandoned = harness({ reset = true })
assert(abandoned.loader.loadPlayerData(abandoned.player))
abandoned.loader.getRecord(abandoned.player).Receipts = {}
abandoned.loader.abandon(abandoned.player)
assert(not abandoned.loader.isLoaded(abandoned.player))
assert(abandoned.record().Session == nil and abandoned.record().Receipts.paid.Complete)
assert(abandoned.record().PlayerData.CurrentBuildings.Bank_1 == "city", "Partial restoration replaced saved city")

local stale = harness()
assert(stale.loader.loadPlayerData(stale.player))
assert(stale.store.release(42, "joining"))
assert(stale.store.acquire(42, "new-server"))
local newer = stale.raw()
stale.loader.abandon(stale.player)
assert(stale.raw() == newer, "Abandonment released a newer session")

print(
	"PASS: automatic session handoff/expiry, bounded contention/outage, cancellation, lost-response retry, release retries, original-city preservation and stale-release protection"
)
