-- RemoteBindings: focused implementation for UIController.
return function(Context)
	local State = Context.State
	local UIController = Context.UIController
	local TweenService = Context.TweenService
	local ReplicatedStorage = Context.ReplicatedStorage
	local ProximityPromptService = Context.ProximityPromptService
	local Icon = Context.Icon
	local player = Context.player
	local questEvents = Context.questEvents

	function Context.connectWeather()
		local timeUpdateRemote = game.ReplicatedStorage.Events.Weather.TimeUpdate
		local weatherUpdateRemote = game.ReplicatedStorage.Events.Weather.UpdateUI

		local Template
		local timeLabel
		local iconLabel

		local function formatTimeDisplay(seconds)
			local minutes = math.floor(seconds / 60)
			local secs = seconds % 60
			return string.format("%d:%02d", minutes, secs)
		end

		local function clearChildrenExceptLayouts(parent)
			for _, child in ipairs(parent:GetChildren()) do
				if
					not child:IsA("UIListLayout")
					and not child:IsA("UIGridLayout")
					and not child:IsA("UIPageLayout")
				then
					child:Destroy()
				end
			end
		end

		local function ensureTemplate()
			if not Template or not Template.Parent then
				local source = ReplicatedStorage:WaitForChild("Assets"):FindFirstChild("WeatherTemplate")
				if not source then
					return false
				end
				clearChildrenExceptLayouts(State.weatherFrame)
				Template = source:Clone()
				Template.Visible = true
				Template.Parent = State.weatherFrame

				timeLabel = Template:FindFirstChild("Label")
				iconLabel = Template:FindFirstChild("Icon")
			end
			return true
		end

		Context.connections:connect(timeUpdateRemote.OnClientEvent, function(timeOfDay, remaining)
			if not ensureTemplate() then
				return
			end

			if iconLabel then
				iconLabel.Image = if timeOfDay == "Day"
					then "rbxassetid://92871176483776"
					else "rbxassetid://102636102491014"
			end

			if timeLabel then
				timeLabel.Text = formatTimeDisplay(remaining)
			end
		end)
	end
end
