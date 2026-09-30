local VFX = {}

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityColors = require(ReplicatedStorage.shared.ui.RarityColors)
local TutorialConfig = require(script.Parent.Parent.Parent.config.TutorialConfig)

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

-- Epic has no authored VFX asset, and Mythic/Luxury have none either. Reuse the
-- closest existing template, but recolor only the clone for this celebration.
local HIGH_RARITIES = {
	Rare = { flag = "FirstRare", template = RareAttach, sound = "RareBuilding" },
	Epic = { flag = "FirstEpic", template = RareAttach, sound = "RareBuilding" },
	Legendary = { flag = "FirstLegendary", template = LegendaryAttach, sound = "LegendaryBuilding" },
	Mythic = { flag = "FirstMythic", template = LegendaryAttach, sound = "LegendaryBuilding" },
	Luxury = { flag = "FirstLuxury", template = LegendaryAttach, sound = "LegendaryBuilding" },
}
local celebratedBuildings = setmetatable({}, { __mode = "k" })
local activeLighting = {}
local nextLightingId = 0

local function recolorEffect(clone, color)
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
			item.Color = ColorSequence.new(color)
		elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
			item.Color = color
		elseif item:IsA("Highlight") then
			item.FillColor = color
			item.OutlineColor = color
		end
	end
end

local function refreshLighting()
	local newest
	for _, entry in activeLighting do
		if not newest or entry.id > newest.id then newest = entry end
	end
	if newest then
		local settings = newest.settings
		tweenLighting({ CloudCover = settings.CloudCover, CloudDensity = settings.CloudDensity, TintColor = newest.color }, settings.SkyTransitionTime)
	else
		tweenLighting(ORIGINAL_LIGHTING, 1.5)
	end
end

local function playRarityCelebration(player, building, rarity, definition, ownerReplay)
	local color = RarityColors[rarity]
	local settings = RARITY_SETTINGS[if rarity == "Rare" or rarity == "Epic" then "Rare" else "Legendary"]
	local position = building.PrimaryPart and building.PrimaryPart.Position or building.Position
	local buildingName = building:GetAttribute("BuildingType") or building.Name
	local clone = definition.template:Clone()
	recolorEffect(clone, color)
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(position))
	else
		clone.CFrame = CFrame.new(position)
	end
	clone.Parent = workspace:WaitForChild("Misc"):WaitForChild("Effects")

	nextLightingId += 1
	local lightingId = nextLightingId
	activeLighting[lightingId] = { id = lightingId, color = color, settings = settings }
	refreshLighting()
	task.wait(0.5)
	shakeAllCameras(settings.ShakeIntensity, settings.ShakeDuration)
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") then item.Enabled = true end
	end
	local orb = clone:FindFirstChild("Orb", true)
	if orb and orb:IsA("Sound") then orb:Play() end
	local sfx = SoundService:FindFirstChild("SFX")
	local sound = sfx and sfx:FindFirstChild(definition.sound)
	if sound then sound:Play() end
	local announceEvent = ReplicatedStorage.Events.Notifications:FindFirstChild("RarityAnnounce")
	if announceEvent then
		for _, audience in Players:GetPlayers() do
			announceEvent:FireClient(audience, rarity, buildingName, player.Name, ownerReplay)
		end
	end
	task.wait(settings.ShakeDuration)
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") then item.Enabled = false end
	end
	activeLighting[lightingId] = nil
	refreshLighting()
	task.wait(3)
	clone:Destroy()
end

function VFX.CheckAndPlayRarityEffect(player, building, rarity)
	local definition = HIGH_RARITIES[rarity]
	if not player or not building or not definition or celebratedBuildings[building] then return false end
	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then return false end
	local milestone = playerInfo:FindFirstChild(definition.flag)
	local ownerReplay = player.UserId == TutorialConfig.OwnerUserId
	if not ownerReplay and (not milestone or milestone.Value) then return false end
	-- Claim before any yield so a timer/skip race cannot produce a second celebration.
	celebratedBuildings[building] = true
	if milestone then milestone.Value = true end
	task.spawn(function()
		local success, err = pcall(playRarityCelebration, player, building, rarity, definition, ownerReplay)
		if not success then warn("[VFX] Rarity celebration failed:", err) end
	end)
	return true
end

return VFX
