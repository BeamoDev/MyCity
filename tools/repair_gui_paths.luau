-- Run in Studio Command Bar in EDIT mode with Script Sync paused.
-- Repairs only legacy FX scripts under StarterGui and ReplicatedStorage.Assets.
local function rewrite(source)
	local names = { ReplicatedStorage = true }
	for name in source:gmatch("local%s+([%a_][%w_]*)%s*=%s*game:GetService%s*%(%s*[\"']ReplicatedStorage[\"']%s*%)") do
		names[name] = true
	end
	for name in source:gmatch("local%s+([%a_][%w_]*)%s*=%s*game%.ReplicatedStorage") do
		names[name] = true
	end
	for name in names do
		local prefix = "%f[%w_]" .. name
		source = source:gsub(prefix .. "%s*%.%s*Modules%f[^%w_]", name .. ':WaitForChild("shared")')
		source = source:gsub(prefix .. ":WaitForChild%s*%(%s*[\"']Modules[\"']%s*%)", name .. ':WaitForChild("shared")')
	end
	source = source:gsub(
		"(game:GetService%s*%(%s*[\"']ReplicatedStorage[\"']%s*%))%s*%.%s*Modules%f[^%w_]",
		'%1:WaitForChild("shared")'
	)
	source = source:gsub('(:WaitForChild%("shared"%))%.UIEffects%f[^%w_]', '%1:WaitForChild("UIEffects")')
	return source
end
-- END REWRITE (used by the local regression test)
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before repairing source")
local editor = game:GetService("ScriptEditorService")
local history = game:GetService("ChangeHistoryService")
local storage = game:GetService("ReplicatedStorage")
assert(storage:FindFirstChild("shared") and storage.shared:FindFirstChild("UIEffects"), "Sync shared.UIEffects first")
history:SetWaypoint("Before MyCity GUI path repair")
local count = 0
for _, root in { game:GetService("StarterGui"), storage:FindFirstChild("Assets") } do
	if not root then
		continue
	end
	for _, instance in root:GetDescendants() do
		if instance:IsA("LuaSourceContainer") and instance.Name == "FX" then
			local changed = false
			editor:UpdateSourceAsync(instance, function(old)
				local updated = rewrite(old)
				changed = updated ~= old
				return updated
			end)
			if changed then
				count += 1
				print("[MyCity] Repaired", instance:GetFullName())
			end
		end
	end
end
history:SetWaypoint("After MyCity GUI path repair")
print("[MyCity] Updated", count, "FX scripts. Resume sync, then start a NEW Play session.")
for _, instance in game:GetDescendants() do
	if instance:IsA("Sound") and instance.SoundId:find("6525690145", 1, true) then
		warn("[MyCity] Sound permission must be resolved for this authored asset:", instance:GetFullName())
	end
end
