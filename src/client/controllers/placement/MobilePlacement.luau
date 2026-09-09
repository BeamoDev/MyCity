-- HUD-lifetime visibility fallback, even when no building Tool session exists.
local MobilePlacement = {}
function MobilePlacement.bind(hud, scope, cleanupEvent)
	local mobile = hud:FindFirstChild("MobilePlacement")
	if not mobile then
		return
	end
	mobile.Visible = false
	scope:connect(cleanupEvent.OnClientEvent, function()
		mobile.Visible = false
	end)
end
return MobilePlacement
