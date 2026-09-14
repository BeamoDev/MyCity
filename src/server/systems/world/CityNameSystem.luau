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

local function truncate(text)
	if type(text) ~= "string" or not utf8.len(text) then
		return nil
	end
	local boundary = utf8.offset(text, 51)
	return if boundary then text:sub(1, boundary - 1) else text
end
local function filterText(text, player)
	local isStudio = RunService:IsStudio()

	if isStudio then
		text = truncate(text)
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
			return nil
		end
	else
		return nil
	end
end

local function updateCitySign(plot, cityName)
	local ui = plot:FindFirstChild("UI")
	local sign = ui and ui:FindFirstChild("CitySign")
	local body = sign and sign:FindFirstChild("Body")
	local surface = body and body:FindFirstChild("SurfaceGui")
	local frame = surface and surface:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("CityName")
	if label then
		label.Text = cityName
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
	for attempt = 1, 3 do
		local success = pcall(cityNameDataStore.SetAsync, cityNameDataStore, tostring(player.UserId), cityName)
		if success then
			return true
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	return false
end

function CityNameSystem.loadCityName(player)
	local success, savedName = pcall(function()
		return cityNameDataStore:GetAsync(tostring(player.UserId))
	end)

	if success and type(savedName) == "string" and savedName ~= "" and utf8.len(savedName) then
		cityNameCache[player.UserId] = savedName
		return savedName
	else
		local data = player:FindFirstChild("Data")
		local info = data and data:FindFirstChild("PlayerInfo")
		local previous = info and info:FindFirstChild("CityName")
		local defaultName = if previous and previous.Value ~= "" then previous.Value else player.Name .. "'s City!"
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
	if not filteredName then
		return false, "Your city name could not be filtered. Please try again."
	end

	filteredName = truncate(filteredName) or (player.Name .. "'s City!")

	if string.len(filteredName) == 0 or filteredName == "########" then
		filteredName = player.Name .. "'s City!"
	end

	if not skipSave and not CityNameSystem.saveCityName(player, filteredName) then
		return false, "Your city name could not be saved. Please try again."
	end
	if not player.Parent or player:GetAttribute("MyCityLeaving") then
		return false
	end
	cityNameValue.Value = filteredName
	cityNameCache[player.UserId] = filteredName

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

local started = false
function CityNameSystem.init()
	if started then
		return
	end
	started = true
	UpdateCityNameEvent.OnServerEvent:Connect(function(player, newName)
		if not newName or type(newName) ~= "string" then
			return
		end

		newName = truncate(newName)
		if not newName then
			UpdateCityNameEvent:FireClient(player, false, "Please enter a valid city name.")
			return
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
		cityNameCache[player.UserId] = nil
	end)
end

return CityNameSystem
