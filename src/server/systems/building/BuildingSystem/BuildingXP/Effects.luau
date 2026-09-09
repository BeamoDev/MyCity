-- Effects: focused implementation for BuildingXP.
return function(Context)
	local State = Context.State
	local pulses = Context.pulses
	local TweenService = Context.TweenService

	function Context.startTextPulseEffect(building, level)
		local configFolder = building:FindFirstChild("Config")
		if not configFolder then
			return
		end

		local hitbox = building:FindFirstChild("Hitbox")
		local billboard = hitbox and hitbox:FindFirstChild("BuildingInfo")
		local buildingInfo = billboard and (billboard:FindFirstChild("Container") or billboard)
		if not buildingInfo then
			return
		end

		local levelLabel = buildingInfo:FindFirstChild("Level") or buildingInfo:FindFirstChild("LevelText")
		if not levelLabel then
			return
		end

		local existingConnection = pulses[levelLabel]
		if existingConnection then
			task.cancel(existingConnection)
			pulses[levelLabel] = nil
		end

		if level < 20 then
			levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- Default white
			return
		end

		-- Determine base and pulse colors based on tier
		local baseColor, pulseColor
		if level >= 100 then
			-- Pink tier
			baseColor = Color3.fromRGB(255, 105, 180)
			pulseColor = Color3.fromRGB(255, 182, 220) -- Lighter pink
		elseif level >= 40 then
			-- Diamond tier
			baseColor = Color3.fromRGB(0, 162, 255)
			pulseColor = Color3.fromRGB(100, 200, 255) -- Lighter blue
		else
			-- Gold tier
			baseColor = Color3.fromRGB(255, 215, 0)
			pulseColor = Color3.fromRGB(255, 255, 100) -- Lighter yellow
		end

		-- Set base color
		levelLabel.TextColor3 = baseColor

		-- Create pulsing effect
		local pulseConnection = task.spawn(function()
			while levelLabel and levelLabel.Parent do
				-- Random delay between pulses (3-8 seconds)
				task.wait(math.random(3, 8))

				if not levelLabel or not levelLabel.Parent then
					break
				end

				-- Pulse to brighter color
				local pulseTween = TweenService:Create(
					levelLabel,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ TextColor3 = pulseColor }
				)
				pulseTween:Play()

				task.wait(0.5)

				if not levelLabel or not levelLabel.Parent then
					break
				end

				-- Return to base color
				local returnTween = TweenService:Create(
					levelLabel,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
					{ TextColor3 = baseColor }
				)
				returnTween:Play()
			end
		end)

		-- Store connection reference for cleanup
		pulses[levelLabel] = pulseConnection
	end

	function Context.applySparkleEffect(building, level)
		local base = building:FindFirstChild("Base")
		if not base then
			return
		end

		local existingSparkles = base:FindFirstChild("LevelSparkles")
		if existingSparkles then
			existingSparkles:Destroy()
		end

		Context.startTextPulseEffect(building, level)

		if level < 20 then
			return
		end

		local sparklesTemplate
		if level >= 100 then
			sparklesTemplate = script.Parent:FindFirstChild("SparklesPink")
		elseif level >= 40 then
			sparklesTemplate = script.Parent:FindFirstChild("SparklesBlue")
		else
			sparklesTemplate = script.Parent:FindFirstChild("SparklesGold")
		end

		if not sparklesTemplate then
			return
		end

		local sparkles = sparklesTemplate:Clone()
		sparkles.Name = "LevelSparkles"
		sparkles.Parent = base
		sparkles.Enabled = true
	end
end
