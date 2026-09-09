-- Geometry: focused implementation for Session.
return function(Context)
	local State = Context.State
	local Workspace = Context.Workspace
	local GRID_SIZE = Context.GRID_SIZE
	local LOCKED_Y_AXIS = Context.LOCKED_Y_AXIS
	local tool = Context.tool
	local player = Context.player
	local state = Context.state

	function Context.getPlayerPlot()
		local plotData = player:FindFirstChild("Data")
			and player.Data:FindFirstChild("PlotInfo")
			and player.Data.PlotInfo:FindFirstChild("Plot")
		if not plotData or plotData.Value == 0 then
			return nil
		end
		return Workspace.Plots:FindFirstChild("Plot" .. plotData.Value)
	end

	-- Calculate plot boundaries including walls

	function Context.calculatePlotBounds()
		local plot = Context.getPlayerPlot()
		if not plot then
			return nil
		end

		local minX, maxX = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge

		-- Get owned land bounds
		local Owned = plot.Land:FindFirstChild("Owned")
		if Owned then
			for _, tile in pairs(Owned:GetChildren()) do
				if tile:IsA("BasePart") then
					local pos = tile.Position
					local halfSize = tile.Size / 2
					minX = math.min(minX, pos.X - halfSize.X)
					maxX = math.max(maxX, pos.X + halfSize.X)
					minZ = math.min(minZ, pos.Z - halfSize.Z)
					maxZ = math.max(maxZ, pos.Z + halfSize.Z)
				end
			end
		end

		-- Check walls for tighter bounds
		local Walls = plot:FindFirstChild("Walls")
		if Walls then
			for _, wall in pairs(Walls:GetChildren()) do
				if wall:IsA("BasePart") then
					local pos = wall.Position
					local halfSize = wall.Size / 2
					-- Walls define the inner boundary
					if wall.Name:lower():find("north") then
						maxZ = math.min(maxZ, pos.Z - halfSize.Z)
					elseif wall.Name:lower():find("south") then
						minZ = math.max(minZ, pos.Z + halfSize.Z)
					elseif wall.Name:lower():find("east") then
						maxX = math.min(maxX, pos.X - halfSize.X)
					elseif wall.Name:lower():find("west") then
						minX = math.max(minX, pos.X + halfSize.X)
					end
				end
			end
		end

		return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
	end

	-- Constrain position to plot boundaries

	function Context.constrainToPlotBounds(position)
		if not state.plotBounds or not state.previewBuilding then
			return position
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return position
		end

		-- Get the building's half-size considering rotation
		local sizeX, sizeZ = base.Size.X, base.Size.Z
		local angle = math.rad(state.rotationAngle)

		-- Calculate the effective half-size after rotation
		local absCosSizeX = math.abs(math.cos(angle)) * sizeX / 2
		local absSinSizeX = math.abs(math.sin(angle)) * sizeX / 2
		local absCosSizeZ = math.abs(math.cos(angle)) * sizeZ / 2
		local absSinSizeZ = math.abs(math.sin(angle)) * sizeZ / 2

		local halfWidth = absCosSizeX + absSinSizeZ
		local halfDepth = absSinSizeX + absCosSizeZ

		-- Constrain the position
		if
			state.plotBounds.maxX - state.plotBounds.minX < halfWidth * 2
			or state.plotBounds.maxZ - state.plotBounds.minZ < halfDepth * 2
		then
			return position -- Oversized preview remains invalid; avoid reversed math.clamp bounds.
		end
		local constrainedX =
			math.clamp(position.X, state.plotBounds.minX + halfWidth, state.plotBounds.maxX - halfWidth)
		local constrainedZ =
			math.clamp(position.Z, state.plotBounds.minZ + halfDepth, state.plotBounds.maxZ - halfDepth)

		return Vector3.new(constrainedX, position.Y, constrainedZ)
	end

	-- Grid snapping with boundary clamping

	function Context.snapToGrid(position)
		if not state.previewBuilding then
			return Vector3.new(position.X, LOCKED_Y_AXIS, position.Z)
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return Vector3.new(position.X, LOCKED_Y_AXIS, position.Z)
		end

		local sizeX, sizeZ = base.Size.X, base.Size.Z
		local isOddSized = (math.floor(sizeX) % 2 == 1) or (math.floor(sizeZ) % 2 == 1)
		local needsOffset = isOddSized or tool.Name == "Airport" or tool.Name == "Stadium"

		local gridOffsetX, gridOffsetZ = 0, 0
		if needsOffset then
			gridOffsetX, gridOffsetZ = 0.5, 0.5
		end

		local x = math.floor((position.X - gridOffsetX) / GRID_SIZE + 0.5) * GRID_SIZE + gridOffsetX
		local z = math.floor((position.Z - gridOffsetZ) / GRID_SIZE + 0.5) * GRID_SIZE + gridOffsetZ

		local snappedPos = Vector3.new(x, LOCKED_Y_AXIS, z)

		-- Apply boundary constraints after snapping
		return Context.constrainToPlotBounds(snappedPos)
	end

	function Context.getBuildingBounds(buildingCFrame, buildingSize)
		local cf = buildingCFrame
		local size = buildingSize / 2

		local corners = {
			(cf * CFrame.new(-size.X, 0, -size.Z)).Position,
			(cf * CFrame.new(size.X, 0, -size.Z)).Position,
			(cf * CFrame.new(-size.X, 0, size.Z)).Position,
			(cf * CFrame.new(size.X, 0, size.Z)).Position,
		}

		local minX, maxX = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge

		for _, corner in ipairs(corners) do
			minX = math.min(minX, corner.X)
			maxX = math.max(maxX, corner.X)
			minZ = math.min(minZ, corner.Z)
			maxZ = math.max(maxZ, corner.Z)
		end

		return {
			min = Vector3.new(minX, buildingCFrame.Position.Y, minZ),
			max = Vector3.new(maxX, buildingCFrame.Position.Y, maxZ),
		}
	end

	function Context.isFullyWithinPlotBounds(position)
		local plot = Context.getPlayerPlot()
		if not plot then
			return false
		end

		local Owned = plot.Land:FindFirstChild("Owned")
		if not Owned then
			return false
		end

		if not state.previewBuilding then
			return false
		end

		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return false
		end

		local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(state.rotationAngle), 0)
		local tiles = Owned:GetChildren()
		local nx, nz = math.max(1, math.ceil(base.Size.X)), math.max(1, math.ceil(base.Size.Z))
		for x = 0, nx do
			for z = 0, nz do
				local point = cf:PointToWorldSpace(
					Vector3.new(-base.Size.X / 2 + base.Size.X * x / nx, 0, -base.Size.Z / 2 + base.Size.Z * z / nz)
				)
				local found = false
				for _, tile in tiles do
					if tile:IsA("BasePart") then
						local p = tile.CFrame:PointToObjectSpace(point)
						if math.abs(p.X) <= tile.Size.X / 2 + 0.01 and math.abs(p.Z) <= tile.Size.Z / 2 + 0.01 then
							found = true
							break
						end
					end
				end
				if not found then
					return false
				end
			end
		end
		return true
	end

	-- Find nearest valid position if spawn in front fails
end
