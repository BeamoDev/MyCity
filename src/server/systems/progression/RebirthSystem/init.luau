local State = {}
-- RebirthSystem.lua
local RebirthSystem = {}
local initialized = setmetatable({}, { __mode = "k" })

local Guard = require(script.Parent.Parent.security.RequestGuard)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingSystem = require(script.Parent.Parent:WaitForChild("building"):WaitForChild("BuildingSystem"))
local IncomeSystem = require(script.Parent.Parent:WaitForChild("economy"):WaitForChild("IncomeSystem"))
local RebirthConfig = require(script.Parent:WaitForChild("RebirthConfig"))
local BuildingConfig = require(script.Parent.Parent.Parent:WaitForChild("config"):WaitForChild("BuildingConfig"))

local events = ReplicatedStorage:FindFirstChild("Events")
local rebirthFolder = events:FindFirstChild("Rebirth")
local requestRebirth = rebirthFolder:FindFirstChild("RequestRebirth")
local rebirthSuccess = rebirthFolder:FindFirstChild("RebirthSuccess")
local rebirthFailed = rebirthFolder:FindFirstChild("RebirthFailed")
local updateRebirthUI_ = rebirthFolder:FindFirstChild("UpdateRebirthUI")

local Context = {
	State = State,
	RebirthSystem = RebirthSystem,
	initialized = initialized,
	Guard = Guard,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	BuildingSystem = BuildingSystem,
	IncomeSystem = IncomeSystem,
	RebirthConfig = RebirthConfig,
	BuildingConfig = BuildingConfig,
	events = events,
	rebirthFolder = rebirthFolder,
	requestRebirth = requestRebirth,
	rebirthSuccess = rebirthSuccess,
	rebirthFailed = rebirthFailed,
	updateRebirthUI_ = updateRebirthUI_,
}
require(script:WaitForChild("Display"))(Context)
require(script:WaitForChild("Reset"))(Context)
require(script:WaitForChild("Rebirth"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return RebirthSystem
