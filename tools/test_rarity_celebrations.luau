local fs, luau = require("@lune/fs"), require("@lune/luau")

local source = fs.readFile("src/server/systems/world/VFX.luau")
local completion = fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionTimer/Completion.luau")
local skip = fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionSkipping.luau")
local schema = luau.load(fs.readFile("src/server/persistence/PlayerDataModule/DataSchema.luau"))()
local colors = {
	Rare = { R = 85 / 255, G = 170 / 255, B = 1 },
	Epic = { R = 212 / 255, G = 0, B = 212 / 255 },
	Legendary = { R = 1, G = 170 / 255, B = 0 },
	Mythic = { R = 1, G = 85 / 255, B = 1 },
	Luxury = { R = 125 / 255, G = 225 / 255, B = 235 / 255 },
}
local rarities = { "Rare", "Epic", "Legendary", "Mythic", "Luxury" }
local defaults = schema.CreateDefault("Tester", 0).PlayerData.PlayerInfo
for _, rarity in rarities do
	assert(defaults["First" .. rarity] and defaults["First" .. rarity].Value == false)
	assert(source:find(rarity .. ' = { flag = "First' .. rarity .. '"', 1, true))
end
assert(source:find("local color = RarityColors[rarity]", 1, true))
assert(source:find("local clone = definition.template:Clone()", 1, true))
assert(source:find("recolorEffect(clone, color)", 1, true))
assert(source:find("celebratedBuildings[building] = true", 1, true))
assert(completion:find("State.completedConstructions[constructionID] = true", 1, true))
local milestoneCall = completion:find("VFX.CheckAndPlayRarityEffect(player, newBuilding, rarity)", 1, true)
assert(milestoneCall)
assert(milestoneCall < completion:find("if not skipAnimation then", milestoneCall, true), "Skip branch precedes rarity milestone")
assert(not completion:find("and not skipAnimation then", 1, true), "Skip still bypasses rarity VFX")
assert(skip:find("ConstructionTimer.finishConstruction(", 1, true))
assert(skip:find("false,\n\t\ttrue,", 1, true), "Legitimate skip must enter shared completion with skipAnimation=true")

local spawned, clones, announcements = {}, {}, {}
local function node(children)
	children = children or {}
	function children:WaitForChild(name) return self[name] end
	function children:FindFirstChild(name) return self[name] end
	return children
end
local function visual(className)
	local object = { Color = "authored", Enabled = false, FillColor = "authored", OutlineColor = "authored" }
	function object:IsA(name) return name == className end
	return object
end
local function template(name)
	local original = { Name = name, Color = "authored" }
	function original:Clone()
		local descendants = {
			visual("ParticleEmitter"), visual("Beam"), visual("Trail"),
			visual("PointLight"), visual("Highlight"),
		}
		local clone = { Name = name, descendants = descendants }
		function clone:IsA(className) return className == "Part" end
		function clone:GetDescendants() return self.descendants end
		function clone:FindFirstChild() return nil end
		function clone:Destroy() self.destroyed = true end
		clones[#clones + 1] = clone
		return clone
	end
	return original
end
local rare, legendary = template("RareVFX"), template("LegendaryVFX")
local items = node({ RareVFX = rare, LegendaryVFX = legendary })
local events = node({
	VFX = node({ CameraShake = { FireClient = function() end } }),
	Notifications = node({ RarityAnnounce = { FireClient = function(_, _, rarity) announcements[#announcements + 1] = rarity end } }),
})
local replicated = node({ Assets = node({ Items = items }), Events = events, shared = { ui = { RarityColors = {} } } })
local lighting = { Atmosphere = { Density = 0, Glare = 0 }, ColorCorrection = { TintColor = "white" } }
function lighting:FindFirstChild(name) return self[name] end
local sfx = node({ RareBuilding = { Play = function() end }, LegendaryBuilding = { Play = function() end } })
local sound = node({ SFX = sfx })
local services = {
	TweenService = { Create = function() return { Play = function() end } end },
	Lighting = lighting,
	SoundService = sound,
	Players = { GetPlayers = function() return {} end },
	RunService = {},
	ReplicatedStorage = replicated,
}
local scriptNode = { Parent = { Parent = { Parent = { config = { TutorialConfig = {} } } } } }
local environment = {
	game = { GetService = function(_, name) return services[name] end },
	script = scriptNode,
	require = function(module)
		if module == replicated.shared.ui.RarityColors then return colors end
		return { OwnerUserId = 1790165114 }
	end,
	workspace = node({ Misc = node({ Effects = {} }) }),
	Color3 = { new = function(...) return { ... } end },
	ColorSequence = { new = function(color) return { value = color } end },
	CFrame = { new = function(position) return position end },
	TweenInfo = { new = function() return {} end },
	Enum = { EasingStyle = { Quad = "Quad" }, EasingDirection = { InOut = "InOut" } },
	task = { spawn = function(callback) spawned[#spawned + 1] = callback end, wait = function() end },
}
local vfx = luau.load(source, { environment = environment })()
local function player(id)
	local flags = {}
	for _, rarity in rarities do flags["First" .. rarity] = { Value = false } end
	local info = node(flags)
	local data = node({ PlayerInfo = info })
	local value = node({ Data = data, UserId = id, Name = "Tester" })
	return value, flags
end
local function building(name)
	return { Name = name, PrimaryPart = { Position = name }, GetAttribute = function(_, key) return if key == "BuildingType" then name else nil end }
end
local owner, ownerFlags = player(1790165114)
local normal, normalFlags = player(55)
for _, rarity in rarities do
	local first, second = building(rarity .. "1"), building(rarity .. "2")
	assert(vfx.CheckAndPlayRarityEffect(owner, first, rarity), rarity .. " owner first failed")
	assert(not vfx.CheckAndPlayRarityEffect(owner, first, rarity), rarity .. " duplicate played")
	assert(vfx.CheckAndPlayRarityEffect(owner, second, rarity), rarity .. " owner repeat failed")
	assert(ownerFlags["First" .. rarity].Value)
	assert(vfx.CheckAndPlayRarityEffect(normal, building(rarity .. "normal1"), rarity))
	assert(not vfx.CheckAndPlayRarityEffect(normal, building(rarity .. "normal2"), rarity))
	assert(normalFlags["First" .. rarity].Value)
end
assert(#spawned == #rarities * 3)
for _, callback in spawned do callback() end
assert(#clones == #spawned and rare.Color == "authored" and legendary.Color == "authored")
for _, clone in clones do
	local rarity
	for _, candidate in rarities do
		if clone.CFrame:sub(1, #candidate) == candidate then rarity = candidate break end
	end
	local expected = colors[rarity]
	for _, item in clone.descendants do
		if item:IsA("Highlight") then
			assert(item.FillColor == expected and item.OutlineColor == expected)
		elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
			assert(item.Color.value == expected, tostring(rarity) .. " sequence color mismatch: " .. tostring(item.Color.value) .. " / " .. tostring(expected))
		else
			assert(item.Color == expected)
		end
	end
end
assert(#announcements == 0, "Mock has no audience; no announcement should be sent")
print("PASS: owner repeats, regular first-only flags, all five rarity fallbacks, duplicate claim, and per-trigger clone colors")
