local CityNameSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local plotsFolder = Workspace:WaitForChild("Plots")
local cityNameDataStore = DataStoreService:GetDataStore("CityNames")

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local citySignFolder = eventsFolder:FindFirstChild("CitySign")

local UpdateCityNameEvent = citySignFolder:FindFirstChild("UpdateCityName")
local RequestCityNameEditEvent = citySignFolder:FindFirstChild("RequestCityNameEdit")

local cityNameCache = {}

local function filterText(text, player)
	local isStudio = RunService:IsStudio()

	if isStudio then
		if string.len(text) > 50 then
			text = string.sub(text, 1, 50)
		end
		return text
	end

	local success, filteredTextResult = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId)
	end)

	if success then
		local finalText
		local filterSuccess, filterError = pcall(function()
			finalText = filteredTextResult:GetNonChatStringForBroadcastAsync()
		end)

		if filterSuccess then
			return finalText
		else
			return player.Name .. "'s City!"
		end
	else
		return player.Name .. "'s City!"
	end
end

local function updateCitySign(plot, cityName)
	local playerSign = plot.UI:FindFirstChild("CitySign")
	if playerSign and playerSign:FindFirstChild("Body") and playerSign.Body:FindFirstChild("SurfaceGui") then
		playerSign.Body.SurfaceGui.Frame.CityName.Text = cityName
	end
end

local function getPlayerPlot(player)
	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")
	if not plotData or plotData.Value == 0 then
		return nil
	end

	local plot = plotsFolder:FindFirstChild("Plot" .. plotData.Value)
	return plot
end

function CityNameSystem.saveCityName(player, cityName)
	local success, error = pcall(function()
		cityNameDataStore:SetAsync(tostring(player.UserId), cityName)
	end)

	if success then
		cityNameCache[player.UserId] = cityName
	end
end

function CityNameSystem.loadCityName(player)
	local success, savedName = pcall(function()
		return cityNameDataStore:GetAsync(tostring(player.UserId))
	end)

	if success and savedName and savedName ~= "" then
		cityNameCache[player.UserId] = savedName
		return savedName
	else
		local defaultName = player.Name .. "'s City!"
		cityNameCache[player.UserId] = defaultName
		return defaultName
	end
end

function CityNameSystem.setCityName(player, newName, skipSave)
	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return false
	end

	local cityNameValue = playerInfo:FindFirstChild("CityName")
	if not cityNameValue then
		cityNameValue = Instance.new("StringValue")
		cityNameValue.Name = "CityName"
		cityNameValue.Value = player.Name .. "'s City!"
		cityNameValue.Parent = playerInfo
	end

	local filteredName = filterText(newName, player)

	if string.len(filteredName) > 50 then
		filteredName = string.sub(filteredName, 1, 50)
	end

	if string.len(filteredName) == 0 or filteredName == "########" then
		filteredName = player.Name .. "'s City!"
	end

	cityNameValue.Value = filteredName
	cityNameCache[player.UserId] = filteredName

	if not skipSave then
		CityNameSystem.saveCityName(player, filteredName)
	end

	local plot = getPlayerPlot(player)
	if plot then
		updateCitySign(plot, filteredName)
	end

	return true, filteredName
end

function CityNameSystem.getCityName(player)
	if cityNameCache[player.UserId] then
		return cityNameCache[player.UserId]
	end

	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return player.Name .. "'s City!"
	end

	local cityNameValue = playerInfo:FindFirstChild("CityName")
	if cityNameValue and cityNameValue.Value ~= "" then
		cityNameCache[player.UserId] = cityNameValue.Value
		return cityNameValue.Value
	end

	return player.Name .. "'s City!"
end

function CityNameSystem.revertCityName(player)
	local defaultName = player.Name .. "'s City!"
	return CityNameSystem.setCityName(player, defaultName)
end

function CityNameSystem.applyCityNameToPlot(player, plot)
	local cityName = CityNameSystem.getCityName(player)

	if plot then
		updateCitySign(plot, cityName)
	end
end

function CityNameSystem.init()
	UpdateCityNameEvent.OnServerEvent:Connect(function(player, newName)
		if not newName or type(newName) ~= "string" then
			return
		end

		if string.len(newName) > 50 then
			newName = string.sub(newName, 1, 50)
		end

		local success, filteredName = Guard.run(player, "CityName", CityNameSystem.setCityName, newName)
		UpdateCityNameEvent:FireClient(player, success, filteredName)
	end)

	RequestCityNameEditEvent.OnServerEvent:Connect(function(player)
		if not Guard.ready(player) then
			return
		end
		local plot = getPlayerPlot(player)
		if plot then
			local currentName = CityNameSystem.getCityName(player)
			RequestCityNameEditEvent:FireClient(player, currentName)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local cityName = CityNameSystem.getCityName(player)
		if cityName and cityName ~= player.Name .. "'s City!" then
			CityNameSystem.saveCityName(player, cityName)
		end

		cityNameCache[player.UserId] = nil
	end)
end

return CityNameSystem
