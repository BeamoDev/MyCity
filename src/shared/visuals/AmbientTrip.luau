-- Immutable route descriptors keep late arrivals on the same trip as existing clients.
local Trip = {}
function Trip.position(first, last, duration, started, now)
	if
		typeof(first) ~= "CFrame"
		or typeof(last) ~= "CFrame"
		or type(duration) ~= "number"
		or duration <= 0
		or duration >= math.huge
		or type(started) ~= "number"
		or math.abs(started) == math.huge
		or duration ~= duration
		or started ~= started
	then
		return nil, false
	end
	local alpha = math.clamp((now - started) / duration, 0, 1)
	return first:Lerp(last, alpha), alpha >= 1
end
return Trip
