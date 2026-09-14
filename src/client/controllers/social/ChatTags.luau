local Controller = {}
local started = false
function Controller.start()
	if started then
		return
	end
	started = true
	local mps = game:GetService("MarketplaceService")
	local TextChatService = game:GetService("TextChatService")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Network")).wait()

	local membership = {}
	local function cacheMembership(player)
		local ok, member = pcall(player.IsInGroup, player, 1050526813)
		if player.Parent then
			membership[player.UserId] = if ok then member else false
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(cacheMembership, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		membership[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(cacheMembership, player)
	end
	local SYSTEM_ALERTS = {
		" Higher level buildings generate more income!",
		" Remember to collect your buildings regularly for maximum profit!",
		" Join my group for a free Police Station!",
		" Build more expensive buildings for higher XP multipliers!",
		" Own the Builder Pass? You can have 8 builders at once!",
		" You can pick up and move your buildings anytime!",
		" Invite friends to grow your city together!",
		" Customize your city sign to make it unique!",
	}

	local ALERT_INTERVAL = 600
	local INITIAL_DELAY = 30
	local lastAlertIndex = 0
	local alertTimer = 0
	local hasStarted = false

	local function sendSystemAlert()
		local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if not textChannel then
			return
		end
		lastAlertIndex = lastAlertIndex % #SYSTEM_ALERTS + 1
		local alertMessage = SYSTEM_ALERTS[lastAlertIndex]
		textChannel:DisplaySystemMessage(
			"<font color='rgb(255, 215, 0)'>[SYSTEM]</font> <font color='rgb(255, 215, 0)'>"
				.. alertMessage
				.. "</font>"
		)
	end

	local function setupRarityAnnouncements()
		local rarityEvent = ReplicatedStorage.Events.Notifications.RarityAnnounce

		rarityEvent.OnClientEvent:Connect(function(rarity, buildingName, playerName)
			local textChannel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if not textChannel then
				return
			end

			local message = ""
			local color = ""

			if rarity == "Rare" then
				color = "rgb(212, 0, 212)"
				message = string.format("%s unlocked their first RARE building: %s!", playerName, buildingName)
			elseif rarity == "Legendary" then
				color = "rgb(255, 215, 0)"
				message = string.format("%s unlocked their first LEGENDARY building: %s!", playerName, buildingName)
			end

			textChannel:DisplaySystemMessage(
				"<font color='"
					.. color
					.. "'>[SYSTEM]</font> <font color='"
					.. color
					.. "'><b>"
					.. message
					.. "</b></font>"
			)
		end)
	end

	local function setupCameraShake()
		local shakeEvent = ReplicatedStorage.Events.VFX:FindFirstChild("CameraShake")

		shakeEvent.OnClientEvent:Connect(function(intensity, duration)
			local camera = workspace.CurrentCamera
			local startTime = tick()

			local shakeConnection
			shakeConnection = RunService.RenderStepped:Connect(function()
				local elapsed = tick() - startTime
				if elapsed > duration then
					shakeConnection:Disconnect()
					return
				end

				local shake = math.sin(elapsed * 30) * intensity * (1 - elapsed / duration)
				camera.CFrame = camera.CFrame
					* CFrame.Angles(math.rad(shake * 0.1), math.rad(shake * 0.1), math.rad(shake * 0.05))
			end)
		end)
	end

	setupRarityAnnouncements()
	setupCameraShake()

	task.spawn(function()
		task.wait(INITIAL_DELAY)
		hasStarted = true
		sendSystemAlert()
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		if not hasStarted then
			return
		end
		alertTimer = alertTimer + deltaTime
		if alertTimer >= ALERT_INTERVAL then
			alertTimer = 0
			sendSystemAlert()
		end
	end)

	local function onMessageReceived(message)
		if
			message.TextSource
			and message.TextSource.UserId == Players.LocalPlayer.UserId
			and message.Text:sub(1, 5) == "!cmd-"
		then
			local command = message.Text:sub(6)
			local panel = ReplicatedStorage:FindFirstChild("ControlPanel")
			local events = panel and panel:FindFirstChild("Events")
			local remote = events and events:FindFirstChild("CommandEvent")
			if remote and remote:IsA("RemoteEvent") then
				remote:FireServer(command)
				return true
			end
		end
		return false
	end

	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local properties = Instance.new("TextChatMessageProperties")
		if message.TextSource then
			local plr = Players:GetPlayerByUserId(message.TextSource.UserId)
			local tag = nil
			if not plr then
				return properties
			end
			if plr.UserId == 1790165114 or plr.UserId == 293318986 then
				tag = "<font color='rgb(255, 255, 255)'>[CREATOR]</font> "
			elseif
				plr.UserId == 101906968
				or plr.UserId == 1900145161
				or plr.UserId == 2507157246
				or plr.UserId == 2548390037
				or plr.UserId == 1108295030
				or plr.UserId == 1246378769
				or plr.UserId == 962940705
				or plr.UserId == 920493064
				or plr.UserId == 121454206
				or plr.UserId == 1584236477
				or plr.UserId == 167445091
				or plr.UserId == 6082624443
				or plr.UserId == 123315075
			then
				tag = "<font color='rgb(255, 126, 249)'>[STAFF]</font> "
			elseif membership[plr.UserId] then
				tag = "<font color='rgb(108, 255, 98)'>[MEMBER]</font> "
			elseif plr.MembershipType == Enum.MembershipType.Premium then
				tag = "<font color='rgb(180, 180, 180)'>[PREMIUM]</font> "
			end
			if tag then
				properties.PrefixText = tag .. message.PrefixText
			else
				properties.PrefixText = message.PrefixText
			end
			if onMessageReceived(message) then
				properties.Text = ""
			end
		end
		return properties
	end
end
return Controller
