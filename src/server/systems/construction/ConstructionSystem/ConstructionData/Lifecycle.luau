-- Lifecycle: focused implementation for ConstructionData.
return function(Context)
	local State = Context.State
	local ConstructionData = Context.ConstructionData
	local ReplicatedStorage = Context.ReplicatedStorage

	function ConstructionData.clearPlayerConstructions(player)
		ReplicatedStorage.Events.UI.UpdateConstructionUI:FireClient(player, "clear")
	end

	function ConstructionData.init()
		-- Any initialization needed for construction data
	end
end
