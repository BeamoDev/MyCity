local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(script.Parent.Parent.Parent.security.RequestGuard)
local Range = require(ReplicatedStorage.shared.util.PlacementRange)
local Validation = {}

function Validation.getPlot(player)
	local data = player:FindFirstChild("Data")
	local info = data and data:FindFirstChild("PlotInfo")
	local number = info and info:FindFirstChild("Plot")
	return number and Workspace.Plots:FindFirstChild("Plot" .. number.Value)
end

function Validation.ownsBuilding(player, building)
	if not Guard.ready(player) or typeof(building) ~= "Instance" or not building:IsA("Model") then
		return false
	end
	local plot = Validation.getPlot(player)
	return plot ~= nil
		and building.Parent == plot.Buildings.Placed
		and type(building:GetAttribute("BuildingID")) == "string"
end

function Validation.ownsTool(player, tool)
	return Guard.ready(player)
		and typeof(tool) == "Instance"
		and tool:IsA("Tool")
		and (tool.Parent == player:FindFirstChild("Backpack") or tool.Parent == player.Character)
		and tool:FindFirstChild("ToolName") ~= nil
		and tool:FindFirstChild("IsValid") ~= nil
end

function Validation.placement(player, cframe, tool)
	if not Validation.ownsTool(player, tool) or typeof(cframe) ~= "CFrame" then
		return false
	end
	for _, component in { cframe:GetComponents() } do
		if component ~= component or math.abs(component) == math.huge then
			return false
		end
	end
	local _, yaw, _ = cframe:ToOrientation()
	if cframe.UpVector:Dot(Vector3.yAxis) < 0.9999 then
		return false
	end
	local quarterTurn = yaw / (math.pi / 2)
	if math.abs(quarterTurn - math.round(quarterTurn)) > 0.001 then
		return false
	end
	local plot = Validation.getPlot(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not Range.isNear(root.Position, plot) then
		return false
	end
	local template = game:GetService("ServerStorage").Buildings:FindFirstChild(tool.Name)
	local base = template and (template:FindFirstChild("Base") or template:FindFirstChild("Hitbox"))
	if not plot or not base or not base:IsA("BasePart") or not template.PrimaryPart then
		return false
	end
	local baseCFrame = cframe * template.PrimaryPart.CFrame:ToObjectSpace(base.CFrame)
	local half = base.Size / 2
	local owned = plot.Land.Owned:GetChildren()
	local function onOwned(point, checkHeight)
		for _, tile in owned do
			if tile:IsA("BasePart") then
				local position = tile.CFrame:PointToObjectSpace(point)
				if
					math.abs(position.X) <= tile.Size.X / 2 + 0.01
					and math.abs(position.Z) <= tile.Size.Z / 2 + 0.01
				then
					if
						not checkHeight
						or math.abs(baseCFrame.Position.Y - (tile.Position.Y + tile.Size.Y / 2)) < 0.1
					then
						return true
					end
				end
			end
		end
		return false
	end
	if not onOwned(baseCFrame.Position, true) then
		return false
	end
	-- Sample the whole footprint so gaps between owned tiles cannot be bridged.
	local stepsX, stepsZ = math.max(1, math.ceil(base.Size.X)), math.max(1, math.ceil(base.Size.Z))
	for x = 0, stepsX do
		for z = 0, stepsZ do
			if
				not onOwned(
					baseCFrame:PointToWorldSpace(
						Vector3.new(-half.X + base.Size.X * x / stepsX, 0, -half.Z + base.Size.Z * z / stepsZ)
					),
					false
				)
			then
				return false
			end
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { plot.Buildings.Placed, plot.Buildings.Construction, plot.Land.Locked }
	for _, part in
		Workspace:GetPartBoundsInBox(
			baseCFrame,
			Vector3.new(math.max(0.01, base.Size.X - 0.2), base.Size.Y, math.max(0.01, base.Size.Z - 0.2)),
			overlap
		)
	do
		if part.Name == "Base" or part.Name == "Hitbox" or part:IsDescendantOf(plot.Land.Locked) then
			return false
		end
	end
	return true
end

return Validation
