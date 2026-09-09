-- Own connections and asynchronous work for one controller/HUD lifetime.
local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ connections = {}, threads = {}, generation = 0 }, Scope)
end

function Scope:connect(signal, callback)
	local generation = self.generation
	local connection = signal:Connect(function(...)
		if self.generation ~= generation then
			return
		end
		local thread = coroutine.running()
		self.threads[thread] = true
		local results = table.pack(pcall(callback, ...))
		self.threads[thread] = nil
		if not results[1] then
			warn("[Controller]", results[2])
		end
	end)
	table.insert(self.connections, connection)
	return connection
end

function Scope:_schedule(scheduler, callback, ...)
	local args = table.pack(...)
	local generation = self.generation
	local thread = coroutine.create(function()
		if generation ~= self.generation then
			return
		end
		local results = table.pack(pcall(callback, table.unpack(args, 1, args.n)))
		self.threads[coroutine.running()] = nil
		if not results[1] then
			warn("[Controller task]", results[2])
		end
	end)
	self.threads[thread] = true
	scheduler(thread)
	return thread
end

function Scope:spawn(callback, ...)
	return self:_schedule(task.spawn, callback, ...)
end

function Scope:defer(callback, ...)
	return self:_schedule(task.defer, callback, ...)
end

function Scope:delay(seconds, callback, ...)
	return self:_schedule(function(thread)
		task.delay(seconds, thread)
	end, callback, ...)
end

function Scope:clear()
	self.generation += 1
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	local current = coroutine.running()
	for thread in self.threads do
		if thread ~= current and coroutine.status(thread) ~= "dead" then
			pcall(task.cancel, thread)
		end
	end
	table.clear(self.threads)
end

return Scope
