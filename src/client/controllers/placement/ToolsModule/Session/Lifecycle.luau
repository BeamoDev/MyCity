-- Lifecycle: focused implementation for Session.
return function(Context)
	local State = Context.State
	local Session = Context.Session
	local ReplicatedStorage = Context.ReplicatedStorage
	local initializedTools = Context.initializedTools
	local tool = Context.tool
	local player = Context.player
	local state = Context.state
	local ownership = Context.cooldown

	function Context.cleanup()
		local wasActive = state.isEquipped
		state.isEquipped = false
		-- Every submodule shares this table: reset it in place, never replace it.
		for _, connection in pairs(state.connections) do
			connection:Disconnect()
		end
		table.clear(state.connections)
		for _, key in { "previewBuilding", "arrowsGui", "baseSelection" } do
			if state[key] then
				state[key]:Destroy()
				state[key] = nil
			end
		end
		Context.clearTileHighlights()
		state.rotationAngle = 0
		state.canPlace = false
		state.isDragging = false
		state.targetPosition = nil
		state.motion = nil
		state.motionTargetAngle = nil
		state.plotBounds = nil
		state.placing = false
		state.nextVisualCheck, state.visualPosition, state.visualAngle = nil, nil, nil
		state.generation = (state.generation or 0) + 1
		if wasActive and ownership.activeTool == tool then
			ownership.activeTool, ownership.activeCleanup = nil, nil
			player:SetAttribute("MyCityPlacementTool", nil)
			Context.restoreUI()
		end
	end

	function Context.isSellFrameOpen()
		local frames = Context.HUD and Context.HUD:FindFirstChild("Frames")
		local sell = frames and frames:FindFirstChild("SellTool")
		return sell ~= nil and sell.Visible
	end

	-- Place building

	function Context.onEquipped()
		-- Deferred Equipped callbacks may arrive after Satchel has selected another tool.
		if tool.Parent ~= player.Character then
			return
		end
		-- Selling only equips the existing held miniature; never acquire placement UI/input.
		if Context.isSellFrameOpen() then
			if state.isEquipped then
				Context.cleanup()
			end
			return
		end
		if state.isEquipped or not Context.HUD or player:GetAttribute("MyCityIntroActive") then
			return
		end
		local plot = Context.getPlayerPlot()
		if not Context.checkPlacementAccess(plot) then
			return
		end
		if ownership.activeCleanup then
			ownership.activeCleanup()
		end
		ownership.activeTool, ownership.activeCleanup = tool, Context.cleanup
		state.isEquipped = true
		Context.disableOtherUI()
		if not plot then
			Context.cleanup()
			return
		end

		-- Calculate plot boundaries
		state.plotBounds = Context.calculatePlotBounds()

		local buildingModel = ReplicatedStorage.Assets.BuildingPreviews:FindFirstChild(tool.Name)
		if not buildingModel then
			Context.cleanup()
			return
		end

		state.previewBuilding = buildingModel:Clone()
		state.previewBuilding.Name = "Preview_" .. tool.Name

		local primaryPart = state.previewBuilding:FindFirstChild("Base")
			or state.previewBuilding:FindFirstChild("Hitbox")
		if not primaryPart then
			for _, child in pairs(state.previewBuilding:GetChildren()) do
				if child:IsA("BasePart") then
					primaryPart = child
					break
				end
			end
		end

		if not primaryPart then
			Context.cleanup()
			return
		end

		state.previewBuilding.PrimaryPart = primaryPart
		Context.preparePreviewModel()
		Context.createTileHighlights()
		Context.addBuildingIndicators()

		-- Find valid spawn position in front of player
		local spawnPosition = Context.findValidSpawnPosition()

		if not spawnPosition then
			-- Fallback to first owned tile if no valid position found
			local ownedFolder = plot.Land:FindFirstChild("Owned")
			if ownedFolder and #ownedFolder:GetChildren() > 0 then
				local firstTile = ownedFolder:GetChildren()[1]
				spawnPosition = Context.snapToGrid(firstTile.Position)
			end
		end

		if spawnPosition then
			state.targetPosition = spawnPosition
			state.previewBuilding:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
		end

		local misc = workspace:FindFirstChild("Misc")
		local previews = misc and misc:FindFirstChild("PlayerPreviews")
		if not previews then
			Context.cleanup()
			return
		end
		state.previewBuilding.Parent = previews

		Context.setupControls()
		local owned = plot:FindFirstChild("Land") and plot.Land:FindFirstChild("Owned")
		if owned then
			local function landChanged()
				state.plotBounds, state.nextVisualCheck = nil, nil
				Context.createTileHighlights()
				Context.updateBuildingVisuals(true)
			end
			state.connections.landAdded = owned.ChildAdded:Connect(landChanged)
			state.connections.landRemoved = owned.ChildRemoved:Connect(landChanged)
		end
		Context.updateBuildingVisuals(true)
		player:SetAttribute("MyCityPlacementTool", tool.Name)
	end

	function Session.start()
		tool.Equipped:Connect(Context.onEquipped)

		tool.Unequipped:Connect(Context.cleanup)

		tool.AncestryChanged:Connect(function()
			if tool.Parent ~= player.Character then
				Context.cleanup()
			end
		end)

		local cleanupConnection =
			ReplicatedStorage.Events.Movement.CleanupPreview.OnClientEvent:Connect(Context.cleanup)
		local introConnection = player:GetAttributeChangedSignal("MyCityIntroActive"):Connect(function()
			if tool.Parent == player.Character then
				Context.onEquipped()
			end
		end)
		local sellConnection
		local function bindHud(hud)
			Context.cleanup()
			if sellConnection then
				sellConnection:Disconnect()
				sellConnection = nil
			end
			Context.HUD = hud
			Context.placementMobileGui = hud and hud:FindFirstChild("MobilePlacement")
			local frames = hud and hud:FindFirstChild("Frames")
			local sell = frames and frames:FindFirstChild("SellTool")
			if sell then
				sellConnection = sell:GetPropertyChangedSignal("Visible"):Connect(function()
					if sell.Visible and state.isEquipped then
						Context.cleanup()
					end
					-- Closing a sale waits for the next equip, avoiding placement of a sold tool.
				end)
			end
		end
		bindHud(Context.HUD)
		local guiAdded, guiRemoved
		if Context.playerGui then
			guiAdded = Context.playerGui.ChildAdded:Connect(function(hud)
				if hud.Name == "HUD" and hud:IsA("ScreenGui") then
					bindHud(hud)
					if tool.Parent == player.Character then
						Context.onEquipped()
					end
				end
			end)
			guiRemoved = Context.playerGui.ChildRemoved:Connect(function(hud)
				if hud == Context.HUD then
					bindHud(nil)
				end
			end)
		end

		tool.Destroying:Connect(function()
			if guiAdded then
				guiAdded:Disconnect()
			end
			if guiRemoved then
				guiRemoved:Disconnect()
			end
			if sellConnection then
				sellConnection:Disconnect()
			end
			introConnection:Disconnect()
			cleanupConnection:Disconnect()
			Context.cleanup()
			initializedTools[tool] = nil
		end)
		if tool.Parent == player.Character then
			Context.onEquipped()
		end
	end
end
