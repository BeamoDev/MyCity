local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local function node(fields)
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end
local lastClone
local original = r.Instance.new("Part")
original.Anchored = true
original.Size = r.Vector3.new(10, 20, 10)
local function modelClone()
	local root, roof = original:Clone(), original:Clone()
	local script = {
		IsA = function(_, class)
			return class == "LuaSourceContainer"
		end,
		Destroy = function(self)
			self.removed = true
		end,
	}
	local items = { root, roof, script }
	local model = { PrimaryPart = root, removedScript = script, parts = { root, roof } }
	function model:GetDescendants()
		return items
	end
	function model:GetBoundingBox()
		return r.CFrame.identity, r.Vector3.new(10, 20, 10)
	end
	function model:GetScale()
		return 1
	end
	function model:ScaleTo(scale)
		self.scale = scale
	end
	function model:GetPivot()
		return r.CFrame.identity
	end
	function model:PivotTo(cf)
		self.pivot = cf
	end
	function model:Destroy()
		self.destroyed = true
	end
	lastClone = model
	return model
end
local replicated = node({
	Assets = node({
		Buildings = node({
			Bank = {
				IsA = function(_, class)
					return class == "Model"
				end,
				Clone = modelClone,
			},
		}),
	}),
})
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
assert(lastClone.removedScript.removed and math.abs(lastClone.scale - 0.085) < 0.0001)
assert(lastClone.Parent == tool and original.Anchored and original.Size.Y == 20, "Authored template was changed")
for _, part in lastClone.parts do
	assert(not part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and part.Massless)
	local weld = part:FindFirstChild("HeldBuildingWeld")
	assert(weld and weld.Part0 == tool.Handle and weld.Part1 == part)
end
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
