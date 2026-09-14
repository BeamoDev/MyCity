local Service = {}
local started = false
function Service.start()
	if started then
		return
	end
	started = true
	local Players = game:GetService("Players")
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	-- Create the complete network before any gameplay module is required.
	require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Network")).start()

	local CityRatingStore = DataStoreService:GetDataStore("CityRatings")
	local Guard = require(script.Parent.Parent.security.RequestGuard)
	local Rewards = require(script.Parent.CityLikeRewards)
	local promptConnections = setmetatable({}, { __mode = "k" })
	local initialized = setmetatable({}, { __mode = "k" })
	local rewardSequences = {}
	local function checked(record)
		if record == nil then
			return { likes = 0, likedBy = {}, rewardSequence = 0 }
		end
		assert(type(record) == "table", "Invalid city rating record")
		assert(
			type(record.likes or 0) == "number" and (record.likes or 0) >= 0 and (record.likes or 0) < math.huge,
			"Invalid city like count"
		)
		assert(record.likedBy == nil or type(record.likedBy) == "table", "Invalid city voters")
		record.likedBy = record.likedBy or {}
		record.rewardSequence = record.rewardSequence or 0
		assert(
			type(record.rewardSequence) == "number" and record.rewardSequence >= 0 and record.rewardSequence < math.huge,
			"Invalid city reward sequence"
		)
		return record
	end
	local function settle(cityId)
		local owner = Players:GetPlayerByUserId(tonumber(cityId) or 0)
		if owner and Guard.ready(owner) then
			Rewards.settle(owner, rewardSequences[cityId] or 0)
		end
	end

	local AlertClientEvent = ReplicatedStorage.Events.Likes.AlertClient

	local likesCache = {}
	local likedByCache = {}
	local cacheTime = {}
	local requestTimes = setmetatable({}, { __mode = "k" })
	local pending = setmetatable({}, { __mode = "k" })

	local function getLikesData(cityId)
		if not cityId or cityId == "Empty" then
			return 0, {}
		end

		if likesCache[cityId] and os.clock() - (cacheTime[cityId] or 0) < 60 then
			return likesCache[cityId], likedByCache[cityId] or {}
		end

		local success, data = pcall(function()
			return checked(CityRatingStore:GetAsync("city_" .. tostring(cityId)))
		end)

		if success and data then
			cacheTime[cityId] = os.clock()
			rewardSequences[cityId] = data.rewardSequence
			task.defer(settle, cityId)
			likesCache[cityId] = data.likes or 0
			likedByCache[cityId] = data.likedBy or {}
			return data.likes or 0, data.likedBy or {}
		end

		if success then
			likesCache[cityId], likedByCache[cityId], cacheTime[cityId] = 0, {}, os.clock()
		end
		return likesCache[cityId] or 0, likedByCache[cityId] or {}
	end

	local function updateLikesDisplay(plot, likes)
		local ui = plot:FindFirstChild("UI")
		local ratioSign = ui and ui:FindFirstChild("RatioSign")
		if not ratioSign then
			return
		end

		local body = ratioSign:FindFirstChild("Body")
		if not body then
			return
		end

		local frame = body:FindFirstChild("Body") and body.Body:FindFirstChild("Frame")
		if not frame then
			frame = body:FindFirstChild("SurfaceGui") and body.SurfaceGui:FindFirstChild("Frame")
		end

		if frame then
			local likesText = frame:FindFirstChild("LikesText") or frame:FindFirstChild("Likes")
			if likesText then
				likesText.Text = tostring(likes) .. " ❤️"
			end
		end
	end

	local handleLikeRequest
	local function setupProximityPrompt(plot)
		local ui = plot:FindFirstChild("UI")
		local ratioSign = ui and ui:FindFirstChild("RatioSign")
		if not ratioSign then
			return
		end

		local body = ratioSign:FindFirstChild("Body")
		if not body then
			return
		end

		local proxPromptFolder = body:FindFirstChild("ProxPrompt")
		local proximityPrompt = proxPromptFolder and proxPromptFolder:FindFirstChild("ProximityPrompt")
		if not proximityPrompt then
			return
		end

		proximityPrompt.ObjectText = "City Rating"
		proximityPrompt.ActionText = "Like City"
		proximityPrompt.MaxActivationDistance = 15
		proximityPrompt.HoldDuration = 0
		proximityPrompt.RequiresLineOfSight = false
		proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
		proximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX

		if promptConnections[proximityPrompt] then
			return proximityPrompt
		end
		promptConnections[proximityPrompt] = proximityPrompt.Triggered:Connect(function(player)
			handleLikeRequest(player, plot)
		end)

		return proximityPrompt
	end

	handleLikeRequest = function(player, plot)
		if not require(script.Parent.Parent.security.RequestGuard).ready(player) then
			return
		end
		local cityId = plot:GetAttribute("CityId")
		if not cityId or cityId == "Empty" or cityId == "" then
			AlertClientEvent:FireClient(player, "Error", "This plot is unoccupied!")
			return
		end

		if likedByCache[cityId] and likedByCache[cityId][tostring(player.UserId)] then
			AlertClientEvent:FireClient(player, "Already Liked", "You've already liked this city!")
			return
		end
		if pending[player] or os.clock() - (requestTimes[player] or -math.huge) < 3 then
			return
		end
		requestTimes[player], pending[player] = os.clock(), true
		local added = false
		local ok, record = pcall(function()
			return CityRatingStore:UpdateAsync("city_" .. tostring(cityId), function(current)
				added = false
				current = checked(current)
				current.likedBy = current.likedBy or {}
				local key = tostring(player.UserId)
				if not current.likedBy[key] then
					current.likedBy[key] = true
					current.likes = (current.likes or 0) + 1
					if tostring(cityId) ~= tostring(player.UserId) then
						current.rewardSequence += 1
					end
					current.lastUpdated = os.time()
					added = true
				end
				return current
			end)
		end)
		pending[player] = nil
		if not player.Parent then
			return
		end
		if not ok then
			AlertClientEvent:FireClient(player, "Error", "Your like could not be saved. Please try again.")
			return
		end
		rewardSequences[cityId] = record.rewardSequence
		likesCache[cityId], likedByCache[cityId], cacheTime[cityId] = record.likes, record.likedBy, os.clock()
		task.defer(settle, cityId)
		if tostring(plot:GetAttribute("CityId")) == tostring(cityId) then
			updateLikesDisplay(plot, record.likes)
		end
		if not added then
			AlertClientEvent:FireClient(player, "Already Liked", "You've already liked this city!")
			return
		end
		AlertClientEvent:FireClient(player, "Success", "Like added! Total: " .. record.likes)
		local owner = Players:GetPlayerByUserId(tonumber(cityId))
		if owner and owner ~= player and require(script.Parent.Parent.security.RequestGuard).ready(owner) then
			AlertClientEvent:FireClient(owner, "New Like!", player.Name .. " liked your city!")
		end
	end

	local function initializePlot(plot)
		if initialized[plot] or not plot.Name:match("^Plot%d+$") then
			return
		end
		initialized[plot] = true
		setupProximityPrompt(plot)
		plot.DescendantAdded:Connect(function(child)
			if child.Name == "UI" or child.Name == "RatioSign" or child.Name == "ProximityPrompt" then
				setupProximityPrompt(plot)
			end
		end)

		local cityId = plot:GetAttribute("CityId")
		if cityId and cityId ~= "Empty" then
			local likes = getLikesData(cityId)
			if plot:GetAttribute("CityId") == cityId then
				updateLikesDisplay(plot, likes)
			end
		else
			updateLikesDisplay(plot, 0)
		end

		plot:GetAttributeChangedSignal("CityId"):Connect(function()
			local newCityId = plot:GetAttribute("CityId")
			if newCityId and newCityId ~= "Empty" then
				local likes = getLikesData(newCityId)
				if plot:GetAttribute("CityId") == newCityId then
					updateLikesDisplay(plot, likes)
				end
			else
				updateLikesDisplay(plot, 0)
			end
		end)
	end

	local function initializeAllPlots()
		for _, plot in workspace.Plots:GetChildren() do
			initializePlot(plot)
		end
	end

	workspace.Plots.ChildAdded:Connect(function(child)
		if child:IsA("Folder") and string.match(child.Name, "^Plot%d+$") then
			initializePlot(child)
		end
	end)

	initializeAllPlots()

	task.spawn(function()
		while true do
			task.wait(30)
			local active = {}
			for _, plot in workspace.Plots:GetChildren() do
				local cityId = plot:GetAttribute("CityId")
				if cityId and cityId ~= "Empty" then
					active[cityId] = true
					local likes = getLikesData(cityId)
					if plot:GetAttribute("CityId") == cityId then
						updateLikesDisplay(plot, likes)
					end
					settle(cityId)
				end
			end
			for cityId in likesCache do
				if not active[cityId] then
					likesCache[cityId], likedByCache[cityId], cacheTime[cityId], rewardSequences[cityId] =
						nil, nil, nil, nil
				end
			end
		end
	end)
end
return Service
