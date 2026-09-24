local catalogue = {}
for _, category in
	{
		require(script.Decorations),
		require(script.Starter),
		require(script.Population),
		require(script.Uncommon),
		require(script.Rare),
		require(script.Epic),
		require(script.Legendary),
		require(script.Mythic),
	}
do
	for name, definition in pairs(category) do
		assert(catalogue[name] == nil, "Duplicate building: " .. name)
		catalogue[name] = definition
	end
end
for _, name in
	{
		"Shack",
		"SmallHouse",
		"CozyHouse",
		"RowHouses",
		"CabinLodge",
		"TallHouse",
		"Apartments",
		"Hotel",
		"ModernHouse",
		"Mansion",
		"LuxuryHouse",
		"LuxuryCondo",
	}
do
	if catalogue[name] then
		catalogue[name].Industry = "Residential"
	end
end
-- Roads are infrastructure: no XP, levels or level display.
for name, definition in catalogue do
	if name:match("^Road") then
		definition.NoLevels = true
	end
end
return catalogue
