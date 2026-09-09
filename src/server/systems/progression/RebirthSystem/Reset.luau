-- Rebirth preserves all city, construction and inventory state.
return function(Context)
	local RebirthSystem = Context.RebirthSystem
	function RebirthSystem.prepareRebirth(player)
		Context.ReplicatedStorage.Events.Movement.CleanupPreview:FireClient(player)
	end
end
