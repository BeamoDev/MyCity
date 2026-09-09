return function(Context)
	local ConstructionTimer = Context.ConstructionTimer
	function ConstructionTimer.syncPlayer(player)
		local items = {}
		for id, timer in Context.State.activeTimers do
			local site = timer.constructionSite
			if
				site
				and site.Parent
				and site:GetAttribute("OwnerUserId") == player.UserId
				and timer.timerActive.Value
			then
				table.insert(items, {
					Id = id,
					Name = timer.displayName,
					Duration = timer.remainingTime,
					TotalDuration = timer.totalTime,
				})
			end
		end
		Context.UpdateConstructionsEvent:FireClient(player, "snapshot", items)
	end
end
