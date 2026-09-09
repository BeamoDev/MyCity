local State = {}
local PlotManager = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plotsFolder = Workspace:WaitForChild("Plots")
local GRID_WIDTH = 10

State.CityNameSystem = nil

local Context = {
	State = State,
	PlotManager = PlotManager,
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	plotsFolder = plotsFolder,
	GRID_WIDTH = GRID_WIDTH,
}
require(script:WaitForChild("Scenery"))(Context)
require(script:WaitForChild("Assignment"))(Context)
require(script:WaitForChild("Reset"))(Context)
require(script:WaitForChild("Relocation"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return PlotManager
