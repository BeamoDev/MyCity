-- Forty objectives. Cash rewards grow with time/effort; none require Robux or destructive actions.
local Catalog = { List = {}, ById = {}, DaySeconds = 86400 }
local families = {
	{ "collect", "Collect city income %d times", { 1, 3, 8, 15, 30 }, { 250, 600, 1500, 3500, 8000 } },
	{ "income", "Collect $%d in city income", { 500, 1500, 5000, 15000, 50000 }, { 250, 600, 1500, 4000, 12000 } },
	{ "purchase", "Buy %d buildings with cash", { 1, 2, 5, 10, 20 }, { 250, 600, 1800, 4500, 12000 } },
	{ "spend", "Spend $%d in the building shop", { 500, 1500, 5000, 15000, 50000 }, { 200, 500, 1500, 4000, 12000 } },
	{ "buildings", "Have %d completed buildings in your city", { 3, 5, 10, 20, 40 }, { 300, 700, 2000, 5000, 15000 } },
	{ "roads", "Have %d road pieces in your city", { 2, 4, 8, 15, 30 }, { 200, 500, 1200, 3000, 9000 } },
	{ "population", "Reach a population of %d", { 10, 25, 75, 200, 500 }, { 300, 750, 2200, 5500, 16000 } },
	{ "play", "Spend %d minutes building your city", { 3, 5, 10, 20, 45 }, { 250, 600, 1800, 4500, 12000 } },
}
for _, family in families do
	for tier, target in family[3] do
		local quest = {
			Id = family[1] .. "_" .. tier,
			Metric = family[1],
			Title = string.format(family[2], target),
			Target = if family[1] == "play" then target * 60 else target,
			Reward = family[4][tier],
			Difficulty = if tier <= 2 then "Easy" elseif tier <= 4 then "Medium" else "Hard",
			Mode = if family[1] == "buildings"
					or family[1] == "roads"
					or family[1] == "population"
				then "peak"
				else "add",
		}
		table.insert(Catalog.List, quest)
		Catalog.ById[quest.Id] = quest
	end
end
return Catalog
