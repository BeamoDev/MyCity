local ExpansionSystem = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plotsFolder = Workspace:WaitForChild("Plots")
local GRID_WIDTH = 10
local CENTER_TILES = { 9, 10, 19, 20 }
local PRICE_BANDS = { 500, 2000, 8000, 20000, 50000, 120000, 250000, 500000, 1000000 }

local UnauthorizedActionEvent = ReplicatedStorage.Events.Movement:WaitForChild("Unauthorized")

local function getTileNumber(tile)
	return tonumber(tile.Name:match("Tile(%d+)"))
end

local function getTilePosition(tileNum)
	return Vector2.new((tileNum - 1) % GRID_WIDTH, math.floor((tileNum - 1) / GRID_WIDTH))
end

local function calculateTilePrice(tileNum)
	local tilePos = getTilePosition(tileNum)
	local minDistance = math.huge

	for _, centerTile in ipairs(CENTER_TILES) do
		local centerPos = getTilePosition(centerTile)
		local distance = math.abs(centerPos.X - tilePos.X) + math.abs(centerPos.Y - tilePos.Y)
		minDistance = math.min(minDistance, distance)
	end

	local bandIndex = math.clamp(math.floor(minDistance), 0, #PRICE_BANDS)
	return PRICE_BANDS[bandIndex + 1] or PRICE_BANDS[#PRICE_BANDS]
end

local function isAdjacentToOwned(tile, ownedFolder)
	local thisNum = getTileNumber(tile)
	if not thisNum then
		return false
	end

	local thisRow = math.floor((thisNum - 1) / GRID_WIDTH)
	for _, ownedTile in pairs(ownedFolder:GetChildren()) do
		local ownedNum = getTileNumber(ownedTile)
		if ownedNum then
			local ownedRow = math.floor((ownedNum - 1) / GRID_WIDTH)
			if
				(ownedRow == thisRow and math.abs(ownedNum - thisNum) == 1)
				or (math.abs(ownedNum - thisNum) == GRID_WIDTH)
			then
				return true
			end
		end
	end

	return false
end

local function removeExpansionScenery(tile)
	for _, child in pairs(tile:GetChildren()) do
		if child.Name == "LockedScenery" or child.Name == "ExpansionPrompt" then
			child:Destroy()
		end
	end
end

function ExpansionSystem.updateExpansionTiles(player)
	local plotData = player:FindFirstChild("Data")
		and player.Data:FindFirstChild("PlotInfo")
		and player.Data.PlotInfo:FindFirstChild("Plot")
	if not plotData then
		return
	end

	local plotNumber = plotData.Value
	local plot = plotsFolder:FindFirstChild("Plot" .. plotNumber)
	if not plot then
		return
	end

	ExpansionSystem.updateExpansionTilesForPlayer(plot, player.UserId)
end

function ExpansionSystem.updateExpansionTilesForPlayer(plot, plotOwner)
	local owned = plot.Land:FindFirstChild("Owned")
	local locked = plot.Land:FindFirstChild("Locked")

	if not owned or not locked then
		return
	end

	for _, tile in pairs(locked:GetChildren()) do
		tile.Color = Color3.fromRGB(48, 131, 59)

		if isAdjacentToOwned(tile, owned) and not tile:FindFirstChild("ExpansionPrompt") then
			removeExpansionScenery(tile)

			local expansionPart = ReplicatedStorage.Assets.Expansion.Expansion.ExpansionPrompt:Clone()
			expansionPart.CFrame = tile.CFrame + Vector3.new(0, 2, 0)
			expansionPart.Parent = tile

			local prompt = expansionPart:WaitForChild("PurchaseLand")
			local price = calculateTilePrice(getTileNumber(tile))

			expansionPart.Objects.Display.SurfaceGui.Cash.Text = "$" .. price
			prompt.ActionText = "$" .. price

			prompt.Triggered:Connect(function(triggeringPlayer)
				if
					not require(script.Parent.Parent.security.RequestGuard).ready(triggeringPlayer)
					or tile.Parent ~= locked
				then
					return
				end
				if triggeringPlayer.UserId ~= plotOwner then
					UnauthorizedActionEvent:FireClient(triggeringPlayer)
					return
				end

				local leaderstats = triggeringPlayer:WaitForChild("leaderstats")
				local Cash = leaderstats:FindFirstChild("Cash")

				if Cash and Cash.Value >= price then
					Cash.Value -= price
					tile.Parent = owned
					tile.Color = Color3.fromRGB(52, 142, 64)
					tile.Size = Vector3.new(5, 0.2, 5)

					local ownedTilesFolder = triggeringPlayer:FindFirstChild("Data"):FindFirstChild("OwnedTiles")
					if ownedTilesFolder then
						local tileNumber = getTileNumber(tile)
						if tileNumber and not ownedTilesFolder:FindFirstChild("Tile" .. tileNumber) then
							local tileValue = Instance.new("IntValue")
							tileValue.Name = "Tile" .. tileNumber
							tileValue.Value = tileNumber
							tileValue.Parent = ownedTilesFolder
						end
					end

					expansionPart:Destroy()
					ExpansionSystem.updateExpansionTilesForPlayer(plot, plotOwner)
				else
					game.ReplicatedStorage.Events.Notifications.BrokeAhh:FireClient(triggeringPlayer)
				end
			end)
		end
	end
end

function ExpansionSystem.init() end

return ExpansionSystem
