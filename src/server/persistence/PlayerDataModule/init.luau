local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Codec = require(script.ProfileCodec)
local Migration = require(script.SchemaMigration)
local Schema = require(script.DataSchema)
local Store = require(script.SessionStore)
local OwnerReset = require(script.OwnerReset)
local PlayerData = {}
local sessions = {}
local started = false
local Guard = require(script.Parent.Parent.systems.security.RequestGuard)
local beforeSave = nil
-- Cover one full 180-second lease plus a retry interval after a crashed server.
local ACQUIRE_TIMEOUT = 190
local MAX_SERVICE_ERRORS = 5

local function active(player)
	return player.Parent and not player:GetAttribute("MyCityLeaving")
end

local function releaseSession(player, session)
	for attempt = 1, 3 do
		local ok, err = pcall(Store.release, player.UserId, session.id)
		if ok then
			return -- False means ownership is already gone; never release another server's lock.
		end
		if attempt < 3 then
			task.wait(attempt)
		else
			warn("[Data] Session release failed for", player.UserId, err)
		end
	end
end

local function waitForRetry(player, seconds)
	local deadline = os.clock() + seconds
	while active(player) and os.clock() < deadline do
		task.wait(math.min(0.25, deadline - os.clock()))
	end
end

function PlayerData.isLoaded(player)
	local session = sessions[player]
	return session ~= nil and session.loaded == true
end

function PlayerData.getRecord(player)
	local session = sessions[player]
	return session and session.record
end

function PlayerData.setBeforeSave(callback)
	beforeSave = callback
end

function PlayerData.loadPlayerData(player)
	if not player.Parent or player:GetAttribute("MyCityLeaving") then
		return false
	end
	if sessions[player] then
		return PlayerData.isLoaded(player)
	end
	local session = {
		id = HttpService:GenerateGUID(false),
		loaded = false,
		busy = false,
		nextSave = os.clock() + 15 + player.UserId % 30,
	}
	sessions[player] = session
	local ok, record
	local deadline = os.clock() + ACQUIRE_TIMEOUT
	local errors = 0
	player:SetAttribute("MyCityLoadStage", "Profile")
	while active(player) do
		ok, record = pcall(Store.acquire, player.UserId, session.id)
		if ok and record then
			break
		end
		errors = if ok then 0 else errors + 1
		player:SetAttribute("MyCityLoadStage", if ok then "WaitingForSession" else "RetryingDataStore")
		if errors >= MAX_SERVICE_ERRORS or os.clock() >= deadline then
			break
		end
		waitForRetry(player, math.min(if ok then 5 else math.min(2 ^ errors, 10), deadline - os.clock()))
	end
	if not player.Parent or player:GetAttribute("MyCityLeaving") then
		releaseSession(player, session)
		return false
	end
	if not ok or not record then
		local code = if ok then "LOAD_SESSION" else "LOAD_SERVICE"
		player:SetAttribute("MyCityLoadFailed", true)
		player:SetAttribute("MyCityLoadErrorCode", code)
		warn("[Data] Load refused for", player.UserId, if ok then "Profile is owned by another session" else record)
		-- A failed request may have acquired our lease before its response was lost.
		releaseSession(player, session)
		if active(player) then
			player:Kick(
				if ok
					then "Your city is still open in another server. Close that session, then rejoin. [LOAD_SESSION]"
					else "City storage is temporarily unavailable. Please try again later. [LOAD_SERVICE]"
			)
		end
		return false
	end
	session.record = record
	local restoreRecord
	player:SetAttribute("MyCityLoadStage", "ProfileRestore")
	local restored, data, stats = xpcall(function()
		restoreRecord = OwnerReset.apply(player, record)
		local data, stats = Codec.restore(Schema.Normalize(restoreRecord, player.Name))
		Migration(player, data, stats)
		return data, stats
	end, debug.traceback)
	if not restored or not player.Parent or player:GetAttribute("MyCityLeaving") then
		if not restored and player.Parent and not player:GetAttribute("MyCityLeaving") then
			player:SetAttribute("MyCityLoadFailed", true)
			player:SetAttribute("MyCityLoadErrorCode", "LOAD_RESTORE")
			warn("[Data] Restore failed for", player.UserId, data)
		end
		releaseSession(player, session)
		if restored then
			data:Destroy()
			stats:Destroy()
		end
		if player.Parent and not player:GetAttribute("MyCityLeaving") then
			player:Kick("Your saved city needs a loading fix. Please report code LOAD_RESTORE with your username.")
		end
		return false
	end
	data.Parent = player
	stats.Parent = player
	session.record = restoreRecord
	session.loaded = true
	return true
end

function PlayerData.savePlayerData(player, release)
	local session = sessions[player]
	if not session or not session.loaded then
		return false
	end
	local deadline = os.clock() + 25
	while session.busy do
		if os.clock() >= deadline then
			return false
		end
		task.wait()
	end
	if not session.loaded then
		return false
	end
	session.busy = true
	local ok, saved = pcall(function()
		if beforeSave then
			beforeSave(player)
		end
		local snapshot = table.clone(session.record)
		snapshot.PlayerData = Codec.encodeFolder(player.Data)
		snapshot.LeaderBoardData = Codec.encodeFolder(player.leaderstats)
		snapshot.NewProfile = nil
		snapshot.FolderEncoding = 2
		snapshot.LastSaved = os.time()
		snapshot = Schema.Normalize(snapshot, player.Name, snapshot.LastSaved)
		-- Detach mutable receipt/intent tables before UpdateAsync yields.
		local encoded = HttpService:JSONEncode(snapshot)
		if #encoded > 3 * 1024 * 1024 and #encoded > (session.warnedSize or 0) + 128 * 1024 then
			session.warnedSize = #encoded
			warn("[Data] Large profile; review retained purchase/history growth:", player.UserId, #encoded, "bytes")
		end
		snapshot = HttpService:JSONDecode(encoded)
		for attempt = 1, 3 do
			local success, result = pcall(Store.save, player.UserId, session.id, snapshot, release)
			if success and result then
				return true
			end
			if success and not result then
				session.loaded = false
				player:SetAttribute("MyCityLeaving", true)
				player:Kick("Your city session moved to another server. Please rejoin.")
				return false
			end
			task.wait(attempt)
		end
		return false
	end)
	session.busy = false
	session.nextSave = os.clock() + (if ok and saved then 45 else 5)
	if release and ok and saved then
		session.loaded = false
	end
	if not ok or not saved then
		warn("[Data] Save failed for", player.UserId)
	end
	return ok and saved == true
end

function PlayerData.abandon(player)
	local session = sessions[player]
	if not session then
		return
	end
	session.loaded = false
	releaseSession(player, session)
end

function PlayerData.forget(player)
	sessions[player] = nil
end

function PlayerData.init()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(1)
			for player, session in sessions do
				if
					session.loaded
					and not session.busy
					and os.clock() >= session.nextSave
					and player:GetAttribute("MyCityLoaded")
					and not player:GetAttribute("MyCityLeaving")
					and not Guard.isBusy(player)
				then
					session.nextSave = os.clock() + 45
					task.spawn(PlayerData.savePlayerData, player)
				end
			end
		end
	end)
end

return PlayerData
