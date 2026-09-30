local CityNameSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")

local plotsFolder = Workspace:WaitForChild("Plots")
local cityNameDataStore = DataStoreService:GetDataStore("CityNames")

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local citySignFolder = eventsFolder:FindFirstChild("CitySign")

local UpdateCityNameEvent = citySignFolder:FindFirstChild("UpdateCityName")
local RequestCityNameEditEvent = citySignFolder:FindFirstChild("RequestCityNameEdit")

local cityNameCache = {}
local SAFE_NAME = "My City"
local FILTERED_RECORD_VERSION = 1

local function normalize(text)
	if type(text) ~= "string" or not utf8.len(text) then
		return nil
	end
	text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil end
	local boundary = utf8.offset(text, 51)
	text = if boundary then text:sub(1, boundary - 1) else text
	return if text:match("^#+$") then nil else text
end
local function filterText(text, player)
	text = normalize(text)
	if not text then return nil end
	local success, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if success then normalize(filtered) else nil
end

function CityNameSystem.sanitizeProfileName(player, data)
	local info = data:FindFirstChild("PlayerInfo")
	local cityName = info and info:FindFirstChild("CityName")
	local filteredFlag = info and info:FindFirstChild("CityNameFiltered")
	if not cityName then return SAFE_NAME end
	local safe = if filteredFlag and filteredFlag.Value then normalize(cityName.Value) else filterText(cityName.Value, player)
	cityName.Value = safe or SAFE_NAME
	if filteredFlag then filteredFlag.Value = true end
	return cityName.Value
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
	return if plot
		and plot:GetAttribute("Assigned") == true
		and tonumber(plot:GetAttribute("CityId")) == player.UserId
		then plot else nil
end

function CityNameSystem.saveCityName(player, cityName)
	for attempt = 1, 3 do
		local success = pcall(
			cityNameDataStore.SetAsync,
			cityNameDataStore,
			tostring(player.UserId),
			{ Version = FILTERED_RECORD_VERSION, Text = cityName }
		)
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

	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlayerInfo")
	local previous = info and info:FindFirstChild("CityName")
	local filteredFlag = info and info:FindFirstChild("CityNameFiltered")
	local name
	if success and type(savedName) == "table" and savedName.Version == FILTERED_RECORD_VERSION then
		name = normalize(savedName.Text)
	elseif success and type(savedName) == "string" then
		-- Old CityNames records have no proof of filtering.
		name = filterText(savedName, player)
	elseif previous and filteredFlag and filteredFlag.Value then
		name = normalize(previous.Value)
	elseif previous then
		name = filterText(previous.Value, player)
	end
	name = name or SAFE_NAME
	if previous then previous.Value = name end
	if filteredFlag then filteredFlag.Value = true end
	cityNameCache[player.UserId] = name
	return name
end

function CityNameSystem.setCityName(player, newName, skipSave)
	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	local plot = getPlayerPlot(player)
	if not playerInfo or not plot then
		return false
	end

	local cityNameValue = playerInfo:FindFirstChild("CityName")
	if not cityNameValue then
		cityNameValue = Instance.new("StringValue")
		cityNameValue.Name = "CityName"
		cityNameValue.Value = SAFE_NAME
		cityNameValue.Parent = playerInfo
	end

	local filteredName = filterText(newName, player)
	if not filteredName then
		return false, "Your city name could not be filtered. Please try again."
	end

	if not skipSave and not CityNameSystem.saveCityName(player, filteredName) then
		return false, "Your city name could not be saved. Please try again."
	end
	if not player.Parent or player:GetAttribute("MyCityLeaving") then
		return false
	end
	cityNameValue.Value = filteredName
	local filteredFlag = playerInfo:FindFirstChild("CityNameFiltered")
	if filteredFlag then filteredFlag.Value = true end
	cityNameCache[player.UserId] = filteredName

	updateCitySign(plot, filteredName)

	return true, filteredName
end

function CityNameSystem.getCityName(player)
	if cityNameCache[player.UserId] then
		return cityNameCache[player.UserId]
	end

	local playerInfo = player:FindFirstChild("Data") and player.Data:FindFirstChild("PlayerInfo")
	if not playerInfo then
		return SAFE_NAME
	end

	local cityNameValue = playerInfo:FindFirstChild("CityName")
	local filteredFlag = playerInfo:FindFirstChild("CityNameFiltered")
	if cityNameValue and filteredFlag and filteredFlag.Value then
		local safe = normalize(cityNameValue.Value)
		if safe then
			cityNameCache[player.UserId] = safe
			return safe
		end
	end

	return SAFE_NAME
end

function CityNameSystem.revertCityName(player)
	local defaultName = player.Name .. "'s City!"
	return CityNameSystem.setCityName(player, defaultName)
end

function CityNameSystem.applyCityNameToPlot(player, plot)
	local cityName = CityNameSystem.getCityName(player)

	if plot and plot == getPlayerPlot(player) then
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

		newName = normalize(newName)
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
