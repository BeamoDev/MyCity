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
	if sessions[player] then
		return PlayerData.isLoaded(player)
	end
	local session = { id = HttpService:GenerateGUID(false), loaded = false, busy = false }
	sessions[player] = session
	local ok, record
	for attempt = 1, 3 do
		ok, record = pcall(Store.acquire, player.UserId, session.id)
		if ok and record then
			break
		end
		if not player.Parent then
			return false
		end
		task.wait(attempt)
	end
	if not ok or not record then
		player:SetAttribute("MyCityLoadFailed", true)
		warn("[Data] Load refused for", player.UserId, if ok then "Profile is owned by another session" else record)
		player:Kick("Your city could not be loaded safely. Please rejoin in a moment.")
		return false
	end
	session.record = record
	local restoreRecord = OwnerReset.apply(player, record)
	local restored, data, stats = xpcall(function()
		local data, stats = Codec.restore(Schema.Normalize(restoreRecord, player.Name))
		Migration(player, data, stats)
		return data, stats
	end, debug.traceback)
	if not restored or not player.Parent then
		player:SetAttribute("MyCityLoadFailed", true)
		if not restored then
			warn("[Data] Restore failed for", player.UserId, data)
		end
		pcall(Store.save, player.UserId, session.id, record, true)
		player:Kick("Your city could not be restored safely. Please try again.")
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
	while session.busy do
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
		snapshot = HttpService:JSONDecode(HttpService:JSONEncode(snapshot))
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
	if session.record then
		pcall(Store.save, player.UserId, session.id, session.record, true)
	end
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
			task.wait(45)
			for _, player in Players:GetPlayers() do
				if PlayerData.isLoaded(player) and player:GetAttribute("MyCityLoaded") and not Guard.isBusy(player) then
					task.spawn(PlayerData.savePlayerData, player)
				end
			end
		end
	end)
end

return PlayerData
