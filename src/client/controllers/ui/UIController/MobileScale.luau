-- Touch-only devices get 15% larger HUD.Frames popups and 10% larger HUD.Buttons groups.
-- Uses UIScale so authored Size/Position (and the popup open tween) stay unchanged.
local UserInputService = game:GetService("UserInputService")
local FRAME_SCALE, BUTTON_SCALE = 1.15, 1.1
local BUTTON_GROUPS = { "Left", "Right", "Up", "Top" }
local BASE = "MyCityBaseScale"

return function(Context)
	local function scale(target, factor)
		if not target:IsA("GuiObject") then
			-- Folders cannot hold a UIScale; scale their GUI children instead.
			for _, child in target:GetChildren() do
				if child:IsA("GuiObject") then
					scale(child, factor)
				end
			end
			return
		end
		local uiScale = target:FindFirstChildOfClass("UIScale")
		if not uiScale then
			uiScale = Instance.new("UIScale")
			uiScale.Name = "MyCityMobileScale"
			uiScale.Parent = target
		end
		-- Remember the authored scale so reapplying never compounds.
		local base = uiScale:GetAttribute(BASE)
		if base == nil then
			base = uiScale.Scale
			uiScale:SetAttribute(BASE, base)
		end
		uiScale.Scale = base * factor
	end

	function Context.isMobileLayout()
		return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end

	function Context.setupMobileScale()
		if not Context.isMobileLayout() then
			return
		end
		local frames, buttons = Context.State.FramesFolder, Context.State.ButtonFolder
		for _, frame in frames:GetChildren() do
			scale(frame, FRAME_SCALE)
		end
		Context.connections:connect(frames.ChildAdded, function(frame)
			scale(frame, FRAME_SCALE)
		end)
		for _, name in BUTTON_GROUPS do
			local group = buttons:FindFirstChild(name)
			if group then
				scale(group, BUTTON_SCALE)
			end
		end
	end
end
