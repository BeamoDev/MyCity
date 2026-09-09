local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function signal()
	local fn
	return {
		Connect = function(_, callback)
			fn = callback
		end,
		Fire = function(_, ...)
			fn(...)
		end,
	}
end
local finished, removed = signal(), signal()
local now, calls, owned, fail, concurrent = 0, 0, false, false, nil
local player = { Parent = true, UserId = 100 }
local marketplace = { PromptGamePassPurchaseFinished = finished }
function marketplace:UserOwnsGamePassAsync(id, pass)
	assert(id == 100)
	calls += 1
	if concurrent then
		coroutine.yield()
	end
	if fail then
		error("Service unavailable")
	end
	return owned
end
local services = { MarketplaceService = marketplace, Players = { PlayerRemoving = removed } }
local ownership = luau.load(
	fs.readFile("src/server/services/GamePassOwnership.luau"),
	{
		environment = {
			game = {
				GetService = function(_, name)
					return services[name]
				end,
			},
			os = {
				clock = function()
					return now
				end,
			},
			task = {
				wait = function()
					coroutine.yield()
				end,
			},
		},
	}
)()
for i = 1, 100 do
	assert(not ownership.has(player, 1))
end
assert(calls == 1, "Repeated successful false queries")
finished:Fire(player, 1, true)
assert(ownership.has(player, 1) and calls == 1, "Purchase did not immediately update cache")
now = 61
owned = true
assert(ownership.has(player, 1) and calls == 2)
fail = true
assert(not ownership.has(player, 2))
assert(not ownership.has(player, 2))
assert(calls == 4, "Cached failure")
fail = false
-- Two callers share a single yielding service query.
concurrent = true
owned = false
local a, b
local first = coroutine.create(function()
	a = ownership.has(player, 3)
end)
local second = coroutine.create(function()
	b = ownership.has(player, 3)
end)
assert(coroutine.resume(first))
assert(coroutine.resume(second))
assert(calls == 5)
finished:Fire(player, 3, true)
assert(coroutine.resume(first))
assert(coroutine.resume(second))
assert(a == true and b == true, "Stale in-flight response overwrote purchased entitlement")
concurrent = nil
owned = false
removed:Fire(player)
assert(not ownership.has(player, 3) and calls == 6, "Departure retained cache")
player.Parent = nil
assert(not ownership.has(player, 3) and calls == 6)
print(
	"PASS: 100 repeated ownership requests use one API call; TTL, live purchase, service failure retry, concurrent lookup, purchase race and cleanup"
)
