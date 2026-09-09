local fs, luau = require("@lune/fs"), require("@lune/luau")
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, connected = true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in callbacks do
				if entry.connected then
					entry.fn(...)
				end
			end
		end,
	}
end
local function node(t)
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
	function t:IsA(class)
		return self.ClassName == class
	end
	return t
end
local function load(path, env)
	return luau.load(fs.readFile(path), { environment = env })()
end
local player = node({})
local starts = 0
local loaderEnv = {
	game = {
		GetService = function()
			return { LocalPlayer = player }
		end,
	},
	script = node({ Satchel = {} }),
	require = function()
		starts += 1
	end,
}
load("src/client/Satchel/init.local.luau", loaderEnv)
load("src/client/Satchel/init.local.luau", loaderEnv)
assert(starts == 1 and player.MyCitySatchelActive, "Duplicate Satchel loader installed another inventory")

-- Execute the actual visibility/input handoff function from the vendored module.
local source = fs.readFile("src/client/Satchel/Satchel/init.luau")
local a = assert(source:find("local function OnIconChanged", 1, true))
local b = assert(source:find("local function MakeVRRoundButton", a, true))
local frame, gui, icon = {}, {}, {}
function icon:setEnabled(value)
	self.enabled = value
end
function icon:deselect() end
local binds, unbinds, closes = 0, 0, 0
local backpack = { IsOpen = false }
backpack.OpenClose = function()
	backpack.IsOpen = false
	closes += 1
end
local menu = { MenuIsOpen = false }
local update = luau.load(
	source:sub(a, b - 1) .. "\nreturn OnIconChanged",
	{
		environment = {
			StarterGui = {
				GetCore = function()
					return true
				end,
			},
			Players = { LocalPlayer = player },
			GuiService = menu,
			BackpackGui = gui,
			MainFrame = frame,
			inventoryIcon = icon,
			WholeThingEnabled = false,
			BackpackScript = backpack,
			FullHotbarSlots = 2,
			bindBackpackHotbarAction = function()
				binds += 1
			end,
			unbindBackpackHotbarAction = function()
				unbinds += 1
			end,
		},
	}
)()
update(true)
assert(not gui.Enabled and not frame.Visible and not icon.enabled, "Inventory appeared before loading started")
player.MyCityIntroActive = true
update(true)
assert(not gui.Enabled)
player.MyCityIntroActive = false
update(true)
assert(gui.Enabled and frame.Visible and icon.enabled and binds == 1)
update(true)
assert(binds == 1, "Heartbeat rebound inventory controls")
backpack.IsOpen, menu.MenuIsOpen = true, true
update(true)
assert(not gui.Enabled and not icon.enabled and closes == 1 and unbinds == 1)
menu.MenuIsOpen = false
update(true)
assert(gui.Enabled and binds == 2)
update(false)
assert(not gui.Enabled and not frame.Visible and unbinds == 2)
print(
	"PASS: single Satchel loader, pre-load/intro input gating, Play handoff, menu close/reopen, disabled state and stable input bindings"
)

-- A building Tool with delayed child replication must initialize exactly once.
local backpackContainer = node({ ClassName = "Backpack", ChildAdded = signal(), children = {} })
player.Backpack, player.ChildAdded, player.CharacterAdded = backpackContainer, signal(), signal()
local initialized = 0
local handler = {
	init = function()
		initialized += 1
	end,
}
local buildingTools = load("src/client/controllers/placement/BuildingTools.luau", {
	game = {
		GetService = function(_, name)
			return if name == "Players" then { LocalPlayer = player } else {}
		end,
	},
	script = { Parent = node({ ToolsModule = handler }) },
	require = function(value)
		return value
	end,
	task = {
		spawn = function(fn, ...)
			fn(...)
		end,
	},
})
buildingTools.start()
local tool = node({ ClassName = "Tool", Parent = backpackContainer, ChildAdded = signal(), Destroying = signal() })
backpackContainer.ChildAdded:Fire(tool)
assert(initialized == 0)
tool.ToolName = {}
tool.ChildAdded:Fire(tool.ToolName)
assert(initialized == 0)
tool.IsValid = {}
tool.ChildAdded:Fire(tool.IsValid)
assert(initialized == 1)
backpackContainer.ChildAdded:Fire(tool)
tool.ChildAdded:Fire({})
assert(initialized == 1)
local destroyed = node({ ClassName = "Tool", Parent = backpackContainer, ChildAdded = signal(), Destroying = signal() })
backpackContainer.ChildAdded:Fire(destroyed)
destroyed.Destroying:Fire()
destroyed.ToolName, destroyed.IsValid = {}, {}
destroyed.ChildAdded:Fire({})
assert(initialized == 1)
print(
	"PASS: delayed building markers initialize once; destroyed and repeatedly moved tools do not gain duplicate sessions"
)

local janitor =
	load("src/client/Satchel/Satchel/Packages/_Index/legitatx_topbarplus@3.0.5/topbarplus/Packages/Janitor.luau", {
		game = {
			GetService = function(_, name)
				assert(name == "RunService")
				return { Heartbeat = {} }
			end,
		},
	})
local owner = janitor.new()
local cleaned = 0
owner:AddObject({
	Destroy = function()
		cleaned += 1
	end,
})
owner:Cleanup()
assert(cleaned == 1)
local promise = {
	cancel = function()
		cleaned += 1
	end,
	getStatus = function()
		return "Started"
	end,
	finally = function() end,
}
owner:AddPromise(promise)
owner:Cleanup()
assert(cleaned == 2)
print("PASS: bundled Janitor cleans objects and pending promises without another game's Framework")
