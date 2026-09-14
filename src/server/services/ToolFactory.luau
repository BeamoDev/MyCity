local HttpService = game:GetService("HttpService")
local BuildingConfig = require(script.Parent.Parent.config.BuildingConfig)
local HeldVisual = require(script.Parent.HeldBuildingVisual)
local ToolFactory = {}

local function addValue(tool, className, name, value)
	local object = Instance.new(className)
	object.Name, object.Value, object.Parent = name, value, tool
end

function ToolFactory.create(buildingName, isCollected, level, xp, mutation)
	if type(buildingName) ~= "string" or not BuildingConfig[buildingName] then
		return nil
	end
	local function integer(value, default, minimum, maximum)
		value = tonumber(value)
		if not value or value ~= value or math.abs(value) == math.huge then
			return default
		end
		return math.clamp(math.floor(value), minimum, maximum)
	end
	level, xp = integer(level, 1, 1, 100), integer(xp, 0, 0, 9e15)
	mutation = if type(mutation) == "string" then mutation else nil
	local definition = BuildingConfig[buildingName]
	local tool = Instance.new("Tool")
	tool.Name = buildingName
	tool.ToolTip = "Equip to place " .. (definition.DisplayName or buildingName) .. "."
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool:SetAttribute("ToolId", HttpService:GenerateGUID(false))
	addValue(tool, "StringValue", "ToolName", buildingName)
	addValue(tool, "BoolValue", "IsValid", isCollected == true)
	addValue(tool, "IntValue", "BuildingLevel", level or 1)
	addValue(tool, "IntValue", "BuildingXP", xp or 0)
	if mutation and mutation ~= "" then
		addValue(tool, "StringValue", "Mutation", mutation)
	end
	if definition.ImageId then
		tool.TextureId = "rbxassetid://" .. tostring(definition.ImageId)
	end
	HeldVisual.attach(tool, buildingName)
	return tool
end
return ToolFactory
