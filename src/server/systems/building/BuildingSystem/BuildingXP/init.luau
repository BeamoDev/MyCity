local State = {}
local BuildingXP = {}
local pulses = setmetatable({}, { __mode = "k" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MAX_LEVEL = 99
local BASE_XP_REQUIREMENT = 100
local XP_SCALING_FACTOR = 1.15
local XP_GAIN_INTERVAL = 5
local BASE_XP_PER_TICK = 2

local XP_MULTIPLIERS = {
	[0] = 1,
	[1000] = 1.2,
	[10000] = 1.5,
	[50000] = 2.0,
	[100000] = 2.5,
	[300000] = 3.0,
	[500000] = 4.0,
	[1000000] = 5.0,
}

State.buildingXPLoops = {}
State.RebirthConfig = nil

local Context = {
	State = State,
	BuildingXP = BuildingXP,
	pulses = pulses,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	TweenService = TweenService,
	MAX_LEVEL = MAX_LEVEL,
	BASE_XP_REQUIREMENT = BASE_XP_REQUIREMENT,
	XP_SCALING_FACTOR = XP_SCALING_FACTOR,
	XP_GAIN_INTERVAL = XP_GAIN_INTERVAL,
	BASE_XP_PER_TICK = BASE_XP_PER_TICK,
	XP_MULTIPLIERS = XP_MULTIPLIERS,
}
require(script:WaitForChild("Effects"))(Context)
require(script:WaitForChild("Progression"))(Context)
require(script:WaitForChild("Awards"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return BuildingXP
