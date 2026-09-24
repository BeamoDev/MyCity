local Ownership = require(script.Parent.Parent.Parent.Parent.Parent.services.GamePassOwnership)
local RarityColors = require(game:GetService("ReplicatedStorage").shared.ui.RarityColors)
-- Visuals: focused implementation for ConstructionTimer.
return function(Context)
	local State = Context.State
	local TweenService = Context.TweenService
	local MarketplaceService = Context.MarketplaceService
	local GAME_PASS_ID2 = Context.GAME_PASS_ID2

	function Context.ownsHalfConstructionSpeedGamePass(player)
		return Ownership.has(player, GAME_PASS_ID2)
	end

	function Context.calculateTweenDistance(size)
		local sizeToStudMapping = {
			["2x2"] = 2,
			["3x3"] = 3,
			["4x4"] = 4,
			["5x5"] = 5,
			["6x6"] = 6,
		}
		return sizeToStudMapping[size] or 4
	end

	function Context.formatTime(seconds)
		if seconds <= 0 then
			return "0"
		end

		local days = math.floor(seconds / 86400)
		seconds = seconds % 86400
		local hours = math.floor(seconds / 3600)
		seconds = seconds % 3600
		local minutes = math.floor(seconds / 60)
		local secs = seconds % 60

		if days > 0 then
			return string.format("%d:%02d:%02d:%02d", days, hours, minutes, secs)
		elseif hours > 0 then
			return string.format("%d:%02d:%02d", hours, minutes, secs)
		elseif minutes > 0 then
			return string.format("%d:%02d", minutes, secs)
		else
			return string.format("%d", secs)
		end
	end

	function Context.updateConstructionBillboard(constructionSite, timeleft, rarity, displayName)
		if not constructionSite or not constructionSite.Parent then
			return
		end
		local structurename = constructionSite:FindFirstChild("Base")
			and constructionSite.Base:FindFirstChild("ConstructionInfo")
			and constructionSite.Base.ConstructionInfo.Container.BuildingName
		if structurename then
			-- Use displayName if provided, otherwise use buildingType
			structurename.Text = displayName or constructionSite:GetAttribute("BuildingType") or constructionSite.Name
			structurename.TextColor3 = RarityColors[rarity] or RarityColors.Common
		end
		local percentageLabel = constructionSite:FindFirstChild("Base")
			and constructionSite.Base:FindFirstChild("ConstructionInfo")
			and constructionSite.Base.ConstructionInfo.Container.TimeLeft
		if percentageLabel then
			percentageLabel.Text = Context.formatTime(timeleft)
		end
	end

	function Context.tweenBuildingTransition(constructionSite, newBuilding, size)
		if not constructionSite or not constructionSite.Parent or not constructionSite.PrimaryPart then
			return
		end
		if not newBuilding or not newBuilding.Parent or not newBuilding.PrimaryPart then
			return
		end

		local tweenDistance = Context.calculateTweenDistance(size)

		local siteTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local siteTweenGoal = {
			CFrame = constructionSite.PrimaryPart.CFrame - Vector3.new(0, tweenDistance * 2, 0),
		}
		local siteTween = TweenService:Create(constructionSite.PrimaryPart, siteTweenInfo, siteTweenGoal)

		local buildingTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local buildingTweenGoal = {
			CFrame = newBuilding.PrimaryPart.CFrame,
		}

		newBuilding:SetPrimaryPartCFrame(newBuilding.PrimaryPart.CFrame - Vector3.new(0, tweenDistance, 0))
		local buildingTween = TweenService:Create(newBuilding.PrimaryPart, buildingTweenInfo, buildingTweenGoal)

		siteTween:Play()
		buildingTween:Play()

		siteTween.Completed:Connect(function()
			if constructionSite and constructionSite.Parent then
				constructionSite:Destroy()
			end
		end)
	end
end
