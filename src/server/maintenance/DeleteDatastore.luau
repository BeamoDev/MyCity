-- Manual maintenance module; never required by startup.
return function()
	local DataStoreService = game:GetService("DataStoreService")
	local RunService = game:GetService("RunService")

	local STORES = {
		{ name = "CityNames" },
		{ name = "CityRatings" },
		{ name = "Data_1" },
		{ name = "Tutorial" },
	}

	local PROTECTED_USER_IDS = {
		--	1108295030,
		--	1246378769,
		--1790165114,
		3250655884,
	}

	local SPECIFIC_DELETE_USER_IDS = {
		1790165114,
		-- Example: 1234567890,
		-- Example: 9876543210,
	}

	local SOURCE_USER_ID = 1108295030
	local TARGET_USER_ID = 962940705

	-- Maintenance only: never enable this in a published place.
	local ENABLE_DELETE = false
	local ENABLE_CLONE = false
	local DELETE_SPECIFIC_ONLY = true -- Set to true to delete only specific IDs, false to delete all except protected
	local STUDIO_ONLY = true
	local VERBOSE = true
	local MAX_RETRIES = 6
	local BASE_DELAY = 0.5
	local PER_KEY_DELAY = 0.05

	if not ENABLE_DELETE then
		print("[DS-CLEAR] Abort: ENABLE_DELETE = false")
		return
	end

	if STUDIO_ONLY and not RunService:IsStudio() then
		print("[DS-CLEAR] Abort: STUDIO_ONLY = true and this is not Studio")
		return
	end

	local function info(...)
		print("[DS-CLEAR]", ...)
	end

	local function dbg(...)
		if VERBOSE then
			print("[DS-CLEAR][v]", ...)
		end
	end

	local function warnf(...)
		warn("[DS-CLEAR][warn]", ...)
	end

	local function success(...)
		print("[DS-CLEAR][✓]", ...)
	end

	local PROTECTED_SET = {}

	for _, id in ipairs(PROTECTED_USER_IDS) do
		PROTECTED_SET[tostring(id)] = true
	end

	local function isProtectedKey(keyName: string): boolean
		return PROTECTED_SET[keyName] ~= nil
	end

	local function cloneUserData(ds, sourceUserId, targetUserId)
		local sourceKey = tostring(sourceUserId)
		local targetKey = tostring(targetUserId)

		-- Get source data
		local sourceData = nil
		local getOk, getErr = pcall(function()
			sourceData = ds:GetAsync(sourceKey)
		end)

		if not getOk then
			warnf(("Failed to get data for cloning from %s: %s"):format(sourceKey, tostring(getErr)))
			return false
		end

		if not sourceData then
			dbg(("No data found for source user %s"):format(sourceKey))
			return false
		end

		local delaySec = BASE_DELAY
		for attempt = 1, MAX_RETRIES do
			local setOk, setErr = pcall(function()
				ds:SetAsync(targetKey, sourceData)
			end)

			if setOk then
				success(("Cloned data from %s to %s"):format(sourceKey, targetKey))
				return true
			end

			dbg(("Clone retry %d for %s -> %s: %s"):format(attempt, sourceKey, targetKey, tostring(setErr)))
			task.wait(delaySec)
			delaySec = math.min(delaySec * 2, 10)
		end

		warnf(("Failed to clone data from %s to %s after %d retries"):format(sourceKey, targetKey, MAX_RETRIES))
		return false
	end

	local function removeKey(ds, key)
		local delaySec = BASE_DELAY
		local lastErr

		for attempt = 1, MAX_RETRIES do
			local ok, err = pcall(function()
				ds:RemoveAsync(key)
			end)

			if ok then
				dbg(("Deleted key: %s"):format(key))
				return true
			end

			lastErr = tostring(err)
			dbg(("Retry %d for key %s -> %s"):format(attempt, key, lastErr))
			task.wait(delaySec)
			delaySec = math.min(delaySec * 2, 10)
		end

		warnf(("Failed to remove key after retries: %s | lastErr=%s"):format(key, tostring(lastErr)))
		return false
	end

	local function deleteSpecificUsers()
		local totalDeleted = 0
		local totalFailed = 0
		local totalCloned = 0

		info("=" .. string.rep("=", 60))
		info("Starting SPECIFIC USER deletion")
		info("Users to delete:", table.concat(SPECIFIC_DELETE_USER_IDS, ", "))
		info("Protected users:", table.concat(PROTECTED_USER_IDS, ", "))
		info("=" .. string.rep("=", 60))

		for _, store in ipairs(STORES) do
			local ds = DataStoreService:GetDataStore(store.name, store.scope)
			local scopeText = store.scope and (" (scope=" .. tostring(store.scope) .. ")") or ""

			info("")
			info(("→ Processing DataStore: %s%s"):format(store.name, scopeText))
			info(string.rep("-", 40))

			if ENABLE_CLONE then
				local cloneSuccess = cloneUserData(ds, SOURCE_USER_ID, TARGET_USER_ID)
				if cloneSuccess then
					totalCloned = totalCloned + 1
				end
			end

			local storeDeleted = 0
			local storeFailed = 0

			for _, userId in ipairs(SPECIFIC_DELETE_USER_IDS) do
				local key = tostring(userId)

				if isProtectedKey(key) then
					dbg(("Skipping protected user: %s"):format(key))
				elseif ENABLE_CLONE and key == tostring(TARGET_USER_ID) then
					dbg(("Skipping clone target: %s"):format(key))
				else
					local ok = removeKey(ds, key)
					if ok then
						storeDeleted = storeDeleted + 1
					else
						storeFailed = storeFailed + 1
					end
					task.wait(PER_KEY_DELAY)
				end
			end

			totalDeleted = totalDeleted + storeDeleted
			totalFailed = totalFailed + storeFailed

			info(("   Done: %d deleted, %d failed"):format(storeDeleted, storeFailed))
		end

		info("")
		info("=" .. string.rep("=", 60))
		info("SPECIFIC DELETION COMPLETE")
		info("=" .. string.rep("=", 60))
		info(("Total deleted:       %d"):format(totalDeleted))
		info(("Total failed:        %d"):format(totalFailed))

		if ENABLE_CLONE then
			info(("Total stores cloned: %d"):format(totalCloned))
		end

		info("=" .. string.rep("=", 60))
	end

	local function listAllKeys(ds)
		local pages
		local ok, err = pcall(function()
			pages = ds:ListKeysAsync()
		end)

		if not ok then
			warnf("ListKeysAsync failed:", err)
			return {}
		end

		local keys = {}
		local pageIdx = 0

		while true do
			pageIdx += 1
			local page = pages:GetCurrentPage()
			dbg(("Fetched page %d with %d keys"):format(pageIdx, #page))

			for _, infoObj in ipairs(page) do
				table.insert(keys, infoObj.KeyName)
			end

			if pages.IsFinished then
				break
			end

			local advOk, advErr = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)

			if not advOk then
				warnf("AdvanceToNextPageAsync failed:", advErr)
				break
			end
		end

		return keys
	end

	local function deleteAllExceptProtected()
		local grandTotalKeys = 0
		local grandTotalDeleted = 0
		local grandTotalFailed = 0
		local grandTotalSkipped = 0
		local grandTotalCloned = 0

		info("=" .. string.rep("=", 60))
		info("Starting DataStore operations")
		info("Stores to process:", #STORES)
		info("Protected users:", table.concat(PROTECTED_USER_IDS, ", "))
		info("MODE: Delete ALL except protected users")

		if ENABLE_CLONE then
			info(("Will clone data: %d -> %d"):format(SOURCE_USER_ID, TARGET_USER_ID))
		end

		info("=" .. string.rep("=", 60))

		for _, store in ipairs(STORES) do
			local ds = DataStoreService:GetDataStore(store.name, store.scope)
			local scopeText = store.scope and (" (scope=" .. tostring(store.scope) .. ")") or ""

			info("")
			info(("→ Processing DataStore: %s%s"):format(store.name, scopeText))
			info(string.rep("-", 40))

			if ENABLE_CLONE then
				local cloneSuccess = cloneUserData(ds, SOURCE_USER_ID, TARGET_USER_ID)
				if cloneSuccess then
					grandTotalCloned = grandTotalCloned + 1
				end
			end

			local keys = listAllKeys(ds)
			local count = #keys
			grandTotalKeys = grandTotalKeys + count
			info(("   Found %d key(s)"):format(count))

			if count > 0 then
				local deleted = 0
				local failed = 0
				local skipped = 0

				for _, key in ipairs(keys) do
					if ENABLE_CLONE and key == tostring(TARGET_USER_ID) then
						skipped = skipped + 1
						grandTotalSkipped = grandTotalSkipped + 1
						dbg(("Skip cloned target key: %s"):format(key))
					elseif isProtectedKey(key) then
						skipped = skipped + 1
						grandTotalSkipped = grandTotalSkipped + 1
						dbg(("Skip protected key: %s"):format(key))
					else
						local ok = removeKey(ds, key)
						if ok then
							deleted = deleted + 1
						else
							failed = failed + 1
						end
						task.wait(PER_KEY_DELAY)
					end
				end

				grandTotalDeleted = grandTotalDeleted + deleted
				grandTotalFailed = grandTotalFailed + failed

				info(("   Done: %d deleted, %d skipped, %d failed"):format(deleted, skipped, failed))
			end
		end

		info("")
		info("=" .. string.rep("=", 60))
		info("OPERATION COMPLETE")
		info("=" .. string.rep("=", 60))
		info(("Total keys found:    %d"):format(grandTotalKeys))
		info(("Total deleted:       %d"):format(grandTotalDeleted))
		info(("Total skipped:       %d"):format(grandTotalSkipped))
		info(("Total failed:        %d"):format(grandTotalFailed))

		if ENABLE_CLONE then
			info(("Total stores cloned: %d"):format(grandTotalCloned))
		end

		info("=" .. string.rep("=", 60))
	end

	-- Main execution
	if DELETE_SPECIFIC_ONLY then
		deleteSpecificUsers()
	else
		deleteAllExceptProtected()
	end

	script:Destroy()
end
