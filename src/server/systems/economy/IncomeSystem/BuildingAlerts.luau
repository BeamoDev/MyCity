-- BuildingAlerts: focused implementation for IncomeSystem.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService
	local plotsFolder = Context.plotsFolder

	function Context.showBuildingIncomeAlerts()
		while true do
			-- Reservoir sampling caps temporary storage without copying the entire city's list.
			local selectedBuildings, seen = {}, 0
			for _, plot in plotsFolder:GetChildren() do
				local buildings = plot:FindFirstChild("Buildings")
				local placed = buildings and buildings:FindFirstChild("Placed")
				for _, building in (if placed then placed:GetChildren() else {}) do
					local config = building:FindFirstChild("Config")
					local income = config and config:FindFirstChild("CollectedIncome")
					if income and income.Value > 0 then
						seen += 1
						local slot = if seen <= 5 then seen else math.random(1, seen)
						if slot <= 5 then
							selectedBuildings[slot] = building
						end
					end
				end
			end

			for _, building in ipairs(selectedBuildings) do
				local configFolder = building:FindFirstChild("Config")
				local collectedIncome = configFolder and configFolder:FindFirstChild("CollectedIncome")
				local crimePercent = configFolder and configFolder:FindFirstChild("CrimePercent")
				local alertGui = building:FindFirstChild("IncomeAlert")

				if collectedIncome and alertGui and alertGui:IsA("BillboardGui") then
					local textLabel = alertGui:FindFirstChild("Income")
					local cashIcon = alertGui:FindFirstChild("CashIcon")

					if textLabel then
						local displayIncome = collectedIncome.Value

						-- Accrued income already includes the crime penalty.
						textLabel.Text = Context.formatNumberShort(displayIncome)

						-- Change color based on crime level
						if crimePercent and crimePercent.Value > 50 then
							--textLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red for high crime
							textLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green for low crime
						elseif crimePercent and crimePercent.Value > 30 then
							--textLabel.TextColor3 = Color3.fromRGB(255, 255, 100) -- Yellow for medium crime
							textLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green for low crime
						else
							textLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Green for low crime
						end

						alertGui.Enabled = true

						task.spawn(function()
							local textStroke = textLabel:FindFirstChild("UIStroke")

							alertGui.StudsOffset = Vector3.new(0, 1, 0)
							textLabel.TextTransparency = 1

							if textStroke then
								textStroke.Transparency = 1
							end

							if cashIcon then
								cashIcon.ImageTransparency = 1
							end

							local fadeInText = TweenService:Create(
								textLabel,
								TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
								{ TextTransparency = 0 }
							)

							local moveUp = TweenService:Create(
								alertGui,
								TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
								{ StudsOffset = Vector3.new(0, 3.5, 0) }
							)

							local fadeInStroke = nil
							if textStroke then
								fadeInStroke = TweenService:Create(
									textStroke,
									TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
									{ Transparency = 0 }
								)
							end

							fadeInText:Play()
							moveUp:Play()

							if fadeInStroke then
								fadeInStroke:Play()
							end

							if cashIcon then
								local fadeInIcon = TweenService:Create(
									cashIcon,
									TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
									{ ImageTransparency = 0.5 }
								)
								fadeInIcon:Play()
							end

							task.wait(3)
							if not building.Parent or not alertGui.Parent then
								return
							end

							local fadeOutText = TweenService:Create(
								textLabel,
								TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
								{ TextTransparency = 1 }
							)

							local moveDown = TweenService:Create(
								alertGui,
								TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
								{ StudsOffset = Vector3.new(0, 1, 0) }
							)

							local fadeOutStroke = nil
							if textStroke then
								fadeOutStroke = TweenService:Create(
									textStroke,
									TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
									{ Transparency = 1 }
								)
							end

							fadeOutText:Play()
							moveDown:Play()

							if fadeOutStroke then
								fadeOutStroke:Play()
							end

							if cashIcon then
								local fadeOutIcon = TweenService:Create(
									cashIcon,
									TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
									{ ImageTransparency = 1 }
								)
								fadeOutIcon:Play()
							end

							task.wait(0.5)
							alertGui.Enabled = false
						end)
					end
				end
			end

			task.wait(15)
		end
	end
end
