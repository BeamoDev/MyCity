-- Shared across joining players, so simultaneous restores share one frame budget.
-- A single authored model clone is indivisible; limits apply between objects.
local Heartbeat = game:GetService("RunService").Heartbeat
local Budget = {}
local started, count = nil, 0
local MAX_OBJECTS = 6
local MAX_SECONDS = 0.003
Heartbeat:Connect(function()
	started, count = nil, 0
end)
function Budget.checkpoint(player)
	while count >= MAX_OBJECTS or (started and os.clock() - started >= MAX_SECONDS) do
		Heartbeat:Wait()
	end
	assert(player.Parent and not player:GetAttribute("MyCityLeaving"), "Player left during city restoration")
	started = started or os.clock()
	count += 1
end
return Budget
