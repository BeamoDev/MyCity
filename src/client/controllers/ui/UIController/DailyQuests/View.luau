local W = require(script.Parent.Widgets)
local View = {}
function View.create(hud)
	-- Keep generated UI independent of authored Frames sizing, clipping and layout objects.
	local screen = W.make("ScreenGui", hud.Parent, {
		Name = "MyCityDailyQuests",
		ResetOnSpawn = false,
		DisplayOrder = hud.DisplayOrder + 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = hud.Enabled,
	})
	screen:SetAttribute("MyCityGenerated", true)
	local root = W.make("Frame", screen, {
		Name = "DailyQuests",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Active = true,
		BackgroundTransparency = 1,
		Visible = false,
	})
	root:SetAttribute("MyCityGenerated", true)
	local card = W.make("Frame", root, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.88),
		BackgroundColor3 = Color3.fromRGB(248, 249, 242),
		BorderSizePixel = 0,
	})
	W.corner(card, 16)
	W.make("UISizeConstraint", card, { MaxSize = Vector2.new(760, 820) })
	W.make("UIStroke", card, { Color = Color3.fromRGB(45, 49, 34), Thickness = 3 })
	local header = W.make(
		"Frame",
		card,
		{ Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = Color3.fromRGB(255, 222, 65), BorderSizePixel = 0 }
	)
	W.corner(header, 16)
	W.text(header, "DAILY QUESTS", UDim2.fromOffset(18, 0), UDim2.new(1, -88, 1, 0), 24)
	local close = W.make("TextButton", header, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(225, 66, 67),
		BorderSizePixel = 0,
	})
	W.corner(close, 10)
	local timer = W.text(card, "Loading your six quests...", UDim2.fromOffset(18, 75), UDim2.new(1, -36, 0, 27), 16)
	local scroll = W.make("ScrollingFrame", card, {
		Name = "Quests",
		Position = UDim2.fromOffset(12, 110),
		Size = UDim2.new(1, -24, 1, -154),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
	})
	W.make("UIPadding", scroll, {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 6),
	})
	W.make("UIListLayout", scroll, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	local footer = W.text(card, "2 easy / 2 medium / 2 hard", UDim2.new(0, 18, 1, -37), UDim2.new(1, -36, 0, 26), 14)
	return { Screen = screen, Root = root, List = scroll, Close = close, Timer = timer, Footer = footer }
end
return View
