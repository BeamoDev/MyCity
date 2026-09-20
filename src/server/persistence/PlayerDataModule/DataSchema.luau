-- Code-owned defaults. Existing saves retain their values and dynamic collections.
local Schema = { Version = 5 }
local function value(className, initial)
	return { ClassName = className, Value = initial }
end
local function number(initial)
	return value("IntValue", initial)
end
local function flag(initial)
	return value("BoolValue", initial)
end
function Schema.CreateDefault(playerName, now)
	local daily = { CurrentStreak = number(0), LastClaimTime = number(0), CurrentCycle = number(1) }
	for day = 1, 7 do
		daily["Day" .. day] = flag(false)
	end
	return {
		PlayerData = {
			Inventory = {},
			OwnedTiles = {},
			ShopEpicMisses = {},
			CurrentBuildings = {},
			CurrentConstructions = {},
			PlotInfo = { Plot = number(0) },
			PlayerInfo = {
				Population = number(0),
				CityName = value("StringValue", playerName .. "'s City!"),
				AvailableIncome = number(0),
				LastUpdate = number(now),
				LastShopReset = number(now),
				LastPlot = number(0),
				FirstRare = flag(false),
				FirstLegendary = flag(false),
				GroupRewardClaimed = flag(false),
				LimitedPrompted = flag(false),
				SchemaVersion = number(Schema.Version),
				Tutorial = {
					IsInTutorial = flag(true),
					NewPlayer = flag(true),
					StarterBuilding = flag(false),
					TutorialBankPlaced = flag(false),
					ServerStage = number(0),
				},
				Quests = {
					QuestProgression = number(0),
					PostTutorialQuestProgress = number(0),
					PostTutorialQuestComplete = flag(false),
				},
				DailyRewards = daily,
			},
		},
		LeaderBoardData = { Cash = number(500), Rebirths = number(0) },
	}
end
-- Match Word Hunt's normalization boundary: convert scalar values before materializing
-- Instances and before saving. MyCity retains its existing envelope and dynamic items.
local function normalizedValue(definition, raw)
	if definition.ClassName == "IntValue" or definition.ClassName == "NumberValue" then
		local numeric = if type(raw) == "number" or type(raw) == "string" then tonumber(raw) else nil
		if not numeric or numeric ~= numeric or math.abs(numeric) == math.huge then
			numeric = definition.Value
		end
		numeric = math.max(0, numeric)
		if definition.ClassName == "IntValue" then
			numeric = math.floor(numeric)
		end
		return numeric
	elseif definition.ClassName == "BoolValue" then
		if type(raw) == "boolean" then
			return raw
		end
		if raw == 1 or raw == "1" or raw == "true" then
			return true
		end
		if raw == 0 or raw == "0" or raw == "false" then
			return false
		end
		return definition.Value
	elseif definition.ClassName == "StringValue" then
		return if type(raw) == "string" then raw else definition.Value
	end
	error("Unsupported schema value type: " .. definition.ClassName)
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end
local function normalizeStoredFolder(entries, definitions, legacy, path)
	assert(type(entries) == "table" and not entries.ClassName, "Invalid saved folder: " .. path)
	for key, entry in entries do
		local name = if type(entry) == "table" and entry.ClassName
			then (entry.Name or key)
			elseif legacy and type(key) == "string" then (key:match("(.+)_%d+$") or key)
			else key
		local definition = definitions[name]
		if definition then
			if definition.ClassName then
				local raw = if type(entry) == "table" then entry.Value else entry
				if name == "SchemaVersion" then
					local version = if type(raw) == "string" or type(raw) == "number" then tonumber(raw) else nil
					assert(not version or version <= Schema.Version, "Profile was written by a newer schema")
				end
				entries[key] =
					{ ClassName = definition.ClassName, Name = name, Value = normalizedValue(definition, raw) }
			else
				normalizeStoredFolder(entry, definition, legacy, path .. "." .. tostring(name))
			end
		end
	end
end
function Schema.Normalize(envelope, playerName, now)
	assert(type(envelope) == "table", "Malformed profile envelope")
	local normalized = copy(envelope)
	if normalized.PlayerData == nil then
		assert(normalized.NewProfile == true, "Profile envelope is missing saved data")
		return normalized
	end
	local defaults = Schema.CreateDefault(playerName, now or os.time())
	normalizeStoredFolder(normalized.PlayerData, defaults.PlayerData, normalized.FolderEncoding ~= 2, "Data")
	normalizeStoredFolder(normalized.LeaderBoardData, defaults.LeaderBoardData, false, "leaderstats")
	return normalized
end
local function reconcile(folder, definitions)
	for name, definition in definitions do
		local existing = folder:FindFirstChild(name)
		if definition.ClassName then
			local raw = if existing and existing:IsA("ValueBase") then existing.Value else nil
			if name == "SchemaVersion" then
				local version = if type(raw) == "string" or type(raw) == "number" then tonumber(raw) else nil
				assert(not version or version <= Schema.Version, "Profile was written by a newer schema")
			end
			local canonical = normalizedValue(definition, raw)
			if not existing or existing.ClassName ~= definition.ClassName then
				local child = Instance.new(definition.ClassName)
				child.Name, child.Value = name, canonical
				if existing then
					existing:Destroy()
				end
				child.Parent = folder
			else
				existing.Value = canonical
			end
		else
			if not existing then
				existing = Instance.new("Folder")
				existing.Name, existing.Parent = name, folder
			end
			assert(existing:IsA("Folder"), "Saved folder has the wrong class: " .. existing:GetFullName())
			reconcile(existing, definition)
		end
	end
end
function Schema.Reconcile(data, stats, playerName, now)
	-- Move the old leaderboard value before defaults can mask it. New saves keep
	-- population in PlayerInfo; an existing canonical value wins over legacy data.
	local info = data:FindFirstChild("PlayerInfo")
	if not info then
		info = Instance.new("Folder")
		info.Name, info.Parent = "PlayerInfo", data
	end
	assert(info:IsA("Folder"), "Saved PlayerInfo must be a Folder")
	local oldPopulation = stats:FindFirstChild("Population")
	if oldPopulation then
		if not info:FindFirstChild("Population") then
			oldPopulation.Parent = info
		else
			oldPopulation:Destroy()
		end
	end
	local defaults = Schema.CreateDefault(playerName, now or os.time())
	reconcile(data, defaults.PlayerData)
	reconcile(stats, defaults.LeaderBoardData)
	data.PlayerInfo.SchemaVersion.Value = Schema.Version
end
return Schema
