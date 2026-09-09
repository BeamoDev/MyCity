-- Executes the actual network module against a mock instance tree; no Roblox APIs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local source = fs.readFile("src/shared/Network.luau")
local created = 0
local function instance(className)
	created += 1
	local self = { ClassName = className, Name = className, children = {} }
	function self:IsA(expected)
		return self.ClassName == expected
	end
	function self:FindFirstChild(name)
		return self.children[name]
	end
	function self:WaitForChild(name, timeout)
		assert(type(timeout) == "number" and timeout >= 0 and timeout <= 60, "Network used an unbounded wait")
		if self.timeout then
			return nil
		end
		while not self.children[name] do
			coroutine.yield(name)
		end
		return self.children[name]
	end
	function self:GetFullName()
		return self.Name
	end
	return setmetatable(self, {
		__newindex = function(object, key, value)
			if key == "Parent" then
				value.children[object.Name] = object
			end
			rawset(object, key, value)
		end,
	})
end

local function loadNetwork(storage, server)
	return luau.load(source, {
		environment = {
			game = {
				GetService = function(_, name)
					if name == "ReplicatedStorage" then
						return storage
					end
					assert(name == "RunService")
					return {
						IsServer = function()
							return server
						end,
					}
				end,
			},
			Instance = { new = instance },
		},
	})()
end

local storage = instance("ReplicatedStorage")
local server = loadNetwork(storage, true)
server.start()
local registry = {}
local events, functions = 0, 0
local function inspect(parent, path)
	for name, child in parent.children do
		local fullPath = path .. "." .. name
		registry[fullPath] = child
		if child:IsA("Folder") then
			inspect(child, fullPath)
		elseif child:IsA("RemoteEvent") then
			assert(string.sub(fullPath, 1, 7) == ".Events")
			events += 1
		else
			assert(child:IsA("RemoteFunction") and string.sub(fullPath, 1, 10) == ".Functions")
			functions += 1
		end
	end
end
inspect(storage, "")
assert(events == 85 and functions == 2, "Unexpected remote inventory")
assert(registry[".Functions.Friends.GetFriendBoost"])
assert(registry[".Events.DailyQuests.Claim"] and registry[".Events.DailyQuests.Update"])
assert(registry[".Events.Sell.SoldWithProfit"] and registry[".Events.Notifications.RarityAnnounce"])
assert(not registry[".Events.Friends.GetFriendBoost"])
local unrelated = instance("Folder")
unrelated.Name = "AuthoredAssets"
unrelated.Parent = storage
local count = created
server.start()
assert(created == count and storage.children.AuthoredAssets == unrelated, "Repeat startup replaced instances")
for path, child in registry do
	local current = storage
	for name in string.gmatch(path, "[^.]+") do
		current = assert(current.children[name])
	end
	assert(current == child, "Repeat startup replaced " .. path)
end

-- Folders exist but one leaf has not replicated: the client must still wait.
local notifications = registry[".Events.Notifications"]
local rarity = notifications.children.RarityAnnounce
notifications.children.RarityAnnounce = nil
local client = loadNetwork(storage, false)
local finished = false
local waiting = coroutine.create(function()
	client.wait()
	finished = true
end)
local ok, missing = coroutine.resume(waiting)
assert(ok and missing == "RarityAnnounce" and not finished)
assert(created == count, "Client created a replacement remote")
notifications.children.RarityAnnounce = rarity
ok, missing = coroutine.resume(waiting)
assert(ok, missing)
assert(finished and coroutine.status(waiting) == "dead")
assert(not pcall(client.start), "Client was allowed to create remotes")

-- A malformed existing object fails clearly instead of destroying it/listeners.
rarity.ClassName = "Folder"
local success, message = pcall(server.start)
assert(not success and string.find(message, "must be a RemoteEvent", 1, true))
assert(notifications.children.RarityAnnounce == rarity)
rarity.ClassName = "RemoteEvent"
server.start()
print(
	"PASS: 81 events + 2 functions; empty startup, idempotence, preserved instances, partial replication, server-only creation, class mismatch"
)

-- Missing root gets a bounded startup diagnostic without creating client remotes.
local empty = instance("ReplicatedStorage")
empty.timeout = true
local timedOut, reason = pcall(loadNetwork(empty, false).wait)
assert(not timedOut and string.find(reason, "Startup timed out waiting for", 1, true))
assert(next(empty.children) == nil)
print("PASS: explicit replication deadline and actionable missing-root startup error")
