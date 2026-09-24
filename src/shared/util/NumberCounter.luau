local NumberCounter = {}

local function resolveNow(now)
	return tonumber(now) or os.clock()
end

local function normalizeValue(value, options)
	local resolvedOptions = typeof(options) == "table" and options or {}
	local result = tonumber(value) or 0
	if resolvedOptions.Integer ~= false then
		result = math.floor(result)
	end
	local minimum = tonumber(resolvedOptions.Minimum)
	local maximum = tonumber(resolvedOptions.Maximum)
	if minimum then
		result = math.max(minimum, result)
	end
	if maximum then
		result = math.min(maximum, result)
	end
	return result
end

-- Retargets an in-flight counter from its currently displayed value. Returns
-- changed, target delta, and whether this was the initial (snapped) value.
function NumberCounter.SetTarget(state, value, options, now)
	if typeof(state) ~= "table" then
		return false, 0, false
	end
	local resolvedOptions = typeof(options) == "table" and options or {}
	local target = normalizeValue(value, resolvedOptions)
	if state.Current == nil then
		state.Current = target
		state.From = target
		state.Target = target
		state.StartAt = resolveNow(now)
		state.Duration = 0
		return true, 0, true
	end
	if state.Target == target then
		return false, 0, false
	end

	local previousTarget = tonumber(state.Target) or tonumber(state.Current) or target
	state.From = tonumber(state.Current) or target
	state.Target = target
	state.StartAt = resolveNow(now)
	local distance = math.abs(state.Target - state.From)
	local baseDuration = tonumber(resolvedOptions.BaseDuration) or 0.2
	local distanceDivisor = math.max(0.001, tonumber(resolvedOptions.DistanceDivisor) or 4000)
	local minimumDuration = math.max(0, tonumber(resolvedOptions.MinDuration) or 0.2)
	local maximumDuration = math.max(minimumDuration, tonumber(resolvedOptions.MaxDuration) or 0.7)
	state.Duration = math.clamp(baseDuration + (distance / distanceDivisor), minimumDuration, maximumDuration)
	return true, target - previousTarget, false
end

-- Advances the counter using the established cubic-out number motion. Returns
-- changed, current display value, and whether the target has been reached.
function NumberCounter.Step(state, now)
	if typeof(state) ~= "table" or state.Current == nil or state.Target == nil then
		return false, nil, true
	end
	if state.Current == state.Target then
		return false, state.Current, true
	end

	local duration = math.max(0.001, tonumber(state.Duration) or 0)
	local alpha = math.clamp((resolveNow(now) - (tonumber(state.StartAt) or 0)) / duration, 0, 1)
	local eased = 1 - ((1 - alpha) * (1 - alpha) * (1 - alpha))
	local from = tonumber(state.From) or tonumber(state.Current) or 0
	local target = tonumber(state.Target) or from
	local rawValue = from + ((target - from) * eased)
	local roundedValue
	if target >= from then
		roundedValue = math.floor(rawValue + 0.5)
	else
		roundedValue = math.ceil(rawValue - 0.5)
	end
	if alpha >= 1 then
		roundedValue = target
	end
	if roundedValue == 0 then
		roundedValue = 0 -- math.ceil of a small negative is -0, which would display as "-0"
	end

	local changed = roundedValue ~= state.Current
	state.Current = roundedValue
	return changed, roundedValue, alpha >= 1
end

function NumberCounter.Snap(state, value, options)
	if typeof(state) ~= "table" then
		return nil
	end
	local target = normalizeValue(value, options)
	state.Current = target
	state.From = target
	state.Target = target
	state.StartAt = os.clock()
	state.Duration = 0
	return target
end

return NumberCounter
