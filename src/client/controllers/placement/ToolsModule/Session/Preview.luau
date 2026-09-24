-- Preview: focused implementation for Session.
return function(Context)
	local State = Context.State
	local VALID_COLOR = Context.VALID_COLOR
	local INVALID_COLOR = Context.INVALID_COLOR
	local state = Context.state

	function Context.updateBuildingVisuals(force)
		if not state.previewBuilding then
			return
		end

		local base = state.previewBuilding:FindFirstChild("Base")
		local hitboxPart = state.previewBuilding:FindFirstChild("Hitbox")

		if not base then
			return
		end

		local position = state.targetPosition or base.Position
		local now = os.clock()
		local unchanged = state.visualPosition == position and state.visualAngle == state.rotationAngle
		if not force and now < (state.nextVisualCheck or 0) then
			return
		end
		state.nextVisualCheck = now + (if unchanged then 0.1 else 1 / 30)
		state.visualPosition, state.visualAngle = position, state.rotationAngle
		-- Same rules as the server (shared.util.PlacementRules); the reason is shown if placing fails.
		state.placementReason = if not Context.isFullyWithinPlotBounds(position)
			then "OutsideLand"
			elseif Context.checkCollisionAtPosition(position) then "Overlap"
			else nil
		local isValid = state.placementReason == nil and not Context.isPlacementOnCooldown()
		state.canPlace = isValid

		-- Update the actual Hitbox part color
		if hitboxPart and hitboxPart:IsA("BasePart") then
			local color = isValid and VALID_COLOR or INVALID_COLOR
			hitboxPart.Color = color
			-- Keep it transparent
			hitboxPart.Transparency = 0.6
		end
		-- Authored controls can arrive after the Tool or HUD replicates.
		local mobile = Context.placementMobileGui
		local frame = mobile and mobile:FindFirstChild("PlacementMobile")
		local placeButton = frame and frame:FindFirstChild("Place")
		if placeButton then
			local grey = placeButton:FindFirstChild("GreyGradient")
			local green = placeButton:FindFirstChild("GreenGradient")
			local stroke = placeButton:FindFirstChild("UIStroke")
			local button = placeButton:FindFirstChild("Button")
			if stroke then
				stroke.Color = isValid and Color3.fromRGB(35, 93, 34) or Color3.fromRGB(93, 93, 93)
			end
			if grey then
				grey.Enabled = not isValid
			end
			if green then
				green.Enabled = isValid
			end
			if button then
				button.Interactable = isValid
			end
		end
	end

	-- Tile highlights

	function Context.createTileHighlights()
		Context.clearTileHighlights()
		local plot = Context.getPlayerPlot()
		local land = plot and plot:FindFirstChild("Land")
		local owned = land and land:FindFirstChild("Owned")
		if not owned then
			return
		end
		for _, tile in owned:GetChildren() do
			if tile:IsA("BasePart") then
				local highlight = Instance.new("SelectionBox")
				highlight.Name = "MyCityPlacementLand"
				highlight.Adornee = tile
				highlight.Color3, highlight.SurfaceColor3 = VALID_COLOR, VALID_COLOR
				highlight.LineThickness = 0.05
				highlight.Transparency, highlight.SurfaceTransparency = 0.3, 0.7
				highlight.Parent = tile
				table.insert(state.tileHighlights, highlight)
			end
		end
	end

	function Context.clearTileHighlights()
		for _, highlight in pairs(state.tileHighlights) do
			if highlight then
				highlight:Destroy()
			end
		end
		state.tileHighlights = {}
	end

	-- Add visual indicators

	function Context.addBuildingIndicators()
		if not state.previewBuilding then
			return
		end
		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return
		end

		-- Make the actual hitbox part transparent
		local hitboxPart = state.previewBuilding:FindFirstChild("Hitbox")
		if hitboxPart and hitboxPart:IsA("BasePart") then
			hitboxPart.Transparency = 0.6
		end

		-- Add ArrowsGUI if available
		local assets = Context.ReplicatedStorage:WaitForChild("Assets")
		local arrows = assets:FindFirstChild("ArrowsGUI")
		if arrows then
			state.arrowsGui = arrows:Clone()
			state.arrowsGui.Parent = base
			if state.arrowsGui:IsA("BillboardGui") or state.arrowsGui:IsA("SurfaceGui") then
				state.arrowsGui.Adornee = base
				state.arrowsGui.Enabled = true
			end
		end

		-- Add BaseSelection if available with Adornee set to base
		local selection = assets:FindFirstChild("BaseSelection")
		if selection then
			state.baseSelection = selection:Clone()
			state.baseSelection.Adornee = base
			state.baseSelection.Parent = base
		end
	end

	-- Smooth movement

	function Context.preparePreviewModel()
		if not state.previewBuilding then
			return
		end

		for _, part in ipairs(state.previewBuilding:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
			if part:IsA("ProximityPrompt") or part:IsA("Script") or part:IsA("LocalScript") then
				part:Destroy()
			end
			if part:IsA("BillboardGui") or part:IsA("SurfaceGui") then
				part.Enabled = false
			end
		end
	end

	-- Rotation
end
