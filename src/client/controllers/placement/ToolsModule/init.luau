local createSession = require(script:WaitForChild("Session"))
local ToolHandler = {}
local initializedTools = setmetatable({}, { __mode = "k" })
local cooldown = { expires = 0, active = false }
function ToolHandler.init(tool)
	return createSession(tool, initializedTools, cooldown)
end
return ToolHandler
