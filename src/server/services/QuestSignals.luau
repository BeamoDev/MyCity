-- Server-only gameplay facts; clients cannot submit quest progress.
local Signals = {}
local listener
function Signals.bind(callback)
	listener = callback
end
function Signals.emit(player, metric, amount)
	if listener then
		local ok, err = pcall(listener, player, metric, amount)
		if not ok then
			warn("[DailyQuests] Progress tracking failed", err)
		end
	end
end
return Signals
