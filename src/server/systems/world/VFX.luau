local VFX = {}

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RareAttach =
	game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Items"):WaitForChild("RareVFX")
local LegendaryAttach =
	game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Items"):WaitForChild("LegendaryVFX")

local ORIGINAL_LIGHTING = {
	CloudCover = Lighting.Atmosphere.Density,
	CloudDensity = Lighting.Atmosphere.Glare,
	TintColor = Lighting.ColorCorrection.TintColor,
}

local RARITY_SETTINGS = {
	Rare = {
		CloudCover = 0.65,
		CloudDensity = 0.9,
		TintColor = Color3.new(0.909804, 0.545098, 1),
		ShakeIntensity = 3,
		ShakeDuration = 5,
		BuildRiseTime = 4,
		SkyTransitionTime = 1.5,
	},
	Legendary = {
		CloudCover = 0.65,
		CloudDensity = 1,
		TintColor = Color3.new(1, 0.843137, 0.203922),
		ShakeIntensity = 5,
		ShakeDuration = 4,
		BuildRiseTime = 5,
		SkyTransitionTime = 2,
	},
}

local function shakeCamera(player, intensity, duration)
	local shakeEvent = ReplicatedStorage.Events.VFX:FindFirstChild("CameraShake")

	shakeEvent:FireClient(player, intensity, duration)
end

local function shakeAllCameras(intensity, duration)
	for _, player in pairs(Players:GetPlayers()) do
		shakeCamera(player, intensity, duration)
	end
end

local function tweenLighting(targetSettings, duration)
	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	local colorCorrection = Lighting:FindFirstChild("ColorCorrection")

	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end

	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Parent = Lighting
	end

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

	local atmosphereTween = TweenService:Create(atmosphere, tweenInfo, {
		Density = targetSettings.CloudCover,
		Glare = targetSettings.CloudDensity,
	})

	local colorTween = TweenService:Create(colorCorrection, tweenInfo, {
		TintColor = targetSettings.TintColor,
	})

	atmosphereTween:Play()
	colorTween:Play()

	return atmosphereTween, colorTween
end

function VFX.PlayFirstRareEffect(building, position, buildingName, playerName)
	local settings = RARITY_SETTINGS.Rare

	tweenLighting(settings, settings.SkyTransitionTime)

	task.wait(0.5)
	shakeAllCameras(settings.ShakeIntensity, settings.ShakeDuration)

	local vfxPart = RareAttach:Clone()
	vfxPart.Parent = workspace:WaitForChild("Misc"):WaitForChild("Effects")
	vfxPart.CFrame = CFrame.new(position)

	local attachment = vfxPart:FindFirstChild("Attachment")
	if attachment then
		for _, particle in pairs(attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
			end
		end
	end

	vfxPart.Orb:Play()

	local epicSound = SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("RareBuilding")
	epicSound:Play()

	local announceEvent = ReplicatedStorage.Events.Notifications:FindFirstChild("RarityAnnounce")

	for _, player in pairs(Players:GetPlayers()) do
		announceEvent:FireClient(player, "Rare", buildingName, playerName)
	end

	task.wait(settings.ShakeDuration)

	if attachment then
		for _, particle in pairs(attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end
	end

	task.wait(1)
	tweenLighting(ORIGINAL_LIGHTING, settings.SkyTransitionTime)

	task.wait(2)
	if vfxPart and vfxPart.Parent then
		vfxPart:Destroy()
	end
end

function VFX.PlayFirstLegendaryEffect(building, position, buildingName, playerName)
	local settings = RARITY_SETTINGS.Legendary

	tweenLighting(settings, settings.SkyTransitionTime)

	task.wait(0.5)
	shakeAllCameras(settings.ShakeIntensity, settings.ShakeDuration)

	local vfxPart = LegendaryAttach:Clone()
	vfxPart.Parent = workspace:WaitForChild("Misc"):WaitForChild("Effects")
	vfxPart.CFrame = CFrame.new(position)

	local attachment = vfxPart:FindFirstChild("Attachment")
	if attachment then
		for _, particle in pairs(attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
			end
		end
	end

	vfxPart.Orb:Play()

	local legendarySound = SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("LegendaryBuilding")
	legendarySound:Play()

	local announceEvent = ReplicatedStorage.Events.Notifications:FindFirstChild("RarityAnnounce")
	for _, player in pairs(Players:GetPlayers()) do
		announceEvent:FireClient(player, "Legendary", buildingName, playerName)
	end

	task.wait(settings.ShakeDuration)

	if attachment then
		for _, particle in pairs(attachment:GetChildren()) do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end
	end

	task.wait(1.5)
	tweenLighting(ORIGINAL_LIGHTING, settings.SkyTransitionTime)

	task.wait(3)
	if vfxPart and vfxPart.Parent then
		vfxPart:Destroy()
	end
end

function VFX.CheckAndPlayRarityEffect(player, building, rarity)
	if not player or not building then
		return false
	end

	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return false
	end

	local position = building.PrimaryPart and building.PrimaryPart.Position or building.Position
	local buildingName = building:GetAttribute("BuildingType") or building.Name

	if rarity == "Rare" then
		local firstRare = playerInfo:FindFirstChild("FirstRare")

		if firstRare.Value == false then
			firstRare.Value = true
			VFX.PlayFirstRareEffect(building, position, buildingName, player.Name)
			return true
		end
	elseif rarity == "Legendary" then
		local firstLegendary = playerInfo:FindFirstChild("FirstLegendary")

		if firstLegendary.Value == false then
			firstLegendary.Value = true
			VFX.PlayFirstLegendaryEffect(building, position, buildingName, player.Name)
			return true
		end
	end

	return false
end

return VFX
