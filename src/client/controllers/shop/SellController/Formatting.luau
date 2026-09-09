-- Formatting: focused implementation for SellController.
return function(Context)
	local State = Context.State

	function Context.formatPrice(price)
		if price >= 1000000 then
			return string.format("$%.1fM", price / 1000000)
		elseif price >= 1000 then
			return string.format("$%.1fK", price / 1000)
		else
			return "$" .. tostring(price)
		end
	end

	function Context.formatProfit(profit, percent)
		local profitStr = Context.formatPrice(math.abs(profit))
		if profit >= 0 then
			return string.format("+%s (%.0f%%)", profitStr, percent)
		else
			return string.format("-%s (%.0f%%)", profitStr, math.abs(percent))
		end
	end

	function Context.showNotification(notificationType, audioChoice, customText)
		local NotificationController =
			require(script.Parent.Parent.Parent:WaitForChild("ui"):WaitForChild("NotificationController"))
		NotificationController.showNotification(notificationType, customText)
	end
end
