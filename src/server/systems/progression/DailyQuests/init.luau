local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(script.Parent.Parent.Parent.persistence.PlayerDataModule)
local Guard = require(script.Parent.Parent.security.RequestGuard)
local Signals = require(script.Parent.Parent.Parent.services.QuestSignals)
local Board = require(script.Board)
local Runtime = require(script.Runtime)
local Service = {}
local sessions = {}
local events = ReplicatedStorage.Events.DailyQuests
local started = false
local function active(player)
	local data = player:FindFirstChild("Data")
	return Guard.ready(player) and data ~= nil and not data.PlayerInfo.Tutorial.IsInTutorial.Value
end
local function boardFor(player)
	local record = Data.getRecord(player)
	if not record then
		return nil
	end
	local board, refreshed = Board.ensure(record, player.UserId, os.time())
	if refreshed and sessions[player] then
		sessions[player].cityDirty, sessions[player].dirty = true, true
	end
	return board, refreshed
end
function Service.syncPlayer(player)
	if not Guard.ready(player) then
		return
	end
	local board = boardFor(player)
	if board then
		events.Update:FireClient(player, Board.snapshot(board, os.time()))
	end
end
function Service.record(player, metric, amount)
	if not active(player) then
		return
	end
	local board, refreshed = boardFor(player)
	if board and (Board.progress(board, metric, amount) or refreshed) then
		local session = sessions[player]
		if session then
			session.dirty = true
		end
	end
end
function Service.initializePlayer(player)
	if sessions[player] then
		return
	end
	local board = boardFor(player)
	if not board then
		return
	end
	sessions[player] = Runtime.start(player, Service.record)
	Service.syncPlayer(player)
end
function Service.cleanup(player)
	local session = sessions[player]
	if not session then
		return
	end
	session:cleanup()
	sessions[player] = nil
end
function Service.init()
	if started then
		return
	end
	started = true
	Signals.bind(Service.record)
	events.Request.OnServerEvent:Connect(function(player)
		Guard.run(player, "DailyQuestRequest", function()
			Service.initializePlayer(player)
			if active(player) and sessions[player] then
				sessions[player]:sample()
			end
			Service.syncPlayer(player)
		end)
	end)
	events.Claim.OnServerEvent:Connect(function(player, day, id)
		Guard.run(player, "DailyQuestClaim", function()
			if not active(player) then
				return
			end
			local board = boardFor(player)
			if not board then
				return
			end
			local reward, message = Board.claim(board, day, id)
			if reward then
				-- Claim marker and cash enter the SAME profile snapshot before acknowledging.
				player.leaderstats.Cash.Value += reward
				local saved = Data.savePlayerData(player)
				message = if saved
					then string.format("Quest complete! +$%d", reward)
					else "Reward credited. Saving will retry automatically."
			end
			events.Result:FireClient(player, reward ~= nil, message)
			Service.syncPlayer(player)
		end)
	end)
	Players.PlayerRemoving:Connect(Service.cleanup)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, session in sessions do
				if active(player) then
					local _, refreshed = boardFor(player)
					if refreshed then
						session.cityDirty = true
					end
					session:step(os.time())
					if session.dirty or refreshed then
						session.dirty = false
						Service.syncPlayer(player)
					end
				else
					session.lastTick = os.time()
				end
			end
		end
	end)
end
return Service
