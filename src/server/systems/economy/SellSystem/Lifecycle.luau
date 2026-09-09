-- Lifecycle: focused implementation for SellSystem.
return function(Context)
	local State = Context.State
	local SellSystem = Context.SellSystem
	local Guard = Context.Guard
	local SellItemEvent = Context.SellItemEvent
	local OpenSellUIEvent = Context.OpenSellUIEvent

	function SellSystem.init()
		if State.started then
			return
		end
		State.started = true
		Context.bindWorldPrompt()

		SellItemEvent.OnServerEvent:Connect(function(player, buildingType)
			Guard.run(player, "Sell", SellSystem.sellBuilding, buildingType)
		end)

		OpenSellUIEvent.OnServerEvent:Connect(function(player)
			if Guard.ready(player) then
				SellSystem.updateSellUI(player)
			end
		end)
	end
end
