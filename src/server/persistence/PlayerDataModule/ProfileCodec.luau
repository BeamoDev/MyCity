-- Preserve the Data_1 envelope and support arbitrary folder depth.
local Codec = {}
local allowed = { BoolValue = true, IntValue = true, NumberValue = true, StringValue = true }

function Codec.encodeFolder(folder)
	local result = {}
	for _, child in folder:GetChildren() do
		assert(not result[child.Name], "Duplicate saved instance: " .. child:GetFullName())
		if child:IsA("Folder") then
			result[child.Name] = Codec.encodeFolder(child)
		elseif allowed[child.ClassName] then
			result[child.Name] =
				{ ClassName = child.ClassName, Value = child.Value, Name = child.Name, Parent = folder.Name }
		end
	end
	return result
end

function Codec.decodeFolder(entries, folder, legacyNames)
	assert(type(entries) == "table", "Invalid saved folder: " .. folder:GetFullName())
	for key, entry in pairs(entries) do
		assert(
			type(key) == "string" and type(entry) == "table",
			"Invalid saved entry in " .. folder:GetFullName() .. "." .. tostring(key)
		)
		if entry.ClassName then
			assert(
				allowed[entry.ClassName],
				"Unsupported saved value type at "
					.. folder:GetFullName()
					.. "."
					.. key
					.. ": "
					.. tostring(entry.ClassName)
			)
			local child = Instance.new(entry.ClassName)
			child.Name = entry.Name or key
			child.Value = entry.Value
			child.Parent = folder
		else
			local name = if legacyNames then (key:match("(.+)_%d+$") or key) else key
			local child = folder:FindFirstChild(name) or Instance.new("Folder")
			child.Name = name
			child.Parent = folder
			Codec.decodeFolder(entry, child, legacyNames)
		end
	end
end

function Codec.restore(envelope)
	local data = Instance.new("Folder")
	data.Name = "Data"
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	if envelope.PlayerData ~= nil then
		Codec.decodeFolder(envelope.PlayerData, data, envelope.FolderEncoding ~= 2)
		Codec.decodeFolder(envelope.LeaderBoardData, stats, false)
	else
		assert(envelope.NewProfile == true, "Profile envelope is missing saved data")
	end
	return data, stats
end

return Codec
