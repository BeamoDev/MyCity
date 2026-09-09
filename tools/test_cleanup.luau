local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local Scope = luau.load(fs.readFile("src/shared/util/ConnectionScope.luau"), { environment = { task = task } })()
local callbacks = {}
local signal = {
	Connect = function(_, callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
		end
		table.insert(callbacks, { callback, connection })
		return connection
	end,
}
local scope = Scope.new()
local count = 0
scope:connect(signal, function()
	count += 1
end)
callbacks[1][1]()
assert(count == 1)
scope:delay(0.02, function()
	count += 100
end)
scope:clear()
assert(not callbacks[1][2].Connected)
callbacks[1][1]()
task.wait(0.04)
assert(count == 1, "Old HUD callback or delayed task survived cleanup")
scope:connect(signal, function()
	count += 1
end)
callbacks[2][1]()
assert(count == 2, "A new HUD could not reuse the scope")
scope:clear()
print(
	"PASS: old signals disconnected, delayed work cancelled, stale callbacks rejected, scope reusable for replacement HUD"
)
