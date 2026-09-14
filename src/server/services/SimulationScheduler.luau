-- One shared clock, earliest-deadline queue and bounded dispatch per server frame.
local RunService = game:GetService("RunService")
local Scheduler = {}
local heap, jobs = {}, {}
local connection
local nextId = 0
local function before(a, b)
	return a.due < b.due or (a.due == b.due and a.id < b.id)
end
local function push(job)
	local i = #heap + 1
	while i > 1 do
		local parent = math.floor(i / 2)
		if not before(job, heap[parent]) then
			break
		end
		heap[i], i = heap[parent], parent
	end
	heap[i] = job
end
local function pop()
	local first = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		local i = 1
		while i * 2 <= #heap do
			local child = i * 2
			if child < #heap and before(heap[child + 1], heap[child]) then
				child += 1
			end
			if not before(heap[child], last) then
				break
			end
			heap[i], i = heap[child], child
		end
		heap[i] = last
	end
	return first
end
function Scheduler.every(interval, callback)
	assert(interval > 0, "Periodic interval must be positive")
	nextId += 1
	local now = os.clock()
	local job =
		{ id = nextId, interval = interval, callback = callback, last = now, due = now + interval, active = true }
	jobs[job.id] = job
	push(job)
	if not connection then
		connection = RunService.Heartbeat:Connect(function()
			local started, dispatched = os.clock(), 0
			while heap[1] and heap[1].due <= os.clock() do
				local current = pop()
				if current.active then
					local tick = os.clock()
					local elapsed = tick - current.last
					current.last = tick
					task.spawn(function()
						if not current.active then
							return
						end
						local ok, keep = pcall(current.callback, elapsed)
						if not ok then
							warn("[Simulation] Periodic work failed:", keep)
						end
						if not ok or keep == false or not current.active then
							current.active, jobs[current.id] = false, nil
						else
							-- A yielding callback cannot overlap itself or trigger a catch-up burst.
							current.due = math.max(current.last + current.interval, os.clock() + 0.01)
							push(current)
						end
					end)
					dispatched += 1
				end
				if dispatched >= 6 or os.clock() - started >= 0.003 then
					break
				end
			end
			if next(jobs) == nil then
				connection:Disconnect()
				connection = nil
				table.clear(heap)
			end
		end)
	end
	return function()
		job.active, jobs[job.id] = false, nil
	end
end
return Scheduler
