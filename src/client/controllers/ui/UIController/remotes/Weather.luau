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
				clearChildrenExceptLayouts(State.weatherFrame)

				Template = script.Parent.Parent:FindFirstChild("WeatherTemplate"):Clone()
				Template.Parent = State.weatherFrame

				timeLabel = Template:FindFirstChild("Label")
				iconLabel = Template:FindFirstChild("Icon")
			end
		end

		Context.connections:connect(timeUpdateRemote.OnClientEvent, function(timeOfDay, remaining)
			ensureTemplate()

			if timeOfDay == "Day" then
				iconLabel.Image = "rbxassetid://92871176483776"
			else
				iconLabel.Image = "rbxassetid://102636102491014"
			end

			if timeLabel then
				timeLabel.Text = formatTimeDisplay(remaining)
			end
		end)
	end
end
