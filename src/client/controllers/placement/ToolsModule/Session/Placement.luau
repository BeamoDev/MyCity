-- Placement: focused implementation for Session.
return function(Context)
	local State = Context.State
	local ReplicatedStorage = Context.ReplicatedStorage
	local SoundService = Context.SoundService
	local PLACEMENT_DEBOUNCE_TIME = Context.PLACEMENT_DEBOUNCE_TIME
	local cooldown = Context.cooldown
	local tool = Context.tool
	local state = Context.state

	function Context.isPlacementOnCooldown()
		return tick() < cooldown.expires
	end

	function Context.startPlacementCooldown()
		cooldown.expires = tick() + PLACEMENT_DEBOUNCE_TIME
		cooldown.active = true
		task.spawn(function()
			task.wait(PLACEMENT_DEBOUNCE_TIME)
			cooldown.active = false
		end)
	end

	function Context.placeBuilding()
		if Context.isSellFrameOpen() or not state.isEquipped or not state.previewBuilding or state.placing then
			return
		end
		if not Context.checkPlacementAccess(Context.getPlayerPlot()) then
			Context.cleanup()
			return
		end
		if Context.isPlacementOnCooldown() then
			if SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("ErrorSound") then
				SoundService.SFX.ErrorSound:Play()
			end
			return
		end

		Context.updateBuildingVisuals(true)
		if not state.canPlace then
			ReplicatedStorage.Events.Movement.CannotPlace:FireServer()
			if SoundService:FindFirstChild("SFX") and SoundService.SFX:FindFirstChild("ErrorSound") then
				SoundService.SFX.ErrorSound:Play()
			end
			return
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return
		end

		local generation = state.generation
		local template = ReplicatedStorage.Assets.BuildingPreviews:FindFirstChild(tool.Name)
		local templateBase = template and (template:FindFirstChild("Base") or template:FindFirstChild("Hitbox"))
		if not templateBase or not template.PrimaryPart then
			return
		end
		-- Preview is positioned by Base; the server commits by the authored PrimaryPart.
		local target = Context.getTargetCFrame()
		if not target then
			return
		end
		local cframe = target * templateBase.CFrame:ToObjectSpace(template.PrimaryPart.CFrame)
		Context.startPlacementCooldown()
		state.placing = true
		local ok, success = pcall(function()
			return ReplicatedStorage.Functions.PlaceBlock:InvokeServer(cframe, tool)
		end)
		if state.generation ~= generation then
			return -- Never clear a newer session's in-flight request.
		end
		state.placing = false
		if ok and success then
			Context.cleanup()
		else
			ReplicatedStorage.Events.Movement.CannotPlace:FireServer()
		end
	end

	-- Setup controls
end
