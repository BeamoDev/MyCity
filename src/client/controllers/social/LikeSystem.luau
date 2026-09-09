local LikesHandler = {}
local connection
function LikesHandler.cleanup()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(game:GetService("ReplicatedStorage"):WaitForChild("shared"):WaitForChild("Network")).wait()
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Events = nil
local LikesFolder = nil
local AlertClientEvent = nil

function LikesHandler.init(playerGui)
	LikesHandler.cleanup()
	Events = ReplicatedStorage:WaitForChild("Events", 5)
	if not Events then
		warn("[LikesHandler] Events folder not found")
		return
	end

	LikesFolder = Events:WaitForChild("Likes", 5)
	if not LikesFolder then
		warn("[LikesHandler] Likes folder not found")
		return
	end

	AlertClientEvent = LikesFolder:WaitForChild("AlertClient", 5)
	if not AlertClientEvent then
		warn("[LikesHandler] AlertClient event not found")
		return
	end

	connection = AlertClientEvent.OnClientEvent:Connect(function(title, message)
		if not message then
			message = title
			title = "City Rating"
		end

		require(script.Parent.Parent.ui.NotificationController).showNotification(
			"CityRating",
			tostring(title) .. ": " .. tostring(message)
		)
	end)
end
return LikesHandler
