local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function node(fields)
	fields = fields or {}
	function fields:FindFirstChild(name)
		return self[name]
	end
	function fields:WaitForChild(name)
		return assert(self[name], name)
	end
	return fields
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			local entry = { callback = callback, connected = true }
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
					entry.callback(...)
				end
			end
		end,
	}
end
local shopEvent, heartbeat = signal(), signal()
local label, calls = {}, 0
local itemTemplate, purchaseTemplate = {}, {}
local context = {
	ReplicatedStorage = node({
		Assets = node({ Shop = node({ ItemTemplate = itemTemplate, PurchaseFrame = purchaseTemplate }) }),
	}),
	State = {},
	ShopController = {},
	RunService = { Heartbeat = heartbeat },
	RESET_INTERVAL = 300,
	ShopEvent = { OnClientEvent = shopEvent, FireServer = function() end },
	connections = {
		connect = function(_, event, callback)
			return event:Connect(callback)
		end,
	},
	updateShopDisplay = function(stock, timer)
		assert(stock[1] == "Shack" and timer == 40)
		calls += 1
	end,
	formatTime = function(number)
		return tostring(number)
	end,
}
local installer = luau.load(
	fs.readFile("src/client/controllers/shop/ShopController/Lifecycle.luau"),
	{ environment = {
		script = { Parent = node() },
		task = { wait = function() end },
	} }
)()
installer(context)
context.ShopController.init({
	Frames = {
		ItemShop = {
			Frame = { ScrollingFrame = node(), RestockTimerFrame = { Pattern = node({ TextLabel = label }) } },
		},
	},
})
assert(
	context.State.ItemTemplate == itemTemplate and context.State.PurchaseFrameTemplate == purchaseTemplate,
	"Shop must load both templates from Assets.Shop"
)
shopEvent:Fire("UpdateShop", { "Shack" }, 40, true)
shopEvent:Fire("ResetShop", { "Shack" }, 40, true)
assert(calls == 2, "Live shop events did not reach the extracted helper")
context.startResetCountdown(3)
heartbeat:Fire(0.5)
assert(context.State.remainingTime == 2.5 and label.Text == "Stock Refresh: 3")
context.startResetCountdown(1)
heartbeat:Fire(2)
assert(context.State.remainingTime == 0 and context.State.timerConnection == nil)
local goal = {}
local rebirth = {
	UIController = {},
	State = { RebirthFrame = node({ Progress = node(), GoalAmount = goal }) },
	player = { Data = { PlayerInfo = { Population = { Value = 12 } } } },
	formatPopulation = tostring,
}
luau.load(fs.readFile("src/client/controllers/ui/UIController/Rebirth.luau"))()(rebirth)
rebirth.updateRebirthUI({ requirements = { population = 100 } })
assert(goal.Text == "12/100", "Rebirth helper after concatenation failed")

local source = fs.readFile("tools/repair_gui_paths.luau")
local code = source:sub(1, assert(source:find("-- END REWRITE", 1, true)) - 1)
local rewrite = luau.load(code .. "\nreturn rewrite")()
for _, original in
	{
		"local effects = require(game.ReplicatedStorage.Modules.UIEffects)",
		'local RS = game:GetService("ReplicatedStorage")\nlocal effects = require(RS.Modules.UIEffects)',
		'local effects = require(game:GetService("ReplicatedStorage").Modules.UIEffects)',
		'local ReplicatedStorage = game:GetService("ReplicatedStorage")\nlocal effects = require(ReplicatedStorage:WaitForChild("Modules").UIEffects)',
	}
do
	local updated = rewrite(original)
	assert(updated:find(':WaitForChild("shared"):WaitForChild("UIEffects")', 1, true), updated)
	assert(rewrite(updated) == updated, "GUI repair is not idempotent")
	luau.load(updated)
end
local untouched = "local x = SomeOtherObject.Modules.UIEffects"
assert(rewrite(untouched) == untouched)
print(
	"PASS: shop update/reset events, countdown delta/cleanup, rebirth helper, direct/aliased GUI paths and repeat repair"
)
