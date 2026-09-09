local TweenService = game:GetService("TweenService")
local UIEffects = {}
local initializedButtons = setmetatable({}, { __mode = "k" })
local initializedContainers = setmetatable({}, { __mode = "k" })

-- General Tweening function
local function tweenObjectSize(object, targetSize, duration, easingStyle, easingDirection)
	TweenService:Create(object, TweenInfo.new(duration, easingStyle, easingDirection), { Size = targetSize }):Play()
end

-- Hover Effect
local function hoverEffect(button)
	local originalSize = button.Size
	local hoverSize = UDim2.new(
		originalSize.X.Scale * 1.03,
		originalSize.X.Offset,
		originalSize.Y.Scale * 1.03,
		originalSize.Y.Offset
	)

	button.MouseEnter:Connect(function()
		tweenObjectSize(button, hoverSize, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if game.SoundService:FindFirstChild("SFX") and game.SoundService.SFX:FindFirstChild("Hover") then
			game.SoundService.SFX.Hover:Play()
		end
	end)

	button.MouseLeave:Connect(function()
		tweenObjectSize(button, originalSize, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)
end

-- Click Effect
local function clickEffect(button)
	local originalSize = button.Size
	local shrinkSize = UDim2.new(
		originalSize.X.Scale * 0.94,
		originalSize.X.Offset,
		originalSize.Y.Scale * 0.94,
		originalSize.Y.Offset
	)

	button.MouseButton1Click:Connect(function()
		tweenObjectSize(button, shrinkSize, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.1, function()
			tweenObjectSize(button, originalSize, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)
		if game.SoundService:FindFirstChild("SFX") and game.SoundService.SFX:FindFirstChild("Click") then
			game.SoundService.SFX.Click:Play()
		end
	end)
end

-- Shine Effect
local function shineEffect(button)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, 0, 1, 0)
	shine.BackgroundTransparency = 1
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.new(-0.5, 0, 0.5, 0)
	shine.Parent = button

	local function playShine()
		local tween = TweenService:Create(
			shine,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1.5, 0, 0.5, 0) }
		)
		tween:Play()
		tween.Completed:Connect(function()
			shine.Position = UDim2.new(-0.5, 0, 0.5, 0)
		end)
	end

	button.MouseEnter:Connect(playShine)
end

-- Initialize Effect for a Button
function UIEffects.Init(button)
	if initializedButtons[button] then
		return
	end
	initializedButtons[button] = true
	-- Default Effects: Hover + Click
	hoverEffect(button)
	clickEffect(button)

	-- Custom Effects via Attributes
	local effectType = button:GetAttribute("EffectType")
	if effectType == "Shine" then
		shineEffect(button)
	end
end

-- Apply Effects to All Buttons in a UI Container
function UIEffects.ApplyToAll(container)
	if initializedContainers[container] then
		return
	end
	initializedContainers[container] = true
	container.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			UIEffects.Init(descendant)
		end
	end)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			UIEffects.Init(descendant)
		end
	end
end

return UIEffects
