local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function node(fields)
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end
local original = r.Instance.new("Part")
original.Anchored = true
original.Size = r.Vector3.new(10, 20, 10)
local source = r.Instance.new("Model")
source.Name = "Bank"
local root = original:Clone()
root.Name, root.Parent = "Base", source
source.PrimaryPart = root
local roof = original:Clone()
roof.Name, roof.Parent = "Roof", source
local behavior = r.Instance.new("Script")
behavior.Name, behavior.Parent = "Legacy", source
local preparations = 0
r.implementMethod("Model", "GetBoundingBox", function()
	return r.CFrame.identity, r.Vector3.new(10, 20, 10)
end)
r.implementMethod("Model", "GetScale", function(model)
	return model:GetAttribute("MockScale") or 1
end)
r.implementMethod("Model", "ScaleTo", function(model, scale)
	preparations += 1
	model:SetAttribute("MockScale", scale)
end)
r.implementMethod("Model", "GetPivot", function()
	return r.CFrame.identity
end)
r.implementMethod("Model", "PivotTo", function(model, cf)
	model:SetAttribute("MockPivot", cf)
end)
local replicated = node({ Assets = node({ Buildings = node({ Bank = source }) }) })
local visuals = luau.load(fs.readFile("src/server/services/HeldBuildingVisual.luau"), {
	environment = {
		Instance = r.Instance,
		CFrame = r.CFrame,
		Vector3 = r.Vector3,
		game = {
			GetService = function(_, name)
				return if name == "ServerStorage" then replicated.Assets else replicated
			end,
		},
		warn = function() end,
	},
})()
local uid = 0
local factory = luau.load(fs.readFile("src/server/services/ToolFactory.luau"), {
	environment = {
		Instance = r.Instance,
		script = {
			Parent = {
				HeldBuildingVisual = visuals,
				Parent = {
					config = {
						BuildingConfig = {
							Bank = { DisplayName = "Bank", ImageId = 123 },
							MissingVisual = {},
						},
					},
				},
			},
		},
		require = function(module)
			return module
		end,
		game = {
			GetService = function()
				return {
					GenerateGUID = function()
						uid += 1
						return tostring(uid)
					end,
				}
			end,
		},
	},
})()
local tool = factory.create("Bank", true, 7, 230, "Gold")
assert(tool:IsA("Tool") and tool.RequiresHandle and not tool.CanBeDropped)
assert(tool.ToolName.Value == "Bank" and tool.IsValid.Value and tool.BuildingLevel.Value == 7)
assert(tool.BuildingXP.Value == 230 and tool.Mutation.Value == "Gold" and tool.TextureId == "rbxassetid://123")
local visual = tool:FindFirstChild("HeldBuildingVisual")
assert(visual and not visual:FindFirstChild("Legacy") and math.abs(visual:GetAttribute("MockScale") - 0.085) < 0.0001)
assert(source.Legacy and source.Base.Anchored and source.Base.Size.Y == 20, "Authored template was changed")
for _, part in visual:GetDescendants() do
	if part:IsA("BasePart") then
		assert(not part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and part.Massless)
		local weld = part:FindFirstChild("HeldBuildingWeld")
		assert(weld and weld.Part0 == tool.Handle and weld.Part1 == part)
	end
end
local second = factory.create("Bank", false, 1, 0)
assert(preparations == 1, "Repeated held models were sanitized/scaled again")
assert(second.HeldBuildingVisual.Base.HeldBuildingWeld.Part0 == second.Handle)
assert(second.HeldBuildingVisual.Base.HeldBuildingWeld.Part0 ~= tool.Handle, "Cached weld points to another tool")
assert(not tool:FindFirstChild("Init") and not tool:FindFirstChild("ToolModel"))
local other = factory.create("MissingVisual", false, 1, 0)
assert(
	other and not other.RequiresHandle and not other:FindFirstChild("Handle"),
	"Missing cosmetic model must not erase inventory"
)
assert(other:GetAttribute("ToolId") ~= tool:GetAttribute("ToolId"))
assert(factory.create("NotInCatalogue") == nil)
local serialization = luau.load(fs.readFile("src/server/services/ToolSerialization.luau"), {
	environment = {
		script = { Parent = { ToolFactory = factory } },
		require = function(module)
			return module
		end,
	},
})()
tool:SetAttribute("RobuxBuilding", true)
local restored = serialization.decode(serialization.encode(tool))
assert(restored:GetAttribute("ToolId") == tool:GetAttribute("ToolId") and restored:GetAttribute("RobuxBuilding"))
assert(restored.BuildingLevel.Value == 7 and restored.BuildingXP.Value == 230 and restored.Mutation.Value == "Gold")
assert(restored.IsValid.Value and restored.ToolName.Value == "Bank")
print(
	"PASS: template-free tools, miniature scale/weld contract, script stripping, untouched source, missing visual fallback, unique IDs and saved metadata round trip"
)
