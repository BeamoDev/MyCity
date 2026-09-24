local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local function load(name, env)
	return luau.load(fs.readFile(name), { environment = env or {} })()
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }
			table.insert(list, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in list do
				if entry.active then
					entry.fn(...)
				end
			end
		end,
	}
end
local function node(t)
	t = t or {}
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:WaitForChild(name)
		return assert(self[name], name)
	end
	function t:GetChildren()
		return self.children or {}
	end
	function t:GetAttribute(name)
		return self[name]
	end
	function t:SetAttribute(name, value)
		self[name] = value
	end
	return t
end
local function child(parent, class, name)
	local v = r.Instance.new(class)
	v.Name = name
	v.Parent = parent
	return v
end
-- Authoritative building templates do not need to exist in ReplicatedStorage.
local workspace = child(nil, "Folder", "Workspace")
local storage, replicated = child(nil, "Folder", "ServerStorage"), child(nil, "Folder", "ReplicatedStorage")
local models = child(storage, "Folder", "Buildings")
local model = child(models, "Model", "Bank")
local base = child(model, "Part", "Base")
base.Size = r.Vector3.new(5, 1, 5)
base.CFrame = r.CFrame.new(10, 0.5, 20) * r.CFrame.Angles(0, math.rad(90), 0)
model.PrimaryPart = base
local tower = child(child(model, "Folder", "Build"), "Part", "Tower")
tower.Size, tower.Anchored = r.Vector3.new(3, 8, 3), true
tower.CFrame = base.CFrame * r.CFrame.new(0, 4.5, 0)
child(model, "Script", "EmbeddedBehavior")
child(base, "ProximityPrompt", "OldPrompt")
local assets0 = child(replicated, "Folder", "Assets")
local hitboxAssets = child(assets0, "Folder", "Hitbox")
child(child(hitboxAssets, "Attachment", "PlaceVFX"), "ParticleEmitter", "Burst")
child(hitboxAssets, "Attachment", "VFX")
child(assets0, "BillboardGui", "IncomeAlert").Enabled = true
local frames = 0
for index = 1, 23 do
	local copy = model:Clone()
	copy.Name, copy.Parent = "Building" .. index, models
end
local services = {
	ServerStorage = storage,
	ReplicatedStorage = replicated,
	RunService = { Heartbeat = {
		Wait = function()
			frames += 1
		end,
	} },
}
-- Non-building models kept in ServerStorage.Buildings (e.g. PlotScenary) are left alone.
local scenery = child(models, "Model", "PlotScenary1")
local sceneryPart = child(scenery, "Part", "Tree")
sceneryPart.Anchored = true
scenery.PrimaryPart = sceneryPart
local warnings = {}
local templates = load("src/server/services/BuildingTemplates.luau", {
	Instance = r.Instance,
	Vector3 = r.Vector3,
	CFrame = r.CFrame,
	Enum = r.Enum,
	warn = function(message)
		table.insert(warnings, message)
	end,
})
local siteBase = child(child(child(assets0, "Folder", "Constructions"), "Model", "5x5"), "Part", "Base")
siteBase.Size = r.Vector3.new(5, 1, 5)
local catalogue = { Bank = { Size = "5x5" }, Ghost = { Size = "5x5" } }
for index = 1, 23 do
	catalogue["Building" .. index] = { Size = if index == 23 then "9x9" else "5x5" }
end
local world = load("src/server/bootstrap/WorldRuntime.luau", {
	script = {
		Parent = { Parent = { services = { BuildingTemplates = templates }, config = { BuildingConfig = catalogue } } },
	},
	require = function(module)
		return module
	end,
	workspace = workspace,
	os = {
		clock = function()
			return 0
		end,
	},
	Instance = r.Instance,
	game = {
		GetService = function(_, name)
			return services[name]
		end,
	},
	task = {
		wait = function()
			frames += 1
		end,
	},
})
world.start()
local preview = replicated.Assets.BuildingPreviews.Bank
assert(preview.PrimaryPart and preview.Base.Size == base.Size and preview.Base.Anchored)
assert(not preview:FindFirstChild("EmbeddedBehavior") and not preview.Base:FindFirstChild("OldPrompt"))
assert(model:FindFirstChild("EmbeddedBehavior") and model.Base:FindFirstChild("OldPrompt"))
assert(workspace.Misc.PlayerAnchors and workspace.Misc.PlayerPreviews and workspace.Misc.Effects and frames == 3)
world.start()
assert(#replicated.Assets.BuildingPreviews:GetChildren() == 24 and frames == 3)
assert(#warnings == 2, "Audit reports exactly the missing model and unknown Size: " .. table.concat(warnings, " | "))
assert(not scenery:FindFirstChild("Hitbox") and sceneryPart.Anchored and sceneryPart.Name == "Tree", "Scenery was modified")
assert(not replicated.Assets.BuildingPreviews:FindFirstChild("PlotScenary1"), "Scenery got a placement preview")
assert(warnings[1]:find("Building23") and warnings[1]:find("9x9") and warnings[2]:find("Ghost"))
siteBase.Size = r.Vector3.new(10, 1, 10)
catalogue.Ghost, catalogue.Building23 = nil, { Size = "5x5" }
local problems = templates.audit(models, catalogue, replicated.Assets)
assert(#problems == 24 and problems[1]:find("5x5 construction site is 10x10"), problems[1])
siteBase.Size = r.Vector3.new(5, 1, 5)
table.clear(warnings)
print(
	"PASS: ServerStorage models, stripped client preview copies, retained authored parts, idempotent Workspace.Misc folders"
)

-- Base + visual parts become a complete template: Hitbox, Assets.Hitbox VFX, IncomeAlert and welds.
local function near(a, b)
	return (a - b).Magnitude < 1e-3
end
local hitbox = model:FindFirstChild("Hitbox")
assert(hitbox and hitbox:IsA("Part") and hitbox.Transparency == 1 and not hitbox.CanCollide and not hitbox.CanQuery)
assert(near(hitbox.Size, r.Vector3.new(5, 9, 5)), "Hitbox must span Base and the building: " .. tostring(hitbox.Size))
assert(near(hitbox.CFrame.Position, base.CFrame * r.Vector3.new(0, 4, 0)), "Hitbox must be centred on the building")
assert(hitbox.PlaceVFX.Burst and hitbox.VFX and hitboxAssets.PlaceVFX.Burst.Parent == hitboxAssets.PlaceVFX)
local alert = model:FindFirstChild("IncomeAlert")
assert(alert and alert:IsA("BillboardGui") and alert.Adornee == hitbox and not alert.Enabled)
assert(model.PrimaryPart == base and base.Anchored and not tower.Anchored and not hitbox.Anchored)
local welded = {}
for _, joint in base:GetChildren() do
	if joint:IsA("WeldConstraint") then
		assert(joint.Part0 == base)
		welded.tower = welded.tower or joint.Part1 == tower
		welded.hitbox = welded.hitbox or joint.Part1 == hitbox
	end
end
assert(welded.tower and welded.hitbox, "Every part must ride on Base for completion tweens")
local placed = models.Building23
assert(placed.Hitbox and placed.IncomeAlert and placed.Hitbox.VFX, "Every template is prepared")
assert(preview.Hitbox and preview.Hitbox.Anchored and not preview:FindFirstChild("IncomeAlert"))
local cloned = model:Clone()
assert(cloned.IncomeAlert.Adornee == cloned.Hitbox, "Clones must adorn their own Hitbox")
local weldCount = #base:GetChildren()
assert(templates.prepare(model, replicated.Assets) and #base:GetChildren() == weldCount and #model:GetChildren() == 5)

-- An existing authored Hitbox/alert is reused; a model without Base/PrimaryPart is refused once.
local legacy = child(models, "Model", "Legacy")
local legacyBase = child(legacy, "Part", "Floor")
legacy.PrimaryPart = legacyBase
local ownHitbox = child(legacy, "Part", "Hitbox")
local ownAlert = child(legacy, "BillboardGui", "IncomeAlert")
assert(templates.prepare(legacy, replicated.Assets))
assert(legacyBase.Name == "Base" and legacy.Hitbox == ownHitbox and legacy.IncomeAlert == ownAlert and ownHitbox.VFX)
local broken = child(models, "Model", "Broken")
child(broken, "Part", "Wall")
assert(not templates.prepare(broken, replicated.Assets) and not templates.prepare(broken, replicated.Assets))
assert(#warnings == 1 and warnings[1]:find("Broken"), "Missing Base warns once")
print("PASS: generated Hitbox bounds, Assets.Hitbox VFX, Assets.IncomeAlert, Base welds, idempotence and legacy reuse")

local added, removing = signal(), signal()
local root = child(workspace, "Part", "HumanoidRootPart")
local character = node({ HumanoidRootPart = root, ChildAdded = signal() })
local player = node({ Parent = true, Character = character, CharacterAdded = signal(), Parent = true })
local players = {
	PlayerAdded = added,
	PlayerRemoving = removing,
	GetPlayers = function()
		return { player }
	end,
}
local guard = load(
	"src/server/bootstrap/SpawnGuard.luau",
	{ Vector3 = r.Vector3, game = {
		GetService = function()
			return players
		end,
	} }
)
guard.start()
guard.start()
assert(root.Anchored and root:GetAttribute("MyCitySpawnHeld"))
guard.release(player)
assert(root.Anchored, "Unloaded player escaped spawn hold")
local nextRoot = child(workspace, "Part", "HumanoidRootPart")
nextRoot.Anchored = true
local replacement = node({ ChildAdded = signal() })
player.CharacterAdded:Fire(replacement)
replacement.ChildAdded:Fire(nextRoot)
player.MyCityLoaded = true
guard.release(player)
assert(not root.Anchored and nextRoot.Anchored and player.MyCityPlaying)
assert(not root:GetAttribute("MyCitySpawnHeld"))
local future = child(workspace, "Part", "HumanoidRootPart")
player.CharacterAdded:Fire(node({ HumanoidRootPart = future, ChildAdded = signal() }))
assert(not future.Anchored, "Normal respawn was held after Play")
print(
	"PASS: pre-data spawn hold, late roots/respawn during loading, rejected early release, original anchored state restored and post-Play respawns released"
)

-- Loading screen/camera/controls begin without network or Data dependencies.
local function screen(name, enabled)
	local value = node({ Name = name, Enabled = enabled, Parent = true, ChildAdded = signal(), changed = signal() })
	function value:IsA(class)
		return class == "ScreenGui"
	end
	function value:GetPropertyChangedSignal()
		return self.changed
	end
	return value
end
local hud, inventory, tutorial = screen("HUD", true), screen("Satchel", false), screen("Tutorial", false)
local function frame(name)
	return {
		Name = name,
		Parent = tutorial,
		Visible = false,
		IsA = function(_, class)
			return class == "GuiObject"
		end,
	}
end
tutorial.Loading, tutorial.IntroFrame = frame("Loading"), frame("IntroFrame")
tutorial.children = { tutorial.Loading, tutorial.IntroFrame }
local gui = node({ children = { hud, inventory, tutorial }, ChildAdded = signal() })
local client = node({ PlayerGui = gui })
local core, bound, cameraStarts, cameraStops = true, false, 0, 0
local cameraModule = {
	start = function()
		cameraStarts += 1
	end,
	restore = function()
		cameraStops += 1
	end,
}
local earlyServices = {
	Players = { LocalPlayer = client },
	StarterGui = {
		GetCoreGuiEnabled = function()
			return core
		end,
		SetCoreGuiEnabled = function(_, _, value)
			core = value
		end,
	},
	ContextActionService = {
		BindActionAtPriority = function()
			bound = true
		end,
		UnbindAction = function()
			bound = false
		end,
	},
	Lighting = {},
	RunService = {},
}
local earlyEnvironment = {
	script = { Parent = { Parent = { controllers = { intro = { IntroController = { Camera = cameraModule } } } } } },
	require = function(module)
		return module
	end,
	game = {
		GetService = function(_, name)
			return assert(earlyServices[name], "Early loading waited for " .. name)
		end,
	},
	workspace = {},
	Enum = {
		ContextActionResult = { Sink = "Sink" },
		PlayerActions = {
			GetEnumItems = function()
				return {}
			end,
		},
		CoreGuiType = { Backpack = "Backpack" },
	},
}
local early = load("src/client/bootstrap/EarlyLoading.luau", earlyEnvironment)
early.start()
early.start()
assert(
	cameraStarts == 0
		and bound
		and not core
		and not hud.Enabled
		and tutorial.Enabled
		and tutorial.Loading.Visible
		and not tutorial.IntroFrame.Visible
)
inventory.Enabled = true
inventory.changed:Fire()
assert(not inventory.Enabled)
local lateGui = screen("LateInventory", true)
gui.ChildAdded:Fire(lateGui)
assert(not lateGui.Enabled)
early.finish()
assert(core and not bound and hud.Enabled and inventory.Enabled and lateGui.Enabled and not client.MyCityIntroActive)
assert(cameraStops == 0, "EarlyLoading must not own or restore the intro camera")
core = true
client.MyCitySatchelActive = true
local withSatchel = load("src/client/bootstrap/EarlyLoading.luau", earlyEnvironment)
withSatchel.start()
withSatchel.finish()
assert(not core, "Loading restored Roblox backpack on top of Satchel")

print(
	"PASS: early loading precedes network/data, immediate authored screen, no second camera owner, hidden HUD/core/custom inventory, late UI suppression and single handoff"
)

local triggered = signal()
local prompt = {
	IsA = function(_, class)
		return class == "ProximityPrompt"
	end,
	Triggered = triggered,
}
local shopMap =
	node({ Interactives = node({ BuyArea = node({ Model = node({ Prompt = node({ ShopPrompt = prompt }) }) }) }) })
local opened = 0
local buyer = node({
	Parent = true,
	MyCityLoaded = false,
	Data = { PlayerInfo = { Tutorial = { IsInTutorial = { Value = false } } } },
})
local shopBinding = load("src/server/bootstrap/ShopPrompt.luau", {
	workspace = node({ Map = shopMap }),
	script = {
		Parent = {
			Parent = {
				systems = {
					security = {
						RequestGuard = {
							ready = function(p)
								return p.MyCityLoaded == true
							end,
						},
					},
				},
			},
		},
	},
	require = function(v)
		return v
	end,
	game = {
		GetService = function()
			return {
				Events = {
					UI = {
						OpenItemShop = {
							FireClient = function(_, p)
								assert(p == buyer)
								opened += 1
							end,
						},
					},
				},
			}
		end,
	},
})
shopBinding.start()
shopBinding.start()
triggered:Fire(buyer)
assert(opened == 0)
buyer.MyCityLoaded = true
buyer.Data.PlayerInfo.Tutorial.IsInTutorial.Value = true
triggered:Fire(buyer)
assert(opened == 0)
buyer.Data.PlayerInfo.Tutorial.IsInTutorial.Value = false
triggered:Fire(buyer)
assert(opened == 1)
print("PASS: buy-area prompt exact hierarchy, single binding, unloaded/tutorial rejection and normal shop opening")
