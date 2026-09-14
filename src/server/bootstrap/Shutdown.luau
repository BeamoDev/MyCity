-- Register before startup can yield; gameplay supplies its save callback before loading players.
local Players = game:GetService("Players")
local Shutdown = {}
local started, closing, handler = false, false, nil

local function departing(player)
	player:SetAttribute("MyCityLeaving", true)
end

function Shutdown.isClosing()
	return closing
end

function Shutdown.start()
	if started then
		return not closing
	end
	started = true
	Players.PlayerRemoving:Connect(departing)
	local registered = pcall(function()
		game:BindToClose(function()
			closing = true
			for _, player in Players:GetPlayers() do
				departing(player)
			end
			if handler then
				handler()
			end
		end)
	end)
	-- A script synced into an already-closing Play session must not resume startup.
	if not registered then
		closing = true
	end
	return not closing
end

function Shutdown.bind(callback)
	if not Shutdown.start() then
		return false
	end
	assert(not handler, "Player shutdown handler already installed")
	handler = callback
	return true
end

return Shutdown
