local Schema = require(script.Parent.DataSchema)
-- Relocate historical flags before reconciliation so defaults never mask saved values.
local function folder(parent, name)
	local child = parent:FindFirstChild(name)
	if not child then
		child = Instance.new("Folder")
		child.Name = name
		child.Parent = parent
	end
	assert(child:IsA("Folder"), "Saved folder has wrong class: " .. child:GetFullName())
	return child
end
return function(player, data, stats)
	local info = folder(data, "PlayerInfo")
	for _, name in
		{
			"IsInTutorial",
			"NewPlayer",
			"StarterBuilding",
			"TutorialBankPlaced",
			"CityName",
			"GroupRewardClaimed",
			"LimitedPrompted",
			"FirstRare",
			"FirstLegendary",
			"AvailableIncome",
			"LastUpdate",
			"LastShopReset",
			"LastPlot",
		}
	do
		local old = data:FindFirstChild(name)
		if old and not info:FindFirstChild(name) then
			old.Parent = info
		end
	end
	local tutorial = folder(info, "Tutorial")
	for _, name in { "IsInTutorial", "NewPlayer", "StarterBuilding", "TutorialBankPlaced" } do
		local old = info:FindFirstChild(name)
		if old and not tutorial:FindFirstChild(name) then
			old.Parent = tutorial
		end
	end
	Schema.Reconcile(data, stats, player.Name)
	local placed = data.CurrentBuildings
	local population = info.Population.Value
	if not tutorial.IsInTutorial.Value or #placed:GetChildren() > 0 or population > 0 then
		tutorial.NewPlayer.Value = false
	end
end
