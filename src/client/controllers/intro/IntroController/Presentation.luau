local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Presentation = {}
function Presentation.sound(folderName, name, playing)
	local folder = SoundService:FindFirstChild(folderName)
	local sound = folder and folder:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		if playing == false then
			sound:Stop()
		else
			sound:Play()
		end
	end
end
local function tween(session, object, properties, duration)
	if not object then
		return
	end
	local animation = TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		properties
	)
	table.insert(session.tweens, animation)
	animation:Play()
	return animation
end
function Presentation.create(screen)
	local intro = screen:WaitForChild("IntroFrame", 10)
	local loading = screen:WaitForChild("Loading", 10)
	local play = intro and intro:WaitForChild("Play", 10)
	local barFrame = loading and loading:WaitForChild("LoadingFrame", 10)
	local fill = barFrame and barFrame:WaitForChild("FillBar", 10)
	if not intro or not loading or not play or not play:IsA("GuiButton") or not fill then
		warn(
			"[Intro] Expected Tutorial.IntroFrame.Play and Tutorial.Loading.LoadingFrame.FillBar; intro remains blocked"
		)
		return nil
	end
	return { screen = screen, intro = intro, loading = loading, play = play, fill = fill }
end
function Presentation.progress(session, progress)
	if type(progress) ~= "number" or progress ~= progress then
		return
	end
	if session.fillTween then
		session.fillTween:Cancel()
	end
	local fill = session.view.fill
	session.fillTween = tween(
		session,
		fill,
		{ Size = UDim2.new(math.clamp(progress, 0, 1), 0, fill.Size.Y.Scale, fill.Size.Y.Offset) },
		0.3
	)
end
function Presentation.loading(session)
	local view = session.view
	view.screen.Enabled = true
	view.intro.Visible = false
	view.loading.Visible = true
	view.loading.Size = UDim2.fromScale(1, 1)
	view.play.Interactable = false
end
function Presentation.reveal(session)
	local view = session.view
	view.loading.Visible = false
	view.intro.Visible = true
	view.play.Interactable = false
	local title = view.play:FindFirstChild("TextLabel")
	local icon = view.intro:FindFirstChild("ImageLabel")
	local pattern = view.play:FindFirstChild("Pattern")
	local offline = view.intro:FindFirstChild("BuildsOffline")
	if offline then
		offline.Visible = true
	end
	local elements = {
		{ view.play, "BackgroundTransparency", 0 },
		{ view.play:FindFirstChild("UIStroke"), "Transparency", 0 },
		{ title, "TextTransparency", 0 },
		{ title and title:FindFirstChild("UIStroke"), "Transparency", 0 },
		{ icon, "ImageTransparency", 0 },
		{ pattern, "ImageTransparency", 0.25 },
	}
	for _, element in elements do
		local object, property, target = element[1], element[2], element[3]
		if object then
			object[property] = 1
			tween(session, object, { [property] = target }, 3)
		end
	end
	session.scope:delay(3, function()
		view.play.Interactable = true
	end)
	session.scope:delay(3.5, function()
		Presentation.sound("GroupIntro", "StartUp")
	end)
end
function Presentation.close(session)
	Presentation.sound("SFX", "Construction", false)
	Presentation.sound("SFX", "Swoosh")
	Presentation.loading(session)
	Presentation.progress(session, 1)
	task.wait(0.3)
	if not session.active or session.dismissed then
		return
	end
	tween(session, session.view.loading, { Size = UDim2.fromScale(0, 0) }, 0.4)
	task.wait(0.4)
end
return Presentation
