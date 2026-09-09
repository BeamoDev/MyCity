-- Formatting: focused implementation for ShopController.
return function(Context)
	local State = Context.State

	function Context.getPriceTier(inGamePrice)
		if inGamePrice < 10000 then
			return 7
		elseif inGamePrice < 30000 then
			return 15
		elseif inGamePrice < 60000 then
			return 25
		elseif inGamePrice < 100000 then
			return 40
		elseif inGamePrice < 200000 then
			return 75
		elseif inGamePrice < 500000 then
			return 150
		elseif inGamePrice <= 10000000 then
			return 300
		end
		return nil
	end

	function Context.formatCash(amount)
		if amount >= 1000000 then
			return string.format("$%.1fM", amount / 1000000)
		elseif amount >= 1000 then
			return string.format("$%.1fK", amount / 1000)
		else
			return "$" .. tostring(amount)
		end
	end

	function Context.formatTime(seconds)
		local minutes = math.floor(seconds / 60)
		local secs = seconds % 60
		return string.format("%02d:%02d", minutes, secs)
	end
end
