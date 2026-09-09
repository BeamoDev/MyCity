-- Displays: focused implementation for UIController.
return function(Context)
	function Context.formatNumber(num)
		local formatted = tostring(math.floor(num))
		local k = 1
		while k ~= 0 do
			formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		end
		return "$" .. formatted
	end

	function Context.formatPopulation(value)
		if value >= 1000000000 then
			return string.format("%.1fB", value / 1000000000)
		elseif value >= 1000000 then
			return string.format("%.1fM", value / 1000000)
		elseif value >= 1000 then
			return string.format("%.1fK", value / 1000)
		else
			return tostring(math.floor(value))
		end
	end

	function Context.formatNumberShort(num)
		if num >= 1000000000 then
			return string.format("$%.2fB", num / 1000000000)
		elseif num >= 1000000 then
			return string.format("$%.2fM", num / 1000000)
		elseif num >= 1000 then
			return string.format("$%.2fK", num / 1000)
		else
			return "$" .. tostring(math.floor(num))
		end
	end
end
