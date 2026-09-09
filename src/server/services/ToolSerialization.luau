local Factory = require(script.Parent.ToolFactory)
local Serialization = {}

function Serialization.encode(tool)
	if not tool:IsA("Tool") or not tool:FindFirstChild("ToolName") or not tool:FindFirstChild("IsValid") then
		return nil
	end
	local function value(name, default)
		local child = tool:FindFirstChild(name)
		return if child then child.Value else default
	end
	return {
		Name = tool.Name,
		ToolId = tool:GetAttribute("ToolId"),
		IsValid = value("IsValid", false),
		BuildingLevel = value("BuildingLevel", 1),
		BuildingXP = value("BuildingXP", 0),
		Mutation = value("Mutation", ""),
		RobuxBuilding = tool:GetAttribute("RobuxBuilding") == true,
	}
end

function Serialization.decode(data)
	if type(data) ~= "table" or type(data.Name) ~= "string" then
		return nil
	end
	local tool = Factory.create(data.Name, data.IsValid == true, data.BuildingLevel, data.BuildingXP, data.Mutation)
	if not tool then
		return nil
	end
	tool:SetAttribute("RobuxBuilding", data.RobuxBuilding == true)
	if type(data.ToolId) == "string" then
		tool:SetAttribute("ToolId", data.ToolId)
	end
	return tool
end

return Serialization
