-- BuildingAlerts: focused implementation for IncomeSystem.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService
	local plotsFolder = Context.plotsFolder

	function Context.showBuildingIncomeAlerts()
		while true do
			local buildingsWithIncome = {}

			for _, plot in ipairs(plotsFolder:GetChildren()) do
				local placedFolder = plot.Buildings:FindFirstChild("Placed")
				if placedFolder then
					for _, building in ipairs(placedFolder:GetChildren()) do
						local configFolder = building:FindFirstChild("Config")
						if configFolder then
							local collectedIncome = configFolder:FindFirstChild("CollectedIncome")
							if collectedIncome and collectedIncome.Value > 0 then
								table.insert(buildingsWithIncome, building)
							end
						end
					end
				end
			end

			local maxAlerts = 5
			local selectedBuildings = {}

			if #buildingsWithIncome > maxAlerts then
				local tempList = {}
				for i, building in ipairs(buildingsWithIncome) do
					tempList[i] = building
				end

				for i = 1, maxAlerts do
					if #tempList == 0 then
						break
					end
					local randomIndex = math.random(1, #tempList)
					table.insert(selectedBuildings, tempList[randomIndex])
					table.remove(tempList, randomIndex)
				end
			else
				selectedBuildings = buildingsWithIncome
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

						-- Apply crime penalty to displayed income for visual feedback
						if crimePercent then
							local crimePenalty = Context.calculateCrimePenalty(crimePercent.Value)
							displayIncome = math.floor(displayIncome * crimePenalty)
						end

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
