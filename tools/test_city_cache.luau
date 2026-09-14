local fs, luau = require("@lune/fs"), require("@lune/luau")
local connected = 0
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			callbacks[fn] = true
			connected += 1
			return {
				Disconnect = function()
					if callbacks[fn] then
						callbacks[fn] = nil
						connected -= 1
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for fn in callbacks do
				fn(...)
			end
		end,
	}
end
local function node(name, class)
	local object = {
		Name = name,
		class = class or "Folder",
		children = {},
		attributes = {},
		signals = {},
		ChildAdded = signal(),
		ChildRemoved = signal(),
		Destroying = signal(),
		DescendantAdded = signal(),
		DescendantRemoving = signal(),
		Changed = signal(),
	}
	function object:IsA(kind)
		return kind == self.class or kind == "ValueBase" and self.class == "IntValue"
	end
	function object:FindFirstChild(key)
		return self.children[key]
	end
	function object:GetChildren()
		local list = {}
		for _, v in self.children do
			table.insert(list, v)
		end
		return list
	end
	function object:GetDescendants()
		local list = {}
		for _, v in self.children do
			table.insert(list, v)
			for _, sub in v:GetDescendants() do
				table.insert(list, sub)
			end
		end
		return list
	end
	function object:GetAttribute(key)
		return self.attributes[key]
	end
	function object:GetAttributeChangedSignal(key)
		self.signals[key] = self.signals[key] or signal()
		return self.signals[key]
	end
	function object:add(child)
		self.children[child.Name] = child
		child.Parent = self
		self.ChildAdded:Fire(child)
		local p = self
		while p do
			p.DescendantAdded:Fire(child)
			p = p.Parent
		end
	end
	return object
end
local populationCalls, incomeCalls = 0, 0
local economy = {
	population = function(def, config)
		populationCalls += 1
		return def.Population * config.children.BuildingLevel.Value
	end,
	income = function(def, config)
		incomeCalls += 1
		return def.Income * config.children.BuildingLevel.Value
	end,
}
local root = { config = { BuildingConfig = { Bank = { Population = 10, Income = 4 } } } }
local systems = { Parent = root }
local folder = { Parent = systems, BuildingEconomy = economy }
local cache = luau.load(
	fs.readFile("src/server/systems/economy/IncomeSystem/CityCache.luau"),
	{
		environment = {
			script = { Parent = { Parent = folder } },
			require = function(m)
				assert(m)
				return m
			end,
		},
	}
)()
local plot, buildings, placed = node("Plot1"), node("Buildings"), node("Placed")
plot:add(buildings)
buildings:add(placed)
local function bank(id)
	local model, config = node(id, "Model"), node("Config")
	model.attributes.BuildingType = "Bank"
	model:add(config)
	for name, value in { BuildingLevel = 1, CollectedIncome = 0 } do
		local v = node(name, "IntValue")
		v.Value = value
		config:add(v)
	end
	placed:add(model)
	return model, config.children.BuildingLevel
end
local first, level = bank("one")
assert(cache.get(plot).population == 10 and cache.get(plot).list[1].rate == 4)
for _ = 1, 1000 do
	cache.get(plot)
end
assert(populationCalls == 1 and incomeCalls == 1, "Unchanged city rescanned")
level.Value = 3
level.Changed:Fire(3)
assert(cache.get(plot).population == 30 and incomeCalls == 2)
local second = bank("two")
assert(cache.get(plot).population == 40)
placed.children.one = nil
first.Parent = nil
placed.ChildRemoved:Fire(first)
assert(cache.get(plot).population == 10 and #cache.get(plot).list == 1)
second.attributes.BuildingType = "Unknown"
second.signals.BuildingType:Fire()
assert(cache.get(plot).population == 0 and cache.get(plot).list[1].rate == 0)
plot.Destroying:Fire()
assert(connected == 0, "Cache leaked connections on plot destruction")
print("PASS: city cache unchanged reads, level/type invalidation, additions/removals, population totals and teardown")
