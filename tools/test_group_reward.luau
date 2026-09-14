local fs, luau = require("@lune/fs"), require("@lune/luau")
local function node(fields)
	fields = fields or {}
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end
local now, notices, saves, checks, created = 0, 0, 0, 0, {}
local member, lookupFailures, unavailable, saveResult = true, 0, false, true
local onLookup, onWait
local player = node({ Parent = true, UserId = 1, attributes = { MyCityLoaded = true } })
function player:GetAttribute(name)
	return self.attributes[name]
end
function player:IsInGroup(id)
	assert(id == 1050526813)
	checks += 1
	if onLookup then
		local fn = onLookup
		onLookup = nil
		fn()
	end
	if lookupFailures > 0 then
		lookupFailures -= 1
		error("temporary group lookup failure")
	end
	return member
end
local info = node({ Tutorial = node({ IsInTutorial = { Value = true } }), GroupRewardClaimed = { Value = false } })
player.Data = node({ PlayerInfo = info })
player.Backpack = node({ Parent = player })
local guard = luau.load(fs.readFile("src/server/systems/security/RequestGuard.luau"), {
	environment = { os = {
		clock = function()
			return now
		end,
	} },
})()
local factory = {
	create = function(name, collected, level, xp)
		assert(name == "PoliceStation" and collected == false and level == 1 and xp == 0)
		if unavailable then
			return nil
		end
		local tool = {
			Destroy = function(self)
				self.destroyed = true
			end,
		}
		table.insert(created, tool)
		return tool
	end,
}
local data = {
	savePlayerData = function(p)
		saves += 1
		assert(p == player and info.GroupRewardClaimed.Value)
		assert(created[#created].Parent == player.Backpack, "Claim saved without its inventory tool")
		return saveResult
	end,
}
local root = { services = { ToolFactory = factory }, persistence = { PlayerDataModule = data } }
local systems = { Parent = root, security = { RequestGuard = guard } }
local env = {
	script = { Parent = { Parent = systems, BadgeModule = {} } },
	require = function(value)
		return value
	end,
	game = {
		GetService = function()
			return {
				Events = {
					Notifications = {
						GroupReward = {
							FireClient = function(_, p)
								assert(p == player and not info.Tutorial.IsInTutorial.Value)
								notices += 1
							end,
						},
					},
				},
			}
		end,
	},
	task = {
		wait = function(seconds)
			now += seconds
			if onWait then
				local fn = onWait
				onWait = nil
				fn()
			end
		end,
	},
}
local rewards = luau.load(fs.readFile("src/server/systems/progression/PlayerRewards.luau"), { environment = env })()
rewards.giveGroupReward(player)
assert(checks == 0 and #created == 0 and notices == 0, "Granted during tutorial")
info.Tutorial.IsInTutorial.Value = false
member = false
rewards.giveGroupReward(player)
assert(#created == 0 and not info.GroupRewardClaimed.Value, "Non-member received reward")
member, lookupFailures = true, 1
onLookup = function()
	rewards.giveGroupReward(player)
end
rewards.giveGroupReward(player)
assert(#created == 1 and saves == 1 and notices == 1 and info.GroupRewardClaimed.Value)
rewards.giveGroupReward(player)
assert(#created == 1 and saves == 1 and notices == 1, "Duplicate readiness granted twice")
-- Persisted claim remains authoritative after rejoin, even with an empty backpack.
player.Backpack = node({ Parent = player })
rewards.giveGroupReward(player)
assert(#created == 1)
-- A missing backpack defers rather than claiming or hanging indefinitely.
info.GroupRewardClaimed.Value = false
player.Backpack = nil
onWait = function()
	player.Backpack = node({ Parent = player })
end
now += 1
rewards.giveGroupReward(player)
assert(#created == 2 and notices == 2)
-- Failed save retains the in-session grant/marker so autosave can retry without duplication.
info.GroupRewardClaimed.Value, saveResult = false, false
now += 1
rewards.giveGroupReward(player)
rewards.giveGroupReward(player)
assert(#created == 3 and info.GroupRewardClaimed.Value and notices == 3)
-- Membership lookup yields: leaving or reentering tutorial prevents the later grant.
info.GroupRewardClaimed.Value = false
onLookup = function()
	player.attributes.MyCityLeaving = true
end
rewards.giveGroupReward(player)
assert(#created == 3 and not info.GroupRewardClaimed.Value)
player.attributes.MyCityLeaving = nil
onLookup = function()
	info.Tutorial.IsInTutorial.Value = true
end
rewards.giveGroupReward(player)
assert(#created == 3 and not info.GroupRewardClaimed.Value)
print(
	"PASS: group membership, post-tutorial-only grant, lookup retry, concurrent/duplicate/rejoin protection, backpack recovery, shared save marker and departure recheck"
)
