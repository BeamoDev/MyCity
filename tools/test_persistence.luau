local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local records = {}
local clock = 1000
local http = {
	JSONEncode = function(_, value)
		return serde.encode("json", value)
	end,
	JSONDecode = function(_, value)
		return serde.decode("json", value)
	end,
}
local database = {
	UpdateAsync = function(_, key, callback)
		local result = callback(records[key])
		if result ~= nil then
			records[key] = result
		end
		return result
	end,
}
local store = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/SessionStore.luau"), {
	environment = {
		game = {
			GetService = function(_, name)
				if name == "HttpService" then
					return http
				end
				assert(name == "DataStoreService")
				return {
					GetDataStore = function(_, namespace)
						assert(namespace == "Data_1")
						return database
					end,
				}
			end,
		},
		os = {
			time = function()
				return clock
			end,
		},
	},
})()
assert(store.acquire(123, "first"))
assert(not store.acquire(123, "second"), "Concurrent server acquired an active profile")
assert(store.save(123, "first", { PlayerData = { Cash = 42 } }, false))
clock += 181
local restored = store.acquire(123, "second")
assert(restored.PlayerData.Cash == 42)
assert(not store.save(123, "first", { PlayerData = {} }, false), "Stale session overwrote the city")
assert(store.save(123, "second", restored, true))
assert(store.acquire(123, "third"), "Release did not free the profile")
records["456"] = "malformed JSON"
assert(not pcall(store.acquire, 456, "bad"), "Corrupt data silently became defaults")
assert(records["456"] == "malformed JSON")

local codec = luau.load(
	fs.readFile("src/server/persistence/PlayerDataModule/ProfileCodec.luau"),
	{ environment = { Instance = roblox.Instance } }
)()
local folder = roblox.Instance.new("Folder")
codec.decodeFolder(
	{ PlayerInfo = { Tutorial_1 = { Nested = { Flag = { ClassName = "BoolValue", Name = "Flag", Value = true } } } } },
	folder,
	true
)
assert(folder.PlayerInfo.Tutorial.Nested.Flag.Value)
local encoded = codec.encodeFolder(folder)
local fresh = roblox.Instance.new("Folder")
codec.decodeFolder(encoded, fresh, false)
assert(fresh.PlayerInfo.Tutorial.Nested.Flag.Value, "Deep folder failed round trip")
local duplicate = roblox.Instance.new("BoolValue")
duplicate.Name = "Flag"
duplicate.Parent = fresh.PlayerInfo.Tutorial.Nested
assert(not pcall(codec.encodeFolder, fresh), "Ambiguous duplicate save keys were accepted")
print(
	"PASS: profile lease contention, expiry, stale writes, release, corrupt data refusal, legacy nesting, recursive round-trip, duplicate keys"
)

local function descriptor(value)
	return { Name = "Bank", Value = value }
end
local item, outcome = store.transferOffline(999, "Bank_1", false, "a", descriptor)
assert(item == nil and outcome == "missing")
records["999"] =
	http:JSONEncode({ PlayerData = { CurrentBuildings = {} }, Session = { Id = "busy", Expires = clock + 60 } })
item, outcome = store.transferOffline(999, "Bank_1", false, "a", descriptor)
assert(item == nil and outcome == "unavailable", "Active remote lease treated as absence")
records["999"] = http:JSONEncode({ PlayerData = { CurrentBuildings = {} } })
item, outcome = store.transferOffline(999, "Bank_1", false, "a", descriptor)
assert(item == nil and outcome == "missing")
records["999"] =
	http:JSONEncode({ PlayerData = { CurrentBuildings = { Bank_1 = { ClassName = "StringValue", Value = "saved" } } } })
assert(store.transferOffline(999, "Bank_1", false, "a", descriptor).Name == "Bank")
assert(
	store.transferOffline(999, "Bank_1", false, "a", descriptor).Name == "Bank",
	"Transfer retry lost durable descriptor"
)
records["999"] = http:JSONEncode({ PlayerData = {} })
item, outcome = store.transferOffline(999, "Bank_1", false, "a", descriptor)
assert(item == nil and outcome == "unavailable", "Malformed envelope treated as confirmed absence")
print("PASS: offline transfer confirmed absence, active lease, malformed folder and durable removal replay")
