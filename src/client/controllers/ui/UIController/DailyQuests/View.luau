local View = {}
local function layout(parent, direction)
	local existing = parent:FindFirstChildOfClass("UIListLayout")
	if not existing then
		existing = Instance.new("UIListLayout")
		existing.FillDirection = direction
		existing.Parent = parent
	end
	existing.SortOrder = Enum.SortOrder.LayoutOrder
end
function View.create(hud)
	-- Remove only the old code-owned display, never authored HUD objects.
	for _, parent in { hud.Parent, hud:FindFirstChild("Frames") } do
		if parent then
			for _, child in parent:GetChildren() do
				if
					(child.Name == "MyCityDailyQuests" or child.Name == "DailyQuests")
					and child:GetAttribute("MyCityGenerated")
				then
					child:Destroy()
				end
			end
		end
	end
	local frames = hud:FindFirstChild("Frames")
	local root = frames and frames:FindFirstChild("Quests")
	local frame = root and root:FindFirstChild("Frame")
	local content = frame and frame:FindFirstChild("Content")
	local template = frame and frame:FindFirstChild("Template")
	local header = frame and frame:FindFirstChild("Header")
	local title = header and header:FindFirstChild("TextLabel", true)
	local close = frame and frame:FindFirstChild("X")
	local top = content and content:FindFirstChild("Top")
	local bottom = content and content:FindFirstChild("Bottom")
	if
		not (
			root
			and template
			and template:IsA("GuiObject")
			and title
			and title:IsA("TextLabel")
			and close
			and close:IsA("GuiButton")
			and top
			and bottom
		)
	then
		warn("[DailyQuests] Expected HUD.Frames.Quests.Frame: Header.TextLabel, Content.Top/Bottom, Template and X")
		return nil
	end
	template.Visible, root.Visible = false, false
	frame.Visible, content.Visible, top.Visible, bottom.Visible = true, true, true, true
	top.LayoutOrder, bottom.LayoutOrder = 1, 100
	layout(content, Enum.FillDirection.Vertical)
	if content:IsA("ScrollingFrame") then
		content.AutomaticCanvasSize = Enum.AutomaticSize.Y
		content.CanvasSize = UDim2.fromScale(0, 0)
	end
	close.Active, close.Interactable = true, true
	return { Root = root, Template = template, List = content, Close = close, Timer = title }
end
function View.updateTimer(view, remaining)
	view.Timer.Text = if remaining
		then string.format("Daily Quests (%dH %02dM)", math.floor(remaining / 3600), math.floor(remaining % 3600 / 60))
		else "Daily Quests (Loading...)"
end
return View
