-- Lease and profile share one record, making ownership checks and saves atomic.
local HttpService = game:GetService("HttpService")
local Store = game:GetService("DataStoreService"):GetDataStore("Data_1")
local SessionStore = {}
local LEASE_SECONDS = 180

local function decode(raw)
	if raw == nil then
		return { NewProfile = true }
	end
	local value = if type(raw) == "string" then HttpService:JSONDecode(raw) else raw
	assert(type(value) == "table", "Malformed profile record")
	return value
end

function SessionStore.acquire(userId, sessionId)
	local result = Store:UpdateAsync(tostring(userId), function(raw)
		local record = decode(raw)
		assert(record.PlayerData ~= nil or record.NewProfile == true, "Profile envelope is missing saved data")
		local lock = record.Session
		if lock and lock.Id ~= sessionId and lock.Expires > os.time() then
			return nil
		end
		record.Session = { Id = sessionId, Expires = os.time() + LEASE_SECONDS }
		return HttpService:JSONEncode(record)
	end)
	if result == nil then
		return nil
	end
	return decode(result)
end

function SessionStore.save(userId, sessionId, snapshot, release)
	local written = Store:UpdateAsync(tostring(userId), function(raw)
		local current = decode(raw)
		if not current.Session or current.Session.Id ~= sessionId then
			return nil
		end
		snapshot.Session = if release then nil else { Id = sessionId, Expires = os.time() + LEASE_SECONDS }
		return HttpService:JSONEncode(snapshot)
	end)
	return written ~= nil
end

function SessionStore.transferOffline(userId, identifier, construction, transferId, descriptorFor)
	local result = Store:UpdateAsync(tostring(userId), function(raw)
		if raw == nil then
			return nil
		end
		local record = decode(raw)
		if record.Session and record.Session.Expires > os.time() then
			return nil
		end
		record.Session = nil
		record.Transfers = record.Transfers or {}
		if not record.Transfers[transferId] then
			local folder = record.PlayerData
				and record.PlayerData[if construction then "CurrentConstructions" else "CurrentBuildings"]
			local entry = folder and folder[identifier]
			if not entry or entry.ClassName ~= "StringValue" then
				return nil
			end
			record.Transfers[transferId] = descriptorFor(entry.Value, identifier, construction)
			folder[identifier] = nil
		end
		return HttpService:JSONEncode(record)
	end)
	if not result then
		return nil
	end
	return decode(result).Transfers[transferId]
end

return SessionStore
