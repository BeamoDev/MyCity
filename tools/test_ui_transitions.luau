local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local tweens = {}
local service = {
	Create = function(_, node, _, props)
		local callback, active = nil, true
		local tween = { Cancel = function() end }
		tween.Completed = {
			Connect = function(_, fn)
				callback = fn
				return {
					Disconnect = function()
						active = false
					end,
				}
			end,
		}
		function tween:Play()
			self.node = node
			self.props = props
			table.insert(tweens, self)
		end
		function tween:complete()
			if active then
				for key, value in props do
					node[key] = value
				end
				callback()
			end
		end
		return tween
	end,
}
local motion = luau.load(
	fs.readFile("src/shared/ui/Transitions.luau"),
	{
		environment = {
			game = {
				GetService = function()
					return service
				end,
			},
			UDim2 = r.UDim2,
			TweenInfo = { new = function() end },
			Enum = r.Enum,
		},
	}
)()
local hud = r.Instance.new("ScreenGui")
local panel = r.Instance.new("Frame")
panel.Parent = hud
panel.Visible = false
panel.Size = r.UDim2.fromScale(0, 0)
motion.panel(panel, true)
assert(tweens[1].props.Size == r.UDim2.fromScale(1, 1))
tweens[1]:complete()
assert(panel.Visible and panel.Size == r.UDim2.fromScale(1, 1))
motion.panel(panel, false)
local exit = tweens[#tweens]
motion.panel(panel, true)
exit:complete()
tweens[#tweens]:complete()
assert(panel.Visible and panel.Size == r.UDim2.fromScale(1, 1))
motion.panel(panel, false)
motion.cancelTree(hud)
tweens[#tweens]:complete()
assert(panel.Visible, "Canceled old exit hid a replacement panel")
assert(not panel:FindFirstChildOfClass("UIScale") and not hud:FindFirstChild("TutorialTransition"))
print("PASS: original popup size tweens, close/reopen cancellation, teardown; no Word Hunt scale or white overlay")
