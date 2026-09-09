local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, active = true }
			table.insert(listeners, entry)
			return {
				Disconnect = function()
					entry.active = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in listeners do
				if entry.active then
					entry.fn(...)
				end
			end
		end,
	}
end
local function node(t)
	function t:WaitForChild(name)
		return assert(self[name], name)
	end
	function t:FindFirstChild(name)
		return self[name]
	end
	return t
end
local attributes, changes = {}, {}
local player = { Character = node({}), Backpack = {} }
function player:GetAttribute(name)
	return attributes[name]
end
function player:GetAttributeChangedSignal(name)
	changes[name] = changes[name] or signal()
	return changes[name]
end
function player:SetAttribute(name, value)
	attributes[name] = value
	self:GetAttributeChangedSignal(name):Fire()
end
local cleanupRemote = signal()
local templates = node({})
local rejected, invokes = 0, 0
local replicated = {
	Assets = { BuildingPreviews = templates },
	Events = {
		Movement = {
			CleanupPreview = { OnClientEvent = cleanupRemote },
			CannotPlace = {
				FireServer = function()
					rejected += 1
				end,
			},
		},
	},
	Functions = { PlaceBlock = {} },
}
local previewCount = 0
local base = { CFrame = r.CFrame.new(0, 1.25, 0) }
local destroyed = {}
local templateBase = { CFrame = r.CFrame.new(0, 0, 0) }
templates.Bank = node({ Base = templateBase, PrimaryPart = { CFrame = r.CFrame.new(0, 2, 0) } })
function templates.Bank:Clone()
	previewCount += 1
	local index = previewCount
	local preview = node({ Base = base })
	function preview:Destroy()
		destroyed[index] = true
	end
	function preview:SetPrimaryPartCFrame(cf)
		base.CFrame = cf
	end
	return preview
end
local tool = {
	Name = "Bank",
	Parent = player.Character,
	Equipped = signal(),
	Unequipped = signal(),
	AncestryChanged = signal(),
	Destroying = signal(),
}
player.Character.Bank = tool
local state = { connections = {}, tileHighlights = {} }
local restores, disconnects, uiAcquires = 0, 0, 0
local sellChanged = signal()
local sell = {
	Visible = false,
	GetPropertyChangedSignal = function(_, name)
		assert(name == "Visible")
		return sellChanged
	end,
}
local hud = node({ Frames = node({ SellTool = sell }) })
local playerGui = { ChildAdded = signal(), ChildRemoved = signal() }
local context = {
	playerGui = playerGui,
	State = {},
	HUD = hud,
	Session = {},
	state = state,
	player = player,
	tool = tool,
	ReplicatedStorage = replicated,
	initializedTools = {},
	cooldown = { expires = 0 },
	PLACEMENT_DEBOUNCE_TIME = 0,
	SoundService = node({}),
	disableOtherUI = function()
		uiAcquires += 1
	end,
	restoreUI = function()
		restores += 1
	end,
	clearTileHighlights = function() end,
	checkPlacementAccess = function()
		return true
	end,
	getPlayerPlot = function()
		return {}
	end,
	calculatePlotBounds = function()
		return {}
	end,
	preparePreviewModel = function() end,
	createTileHighlights = function() end,
	addBuildingIndicators = function() end,
	findValidSpawnPosition = function()
		return r.Vector3.new(0, 1.25, 0)
	end,
	updateBuildingVisuals = function()
		state.canPlace = true
	end,
	setupControls = function()
		state.connections.render = {
			Disconnect = function()
				disconnects += 1
			end,
		}
	end,
}
local taskMock = { wait = coroutine.yield, spawn = function() end }
local function load(path, environment)
	return luau.load(fs.readFile(path), { environment = environment or {} })()
end
load(
	"src/client/controllers/placement/ToolsModule/Session/Lifecycle.luau",
	{ workspace = node({ Misc = node({ PlayerPreviews = {} }) }), CFrame = r.CFrame }
)(context)
load("src/client/controllers/placement/ToolsModule/Session/Motion.luau", { CFrame = r.CFrame })(context)
load("src/client/controllers/placement/ToolsModule/Session/Placement.luau", {
	task = taskMock,
	tick = function()
		return 10
	end,
})(context)
-- Exercise real tutorial highlights using lightweight authored tile mocks.
local highlights = 0
local tutorialState = { isActive = true, tileHighlights = {} }
local tutorial = {
	State = { serverTutorial = { ServerStage = { Value = 1 } } },
	player = player,
	tutorialState = tutorialState,
}
load("src/client/controllers/tutorial/TutorialController/Highlights.luau", {
	Instance = {
		new = function()
			highlights += 1
			return {
				Destroy = function()
					highlights -= 1
				end,
			}
		end,
	},
	Color3 = r.Color3,
})(tutorial)
tutorial.getPlayerPlot = function()
	return {
		Land = node({
			Owned = {
				GetChildren = function()
					return { {
						IsA = function()
							return true
						end,
					} }
				end,
			},
		}),
	}
end
player:GetAttributeChangedSignal("MyCityPlacementTool"):Connect(tutorial.refreshPlacementHighlights)
-- Placement owns green land highlighting; tutorial cleanup must not remove it.
context.createTileHighlights = function()
	highlights = 1
end
context.clearTileHighlights = function()
	highlights = 0
end
context.Session.start()
assert(state.isEquipped and highlights == 1 and previewCount == 1)
local originalState = context.state
-- Unequip, delayed equipped notification, then equip again.
tool.Parent = player.Backpack
player.Character.Bank = nil
tool.Unequipped:Fire()
assert(context.state == originalState and not state.isEquipped and not state.previewBuilding)
assert(highlights == 0 and destroyed[1] and disconnects == 1)
tool.Equipped:Fire()
assert(not state.isEquipped and previewCount == 1, "Delayed Equipped callback resurrected an unequipped tool")
tutorial.refreshPlacementHighlights()
assert(highlights == 0, "Late equip remote resurrected green highlights")
tool.Parent = player.Character
player.Character.Bank = tool
tool.Equipped:Fire()
assert(state.isEquipped and state.canPlace and highlights == 1 and previewCount == 2)
-- Rejected placement retains the preview so the player can reposition it.
function replicated.Functions.PlaceBlock:InvokeServer(cf, submittedTool)
	invokes += 1
	assert(submittedTool == tool and cf == r.CFrame.new(0, 3.25, 0), "Base/PrimaryPart transform was lost")
	return false
end
-- Simulate clicking Place mid-motion: server receives the grid target, not the visual pose.
base.CFrame = r.CFrame.new(0.35, 1.25, 0.6) * r.CFrame.Angles(0, math.rad(35), 0)
context.placeBuilding()
assert(invokes == 1 and rejected == 1 and state.previewBuilding and highlights == 1)
-- A reply from an older equip must never delete the newly equipped preview.
replicated.Functions.PlaceBlock.InvokeServer = function()
	coroutine.yield()
	return true
end
local request = coroutine.create(context.placeBuilding)
assert(coroutine.resume(request))
tool.Unequipped:Fire()
tool.Equipped:Fire()
local newPreview = state.previewBuilding
assert(coroutine.resume(request))
assert(state.previewBuilding == newPreview and state.isEquipped and highlights == 1)
-- CleanupPreview is idempotent and does not restore unrelated UI for idle tools.
cleanupRemote:Fire()
local priorRestores = restores
cleanupRemote:Fire()
assert(restores == priorRestores and highlights == 0 and not state.isEquipped)
-- Intro suppresses equip; ending it resumes the still-equipped tool.
player:SetAttribute("MyCityIntroActive", true)
tool.Equipped:Fire()
assert(not state.isEquipped)
player:SetAttribute("MyCityIntroActive", false)
assert(state.isEquipped and highlights == 1)
-- Far-away equip is rejected before placement acquires UI or creates a preview.
context.cleanup()
local countBeforeDistance = previewCount
local uiBeforeDistance = uiAcquires
context.checkPlacementAccess = function()
	return false
end
tool.Equipped:Fire()
assert(not state.isEquipped and previewCount == countBeforeDistance and uiAcquires == uiBeforeDistance)
context.checkPlacementAccess = function()
	return true
end
tool.Equipped:Fire()
assert(state.isEquipped)
-- Opening the shop cancels an existing placement without unequipping the held tool.
local previousPreview = previewCount
sell.Visible = true
-- No placement request can race ahead of the visibility callback.
local previousInvokes = invokes
context.placeBuilding()
assert(invokes == previousInvokes)
sellChanged:Fire()
assert(not state.isEquipped and not state.previewBuilding and highlights == 0 and tool.Parent == player.Character)
local acquiredBeforeSell, restoredBeforeSell = uiAcquires, restores
tool.Unequipped:Fire()
tool.Equipped:Fire()
assert(
	not state.isEquipped
		and previewCount == previousPreview
		and uiAcquires == acquiredBeforeSell
		and restores == restoredBeforeSell,
	"Sell equip changed placement UI or created a world preview"
)
context.placeBuilding()
assert(invokes == previousInvokes)
-- Intro completion while selling cannot restart placement either.
player:SetAttribute("MyCityIntroActive", true)
player:SetAttribute("MyCityIntroActive", false)
assert(not state.isEquipped and highlights == 0)
-- Closing does not race a pending sale; equipping outside the shop is normal again.
sell.Visible = false
sellChanged:Fire()
assert(not state.isEquipped)
tool.Unequipped:Fire()
tool.Equipped:Fire()
assert(state.isEquipped and previewCount == previousPreview + 1 and uiAcquires == acquiredBeforeSell + 1)
-- Replacing the HUD rebinds the same equipped tool and its sell suppression.
playerGui.ChildRemoved:Fire(hud)
assert(not state.isEquipped and not context.HUD)
local replacementSellChanged = signal()
local replacementSell = {
	Visible = false,
	GetPropertyChangedSignal = function()
		return replacementSellChanged
	end,
}
local replacementHud = node({
	Name = "HUD",
	Frames = node({ SellTool = replacementSell }),
	IsA = function(_, class)
		return class == "ScreenGui"
	end,
})
playerGui.ChildAdded:Fire(replacementHud)
assert(context.HUD == replacementHud and state.isEquipped)
replacementSell.Visible = true
replacementSellChanged:Fire()
assert(not state.isEquipped)
replacementSell.Visible = false
replacementSellChanged:Fire()
tool.Equipped:Fire()
assert(state.isEquipped)
-- A delayed old cleanup must not release the next tool's ownership or UI.
local nextTool = {}
context.cooldown.activeTool = nextTool
player:SetAttribute("MyCityPlacementTool", "Shack")
local beforeOldCleanup = restores
context.cleanup()
assert(restores == beforeOldCleanup and player:GetAttribute("MyCityPlacementTool") == "Shack")
context.cooldown.activeTool, context.cooldown.activeCleanup = nil, nil
player:SetAttribute("MyCityPlacementTool", nil)
tool.Destroying:Fire()
assert(highlights == 0 and not state.previewBuilding)
local generationAfterDestroy = state.generation
sell.Visible = true
sellChanged:Fire()
assert(state.generation == generationAfterDestroy, "Destroyed tool retained sell visibility listener")
print(
	"PASS: selling preserves held equip without placement UI/highlights/requests; opening cancels placement; normal re-equip resumes"
)
-- UI tutorial status actually owns cash visibility.
local cash, friend = { Visible = true }, { Visible = true }
local ui = { State = { HUD = { CashDisplay = cash, FriendBoost = friend } }, UIController = {} }
load("src/client/controllers/ui/UIController/Navigation.luau")(ui)
ui.UIController.updateTutorialStatus(true)
assert(not cash.Visible and not friend.Visible)
ui.UIController.updateTutorialStatus(false)
assert(cash.Visible and friend.Visible)
print(
	"PASS: shared placement state, re-equip, tutorial highlights/late equip, rejected placement retry, stale server reply, intro equip gate, cash visibility"
)

-- Collected Bank placement must advance replay before optional cosmetic tasks.
local milestones, consumed, recorded = 0, false, false
local building = { SetPrimaryPartCFrame = function() end, SetAttribute = function() end }
local progress = {
	handleBuildingPlacement = function(_, name, id)
		assert(recorded and consumed and name == "Bank" and id == "fresh")
		milestones += 1
	end,
	handleConstructionComplete = function()
		milestones += 1
	end,
}
local parent = {
	BuildingValidation = {
		placement = function()
			return true
		end,
	},
	BuildingConfig = { setupBuildingConfig = function() end },
	BuildingData = {
		saveBuildingData = function()
			recorded = true
		end,
	},
	Parent = { Parent = { progression = { TutorialSystem = progress } } },
}
local commit = load("src/server/systems/building/BuildingSystem/PlacementCommit.luau", {
	script = { Parent = parent },
	require = function(module)
		return module
	end,
	game = {
		GetService = function()
			return {}
		end,
	},
	task = { defer = function() end },
})
assert(
	commit.instant(
		{ Data = { PlayerInfo = { Tutorial = { IsInTutorial = { Value = true } } } } },
		r.CFrame.identity,
		{
			Destroy = function()
				consumed = true
			end,
		},
		"Bank",
		{
			Clone = function()
				return building
			end,
		},
		{ Buildings = { Placed = {} } },
		1,
		0,
		false,
		"fresh"
	)
)
assert(milestones == 2, "Collected Bank was committed but replay stage never advanced")
print("PASS: instant replay milestones are independent of cosmetic setup")

-- Real client geometry: oversized plots never raise clamp errors and holes stay invalid.
local land = {
	GetChildren = function()
		return {
			{
				IsA = function()
					return true
				end,
				CFrame = r.CFrame.new(-3, 1.15, 0),
				Size = r.Vector3.new(4, 0.2, 8),
			},
			{
				IsA = function()
					return true
				end,
				CFrame = r.CFrame.new(3, 1.15, 0),
				Size = r.Vector3.new(4, 0.2, 8),
			},
		}
	end,
}
local footprint = { Size = r.Vector3.new(8, 0.2, 4) }
local spatial = {
	state = {
		previewBuilding = node({ Base = footprint }),
		rotationAngle = 0,
		plotBounds = { minX = -1, maxX = 1, minZ = -1, maxZ = 1 },
	},
	GRID_SIZE = 1,
	LOCKED_Y_AXIS = 1.25,
	tool = { Name = "Bank" },
}
load("src/client/controllers/placement/ToolsModule/Session/Geometry.luau", { Vector3 = r.Vector3, CFrame = r.CFrame })(
	spatial
)
spatial.getPlayerPlot = function()
	return { Land = node({ Owned = land }) }
end
assert(spatial.constrainToPlotBounds(r.Vector3.zero) == r.Vector3.zero)
assert(
	not spatial.isFullyWithinPlotBounds(r.Vector3.new(0, 1.25, 0)),
	"Preview accepted owned corners with unowned center"
)
print("PASS: oversized preview clamp and full-footprint owned-land validation")

-- Execute the real restored green highlight renderer, including cleanup/repeated equips.
local landPlot = r.Instance.new("Folder")
local land = r.Instance.new("Folder")
land.Name = "Land"
land.Parent = landPlot
local owned = r.Instance.new("Folder")
owned.Name = "Owned"
owned.Parent = land
for i = 1, 3 do
	local tile = r.Instance.new("Part")
	tile.Name = "Tile" .. i
	tile.Parent = owned
end
local highlightContext = {
	state = { tileHighlights = {} },
	VALID_COLOR = r.Color3.fromRGB(88, 255, 76),
	getPlayerPlot = function()
		return landPlot
	end,
}
load("src/client/controllers/placement/ToolsModule/Session/Preview.luau", { Instance = r.Instance, Color3 = r.Color3 })(
	highlightContext
)
highlightContext.createTileHighlights()
assert(#highlightContext.state.tileHighlights == 3)
for _, box in highlightContext.state.tileHighlights do
	assert(
		box.Name == "MyCityPlacementLand"
			and box.Adornee.Parent == owned
			and box.LineThickness > 0
			and box.SurfaceTransparency < 1
	)
end
highlightContext.createTileHighlights()
for _, tile in owned:GetChildren() do
	assert(#tile:GetChildren() == 1, "Re-equip stacked land highlights")
end
highlightContext.clearTileHighlights()
for _, tile in owned:GetChildren() do
	assert(#tile:GetChildren() == 0)
end
print("PASS: green owned-land highlights restored for all previews, no stacked copies, complete unequip cleanup")
