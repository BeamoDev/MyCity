-- Collision: focused implementation for Session.
return function(Context)
	local State = Context.State
	local Workspace = Context.Workspace
	local LOCKED_Y_AXIS = Context.LOCKED_Y_AXIS
	local SPAWN_DISTANCE = Context.SPAWN_DISTANCE
	local player = Context.player
	local state = Context.state

	function Context.checkCollision()
		if not state.previewBuilding then
			return false
		end

		local buildingBase = state.previewBuilding:FindFirstChild("Base")
			or state.previewBuilding:FindFirstChild("Hitbox")
		if not buildingBase then
			return false
		end

		local plot = Context.getPlayerPlot()
		if not plot then
			return false
		end

		-- Only other buildings' Base footprints block; land coverage is checked separately.
		return Context.Rules.blockingBuilding(plot, buildingBase.CFrame, buildingBase.Size) ~= nil
	end

	-- Validation

	function Context.findNearestValidPosition(startPos)
		local plot = Context.getPlayerPlot()
		if not plot then
			return nil
		end

		local Owned = plot.Land:FindFirstChild("Owned")
		if not Owned then
			return nil
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return nil
		end

		local bestPosition = nil
		local bestDistance = math.huge

		-- Check all owned tiles for a valid position
		for _, tile in pairs(Owned:GetChildren()) do
			if tile:IsA("BasePart") then
				local tilePos = tile.Position
				local snappedPos = Context.snapToGrid(Vector3.new(tilePos.X, LOCKED_Y_AXIS, tilePos.Z))

				state.previewBuilding:SetPrimaryPartCFrame(CFrame.new(snappedPos))

				if not Context.checkCollision() and Context.isFullyWithinPlotBounds(snappedPos) then
					local distance = (snappedPos - startPos).Magnitude
					if distance < bestDistance then
						bestDistance = distance
						bestPosition = snappedPos
					end
				end
			end
		end

		return bestPosition
	end

	-- Find a valid spawn position in front of the player

	function Context.findValidSpawnPosition()
		local character = Context.player.Character
		local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or not state.previewBuilding then
			return nil
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return nil
		end

		-- Get player's forward direction
		local lookDirection = humanoidRootPart.CFrame.LookVector
		local buildingHalfSize = math.max(base.Size.X, base.Size.Z) / 2

		-- Start checking positions from closest to furthest
		for distance = buildingHalfSize + 3, SPAWN_DISTANCE + buildingHalfSize, 2 do
			local testPosition = humanoidRootPart.Position + (lookDirection * distance)
			testPosition = Vector3.new(testPosition.X, LOCKED_Y_AXIS, testPosition.Z)

			-- Snap to grid and constrain to bounds
			local snappedPos = Context.snapToGrid(testPosition)

			-- Check if this position is valid (no collisions)
			state.previewBuilding:SetPrimaryPartCFrame(CFrame.new(snappedPos))

			if not Context.checkCollision() and Context.isFullyWithinPlotBounds(snappedPos) then
				return snappedPos
			end
		end

		-- If no valid position in front, find the nearest valid position
		return Context.findNearestValidPosition(humanoidRootPart.Position)
	end

	-- Check collision at specific position

	function Context.checkCollisionAtPosition(position)
		if not state.previewBuilding then
			return false
		end

		local buildingBase = state.previewBuilding:FindFirstChild("Base")
			or state.previewBuilding:FindFirstChild("Hitbox")
		if not buildingBase then
			return false
		end

		local plot = Context.getPlayerPlot()
		if not plot then
			return false
		end

		local testCFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(state.rotationAngle), 0)
		return Context.Rules.blockingBuilding(plot, testCFrame, buildingBase.Size) ~= nil
	end

	-- Visual updates
end
