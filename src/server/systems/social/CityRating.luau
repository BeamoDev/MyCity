local Service = {}
function Service.start()
	local Players = game:GetService("Players")
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	-- Create the complete network before any gameplay module is required.
	require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Network")).start()

	local CityRatingStore = DataStoreService:GetDataStore("CityRatings")

	local AlertClientEvent = ReplicatedStorage.Events.Likes.AlertClient

	local likesCache = {}
	local likedByCache = {}

	local function getLikesData(cityId)
		if not cityId or cityId == "Empty" then
			return 0, {}
		end

		if likesCache[cityId] then
			return likesCache[cityId], likedByCache[cityId] or {}
		end

		local success, data = pcall(function()
			return CityRatingStore:GetAsync("city_" .. tostring(cityId))
		end)

		if success and data then
			likesCache[cityId] = data.likes or 0
			likedByCache[cityId] = data.likedBy or {}
			return data.likes or 0, data.likedBy or {}
		end

		return 0, {}
	end

	local function updateLikesDisplay(plot, likes)
		local ratioSign = plot:WaitForChild("UI"):FindFirstChild("RatioSign")
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
		local ratioSign = plot.UI:FindFirstChild("RatioSign")
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

		local oldConnection = proximityPrompt:GetAttribute("ConnectionId")
		if oldConnection then
			proximityPrompt:SetAttribute("ConnectionId", nil)
		end

		local connection = proximityPrompt.Triggered:Connect(function(player)
			handleLikeRequest(player, plot)
		end)

		proximityPrompt:SetAttribute("ConnectionId", tostring(connection))

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

		local added = false
		local ok, record = pcall(function()
			return CityRatingStore:UpdateAsync("city_" .. tostring(cityId), function(current)
				added = false
				current = current or { likes = 0, likedBy = {} }
				current.likedBy = current.likedBy or {}
				local key = tostring(player.UserId)
				if not current.likedBy[key] then
					current.likedBy[key] = true
					current.likes = (current.likes or 0) + 1
					current.lastUpdated = os.time()
					added = true
				end
				return current
			end)
		end)
		if not ok then
			AlertClientEvent:FireClient(player, "Error", "Your like could not be saved. Please try again.")
			return
		end
		likesCache[cityId], likedByCache[cityId] = record.likes, record.likedBy
		updateLikesDisplay(plot, record.likes)
		if not added then
			AlertClientEvent:FireClient(player, "Already Liked", "You've already liked this city!")
			return
		end
		AlertClientEvent:FireClient(player, "Success", "Like added! Total: " .. record.likes)
		local owner = Players:GetPlayerByUserId(tonumber(cityId))
		if owner and owner ~= player and require(script.Parent.Parent.security.RequestGuard).ready(owner) then
			AlertClientEvent:FireClient(owner, "New Like!", player.Name .. " liked your city!")

			local leaderstats = owner:FindFirstChild("leaderstats")
			if leaderstats then
				local cash = leaderstats:FindFirstChild("Cash")
				if cash then
					cash.Value = cash.Value + 50
				end
			end
		end
	end

	local function initializePlot(plot)
		setupProximityPrompt(plot)

		local cityId = plot:GetAttribute("CityId")
		if cityId and cityId ~= "Empty" then
			local likes = getLikesData(cityId)
			updateLikesDisplay(plot, likes)
		else
			updateLikesDisplay(plot, 0)
		end

		plot:GetAttributeChangedSignal("CityId"):Connect(function()
			local newCityId = plot:GetAttribute("CityId")
			if newCityId and newCityId ~= "Empty" then
				local likes = getLikesData(newCityId)
				updateLikesDisplay(plot, likes)
			else
				updateLikesDisplay(plot, 0)
			end
		end)
	end

	local function initializeAllPlots()
		for i = 1, 8 do
			local plotName = "Plot" .. i
			local plot = workspace.Plots:FindFirstChild(plotName)
			if plot then
				initializePlot(plot)
			end
		end
	end

	workspace.Plots.ChildAdded:Connect(function(child)
		if child:IsA("Folder") and string.match(child.Name, "^Plot%d+$") then
			task.wait(1)
			initializePlot(child)
		end
	end)

	task.wait(2)
	initializeAllPlots()

	task.spawn(function()
		while true do
			task.wait(30)
			for i = 1, 8 do
				local plotName = "Plot" .. i
				local plot = workspace.Plots:FindFirstChild(plotName)
				if plot then
					local cityId = plot:GetAttribute("CityId")
					if cityId and cityId ~= "Empty" then
						local likes = getLikesData(cityId)
						updateLikesDisplay(plot, likes)
					end
				end
			end
		end
	end)
end
return Service
