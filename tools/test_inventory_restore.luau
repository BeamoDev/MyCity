local fs, luau = require("@lune/fs"), require("@lune/luau")
local function node(fields)
	local t = fields or {}
	function t:FindFirstChild(name)
		return self[name]
	end
	function t:WaitForChild(name)
		return self[name]
	end
	function t:GetChildren()
		return self.children or {}
	end
	function t:GetAttribute(name)
		return self[name]
	end
	function t:SetAttribute(name, value)
		self[name] = value
	end
	function t:IsA(class)
		return self.ClassName == class
	end
	return t
end
local function scenario(failAt, departAt)
	local entries, tools = {}, {}
	local p = node({ Parent = true, UserId = 10 })
	p.Backpack = node({ Parent = p })
	p.Data = node({ Inventory = node({ children = entries }) })
	for i = 1, 60 do
		entries[i] = node({ ClassName = "StringValue", Value = tostring(i) })
	end
	local checkpoints = 0
	local root = {
		services = {
			RestoreBudget = {
				checkpoint = function(player)
					checkpoints += 1
					if checkpoints == departAt then
						player.MyCityLeaving = true
						error("departed")
					end
				end,
			},
			ToolSerialization = {
				decode = function(data)
					if tonumber(data.ToolId) == failAt then
						return nil
					end
					local tool = node({ ClassName = "Tool", ToolId = data.ToolId })
					function tool:Destroy()
						self.destroyed = true
						self.Parent = nil
					end
					table.insert(tools, tool)
					return tool
				end,
			},
		},
	}
	local inventory = luau.load(
		fs.readFile("src/server/systems/economy/InventorySystem.luau"),
		{
			environment = {
				script = { Parent = { Parent = { Parent = root } } },
				require = function(value)
					return value
				end,
				game = {
					GetService = function(_, name)
						if name == "HttpService" then
							return {
								JSONDecode = function(_, value)
									return { ToolId = value }
								end,
							}
						end
						return {}
					end,
				},
				warn = function() end,
			},
		}
	)()
	local ok = inventory.loadInventory(p)
	if failAt or departAt then
		assert(not ok and not p.MyCityInventoryReady)
		for _, tool in tools do
			assert(tool.destroyed and not tool.Parent, "Detached tool leaked after failed restore")
		end
		assert(#entries == 60, "Failure changed saved inventory")
	else
		assert(ok and checkpoints == 60 and #tools == 60 and p.MyCityInventoryReady)
		for _, tool in tools do
			assert(tool.Parent == p.Backpack and not tool.destroyed)
		end
		assert(inventory.loadInventory(p) and #tools == 60, "Repeated restore duplicated inventory")
	end
end
scenario()
scenario(10)
scenario(nil, 10)
print(
	"PASS: budgeted 60-tool inventory restore, unchanged inventory/IDs, idempotence, partial-failure and departure cleanup"
)
