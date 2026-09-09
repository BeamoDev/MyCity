--[[
	Name: Satchel
	Description: Loads the Satchel backpack system.
	DevForum: https://devforum.roblox.com/t/2451549
]]

--[[
	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at Mozilla Public License Version 2.0.
]]

-- A copied loader must not create a second inventory or competing input handlers.
local player = game:GetService("Players").LocalPlayer
if player:GetAttribute("MyCitySatchelActive") then
	return
end
player:SetAttribute("MyCitySatchelActive", true)
local ok, result = pcall(require, script:WaitForChild("Satchel"))
if not ok then
	player:SetAttribute("MyCitySatchelActive", nil)
	error(result)
end
