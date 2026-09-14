local fs, luau = require("@lune/fs"), require("@lune/luau")
local now, frame, connections, warnings = 0, nil, 0, 0
local queue = {}
local scheduler = luau.load(fs.readFile("src/server/services/SimulationScheduler.luau"), {
	environment = {
		game = {
			GetService = function()
				return {
					Heartbeat = {
						Connect = function(_, callback)
							frame = callback
							connections += 1
							return {
								Disconnect = function()
									connections -= 1
									frame = nil
								end,
							}
						end,
					},
				}
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		task = {
			spawn = function(callback)
				table.insert(queue, coroutine.create(callback))
			end,
		},
		warn = function()
			warnings += 1
		end,
	},
})()
local calls, elapsed = {}, {}
for i = 1, 20 do
	scheduler.every(1, function(dt)
		table.insert(calls, i)
		elapsed[i] = dt
		return false
	end)
end
assert(connections == 1)
now = 4
frame()
assert(#queue == 6, "Dispatch burst exceeded frame limit")
local function flush()
	local pending = queue
	queue = {}
	for _, thread in pending do
		assert(coroutine.resume(thread))
	end
end
flush()
for _ = 1, 3 do
	now += 0.01
	frame()
	flush()
end
assert(#calls == 20)
for i = 1, 20 do
	assert(calls[i] == i and elapsed[i] >= 4, "Starvation or elapsed time lost")
end
frame()
assert(connections == 0)
local runs, suspended = 0, nil
local cancel = scheduler.every(1, function()
	runs += 1
	suspended = coroutine.running()
	coroutine.yield()
	return true
end)
now += 2
frame()
flush()
now += 5
frame()
flush()
assert(runs == 1, "Yielding callback overlapped itself")
cancel()
assert(coroutine.resume(suspended))
frame()
assert(connections == 0)
local canceled = scheduler.every(1, function()
	error("Canceled callback ran")
end)
canceled()
now += 2
frame()
flush()
assert(connections == 0 and warnings == 0)
scheduler.every(1, function()
	error("injected failure")
end)
now += 2
frame()
flush()
frame()
assert(warnings == 1 and connections == 0)
print(
	"PASS: bounded fair scheduler, elapsed catch-up, yielding non-overlap, cancellation, failure cleanup and one connection"
)
