local State = {}
local SellSystem = {}
local Guard = require(script.Parent.Parent.security.RequestGuard)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SellEvents = ReplicatedStorage.Events.Sell
local SellItemEvent = SellEvents.SellItem
local OpenSellUIEvent = SellEvents.OpenUI
local UpdateUIEvent = ReplicatedStorage.Events.Sell.SellUICurrentTool

local BASE_PROFIT_MARGINS = {
	Common = 1.15,
	Rare = 1.25,
	Legendary = 1.35,
}

local LEVEL_VALUE_SCALING = {
	Common = 0.08,
	Rare = 0.12,
	Legendary = 0.18,
}

local XP_VALUE_SCALING = 0.05

local MUTATION_BONUSES = {
	Speed = 0.20,
	Income = 0.25,
	Population = 0.15,
	Defense = 0.18,
	Efficiency = 0.22,
}

local SPECIAL_BUILDING_MULTIPLIERS = {
	Bank = 1.1,
	Airport = 1.15,
	Stadium = 1.12,
	Mall = 1.08,
}

local Context = {
	State = State,
	SellSystem = SellSystem,
	Guard = Guard,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	SellEvents = SellEvents,
	SellItemEvent = SellItemEvent,
	OpenSellUIEvent = OpenSellUIEvent,
	UpdateUIEvent = UpdateUIEvent,
	BASE_PROFIT_MARGINS = BASE_PROFIT_MARGINS,
	LEVEL_VALUE_SCALING = LEVEL_VALUE_SCALING,
	XP_VALUE_SCALING = XP_VALUE_SCALING,
	MUTATION_BONUSES = MUTATION_BONUSES,
	SPECIAL_BUILDING_MULTIPLIERS = SPECIAL_BUILDING_MULTIPLIERS,
}
require(script:WaitForChild("Valuation"))(Context)
require(script:WaitForChild("Display"))(Context)
require(script:WaitForChild("Sale"))(Context)
require(script:WaitForChild("PromptBinding"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return SellSystem
