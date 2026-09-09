local Rows = require(script.Rows)
return function(Context)
	local rows
	function Context.cleanupConstructionDisplay()
		if rows then
			rows.clear()
			rows = nil
		end
	end
	function Context.setupConstructionDisplay()
		Context.cleanupConstructionDisplay()
		local frame = Context.State.ConstructionsFrame:FindFirstChild("Frame")
		local assets = Context.ReplicatedStorage:WaitForChild("Assets")
		local template = assets:WaitForChild("ConstructionTemplate", 10)
		if not frame or not template then
			warn(
				"[Construction UI] Expected HUD.Frames.Construction.Frame and ReplicatedStorage.Assets.ConstructionTemplate"
			)
			return
		end
		local container = frame:FindFirstChild("ScrollingFrame")
		local empty = frame:FindFirstChild("ErrorFrame")
		if not container or not empty then
			warn("[Construction UI] Missing ScrollingFrame/ErrorFrame")
			return
		end
		rows = Rows.new(template, container, Context.TweenService)
		local function render()
			empty.Visible = rows.render(os.clock()) == 0
		end
		Context.connections:connect(
			Context.ReplicatedStorage.Events.UI.UpdateConstructionUI.OnClientEvent,
			function(action, data)
				if action == "clear" then
					rows.clear()
				elseif action == "snapshot" and type(data) == "table" then
					rows.clear()
					for _, item in data do
						rows.upsert(item, os.clock())
					end
				elseif action == "start" then
					rows.upsert(data, os.clock())
				elseif action == "remove" and type(data) == "table" then
					rows.remove(data.Id)
				end
				render()
			end
		)
		local elapsed = 0
		Context.connections:connect(Context.RunService.Heartbeat, function(dt)
			elapsed += dt
			if elapsed < 0.25 then
				return
			end
			elapsed = 0
			render()
		end)
		render()
	end
end
