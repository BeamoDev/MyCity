local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(script.Parent.Parent.Parent.security.RequestGuard)
local Range = require(ReplicatedStorage.shared.util.PlacementRange)
local Rules = require(ReplicatedStorage.shared.util.PlacementRules)
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
		return false, "TooFar"
	end
	local template = game:GetService("ServerStorage").Buildings:FindFirstChild(tool.Name)
	local base = template and (template:FindFirstChild("Base") or template:FindFirstChild("Hitbox"))
	if not plot or not base or not base:IsA("BasePart") or not template.PrimaryPart then
		return false
	end
	local baseCFrame = cframe * template.PrimaryPart.CFrame:ToObjectSpace(base.CFrame)
	local tiles = Rules.ownedTiles(plot)
	-- Base must rest on the owned tile under its centre.
	local centreTile = Rules.tileAt(tiles, baseCFrame.Position)
	if not centreTile then
		return false, "OutsideLand"
	end
	if math.abs(baseCFrame.Position.Y - (centreTile.Position.Y + centreTile.Size.Y / 2)) >= 0.1 then
		return false, "Height"
	end
	return Rules.check(plot, baseCFrame, base.Size)
end

return Validation
