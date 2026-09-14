-- Pure daily selection/progression rules, independent of Roblox services.
local Catalog = require(script.Parent.Parent.Parent.Parent.config.DailyQuestCatalog)
local Board = {}
function Board.day(now)
	return math.floor(now / Catalog.DaySeconds)
end
function Board.ensure(record, userId, now)
	local day = Board.day(now)
	local old = record.DailyQuests
	if type(old) == "table" and old.Day == day and type(old.Entries) == "table" and #old.Entries == 6 then
		local valid, seen = true, {}
		for _, entry in old.Entries do
			local definition = type(entry) == "table" and Catalog.ById[entry.Id]
			if
				not definition
				or seen[entry.Id]
				or type(entry.Progress) ~= "number"
				or entry.Progress ~= entry.Progress
				or entry.Progress < 0
				or entry.Progress > definition.Target
				or type(entry.Claimed) ~= "boolean"
			then
				valid = false
				break
			end
			seen[entry.Id] = true
		end
		if valid then
			return old, false
		end
	end
	local previous = {}
	if type(old) == "table" and type(old.Entries) == "table" then
		for _, entry in old.Entries do
			if type(entry) == "table" then
				previous[entry.Id] = true
			end
		end
	end
	local seed = (userId % 2147483646 + day * 97) % 2147483646 + 1
	local function randomIndex(count)
		seed = (seed * 48271) % 2147483647
		return seed % count + 1
	end
	local board, used = { Day = day, Entries = {} }, {}
	for _, difficulty in { "Easy", "Medium", "Hard" } do
		for _ = 1, 2 do
			local candidates = {}
			for _, quest in Catalog.List do
				if quest.Difficulty == difficulty and not used[quest.Metric] and not previous[quest.Id] then
					table.insert(candidates, quest)
				end
			end
			assert(#candidates > 0, "Daily quest pool cannot supply six distinct objectives")
			local quest = candidates[randomIndex(#candidates)]
			used[quest.Metric] = true
			table.insert(board.Entries, { Id = quest.Id, Progress = 0, Claimed = false })
		end
	end
	record.DailyQuests = board
	return board, true
end
function Board.progress(board, metric, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	local changed, completed = false, false
	for _, entry in board.Entries do
		local quest = Catalog.ById[entry.Id]
		if quest.Metric == metric and not entry.Claimed then
			local target = if quest.Mode == "peak" then math.max(entry.Progress, amount) else entry.Progress + amount
			target = math.min(quest.Target, target)
			if target ~= entry.Progress then
				completed = completed or target >= quest.Target
				entry.Progress = target
				changed = true
			end
		end
	end
	return changed, completed
end
function Board.claim(board, day, id)
	if day ~= board.Day or type(id) ~= "string" then
		return nil, "These quests have refreshed. Try the new board."
	end
	for _, entry in board.Entries do
		if entry.Id == id then
			local quest = Catalog.ById[id]
			if entry.Claimed then
				return nil, "Reward already claimed."
			end
			if entry.Progress < quest.Target then
				return nil, "Finish this quest first."
			end
			entry.Claimed = true
			return quest.Reward
		end
	end
	return nil, "That quest is not on your daily board."
end
function Board.snapshot(board, now)
	local entries = {}
	for _, entry in board.Entries do
		local quest = Catalog.ById[entry.Id]
		table.insert(entries, {
			Id = entry.Id,
			Title = quest.Title,
			Difficulty = quest.Difficulty,
			Metric = quest.Metric,
			Target = quest.Target,
			Progress = entry.Progress,
			Reward = quest.Reward,
			Claimed = entry.Claimed,
		})
	end
	return { Day = board.Day, ResetsAt = (board.Day + 1) * Catalog.DaySeconds, ServerTime = now, Quests = entries }
end
return Board
