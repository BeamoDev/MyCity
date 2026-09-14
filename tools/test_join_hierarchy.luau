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
model.PrimaryPart = base
child(model, "Script", "EmbeddedBehavior")
child(base, "ProximityPrompt", "OldPrompt")
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
local world = load("src/server/bootstrap/WorldRuntime.luau", {
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
print(
	"PASS: ServerStorage models, stripped client preview copies, unchanged authored templates, idempotent Workspace.Misc folders"
)

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
