local Audio = {}
local musicEnabled, sfxEnabled = true, true
local volumes = setmetatable({}, { __mode = "k" })
function Audio.bind(root, scope, soundService, tweenService)
	local musicButton = root:FindFirstChild("MusicToggle", true)
	local sfxButton = root:FindFirstChild("SFXToggle", true)
	local holding = root:FindFirstChild("Holding", true)
	local folder = soundService:WaitForChild("SFX", 10)
	if not musicButton or not sfxButton or not holding or not folder then
		warn("[Settings] Missing audio controls or SoundService.SFX")
		return function() end
	end
	local red, green = holding:FindFirstChild("RedGradient"), holding:FindFirstChild("GreenGradient")
	local tweens = {}
	local function visual(button, enabled)
		for _, name in { "RedGradient", "GreenGradient" } do
			local old = button:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
		local source = if enabled then green else red
		if source then
			source:Clone().Parent = button
		end
		local color = if enabled
			then Color3.new(0.121569, 0.415686, 0.156863)
			else Color3.new(0.415686, 0.121569, 0.121569)
		local stroke = button:FindFirstChild("Stroke")
		if stroke then
			stroke.Color = color
		end
		local label = button:FindFirstChild("TextLabel")
		if label then
			label.Text = if enabled then "On" else "Off"
			local textStroke = label:FindFirstChild("Stroke")
			if textStroke then
				textStroke.Color = color
			end
		end
	end
	local function apply(sound, animate)
		if not sound:IsA("Sound") then
			return
		end
		if volumes[sound] == nil then
			volumes[sound] = sound.Volume
		end
		local music = sound.Name == "Ambience"
		local enabled = if music then musicEnabled else sfxEnabled
		local target = if enabled then volumes[sound] else 0
		if tweens[sound] then
			tweens[sound]:Cancel()
			tweens[sound] = nil
		end
		if animate and music then
			local tween = tweenService:Create(
				sound,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Volume = target }
			)
			tweens[sound] = tween
			tween:Play()
		else
			sound.Volume = target
		end
	end
	local function update(animate)
		visual(musicButton, musicEnabled)
		visual(sfxButton, sfxEnabled)
		for _, sound in folder:GetDescendants() do
			apply(sound, animate)
		end
	end
	scope:connect(musicButton.Activated, function()
		musicEnabled = not musicEnabled
		update(true)
	end)
	scope:connect(sfxButton.Activated, function()
		sfxEnabled = not sfxEnabled
		update(false)
	end)
	scope:connect(folder.DescendantAdded, function(sound)
		apply(sound, false)
	end)
	update(false)
	return function()
		for sound, tween in tweens do
			tween:Cancel()
			if sound.Parent then
				apply(sound, false)
			end
		end
	end
end
return Audio
