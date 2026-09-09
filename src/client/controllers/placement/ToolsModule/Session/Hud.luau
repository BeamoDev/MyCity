-- Hud: focused implementation for Session.
return function(Context)
	local State = Context.State
	local player = Context.player

	function Context.disableOtherUI()
		local HUD = Context.HUD
		if not HUD then
			return
		end
		local placementMobileGui = Context.placementMobileGui
		if placementMobileGui then
			placementMobileGui.Visible = true
		end

		HUD.Buttons.Visible = false
		HUD.Frames.Visible = false
		HUD.CashDisplay.Visible = false
		HUD.FriendBoost.Visible = false
	end

	function Context.restoreUI()
		local HUD = Context.HUD
		if not HUD then
			return
		end
		local placementMobileGui = Context.placementMobileGui
		if placementMobileGui then
			placementMobileGui.Visible = false
		end

		if player.Data.PlayerInfo.Tutorial.IsInTutorial.Value == false then
			HUD.Buttons.Visible = true
			HUD.Frames.Visible = true
			HUD.CashDisplay.Visible = true
			HUD.FriendBoost.Visible = true
		end
	end

	-- Utility functions
end
