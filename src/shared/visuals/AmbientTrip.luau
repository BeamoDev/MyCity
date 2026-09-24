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
-- Multi-waypoint trips (road cars) publish Points plus P1..Pn CFrame attributes.
function Trip.readPath(descriptor)
	local count = descriptor:GetAttribute("Points")
	if type(count) ~= "number" or count < 2 then
		return nil
	end
	local frames, distances, total = {}, { 0 }, 0
	for index = 1, count do
		local frame = descriptor:GetAttribute("P" .. index)
		if typeof(frame) ~= "CFrame" then
			return nil
		end
		frames[index] = frame
		if index > 1 then
			total += (frame.Position - frames[index - 1].Position).Magnitude
			distances[index] = total
		end
	end
	return if total > 0 then { frames = frames, distances = distances, total = total } else nil
end

-- Constant-speed position along a path, matching the server's length/speed duration.
function Trip.along(path, duration, started, now)
	if not path or type(duration) ~= "number" or duration <= 0 or type(started) ~= "number" then
		return nil, false
	end
	local alpha = math.clamp((now - started) / duration, 0, 1)
	local travelled = alpha * path.total
	local frames, distances = path.frames, path.distances
	for index = 2, #frames do
		if travelled <= distances[index] or index == #frames then
			local span = distances[index] - distances[index - 1]
			local t = if span > 0 then math.clamp((travelled - distances[index - 1]) / span, 0, 1) else 1
			return frames[index - 1]:Lerp(frames[index], t), alpha >= 1
		end
	end
	return frames[#frames], true
end

return Trip
