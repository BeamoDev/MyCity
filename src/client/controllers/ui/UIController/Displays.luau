-- Displays: focused implementation for UIController.
return function(Context)
	function Context.formatNumber(num)
		local value = math.floor(num)
		local negative = value < 0 -- -0 is not < 0, so it formats as "$0"
		local formatted = tostring(math.abs(value))
		local k = 1
		while k ~= 0 do
			formatted, k = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
		end
		return (if negative then "-$" else "$") .. formatted
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
