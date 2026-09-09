local Controller = {}
local started = false
function Controller.start()
	if started then
		return
	end
	started = true
	local StarterGui = game:GetService("StarterGui")

	-- Wait for SetCore to be available
	local success, err = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)

	-- Retry if it fails
	while not success do
		wait(1) -- Wait for a bit before trying again
		success, err = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
	end
end
return Controller
