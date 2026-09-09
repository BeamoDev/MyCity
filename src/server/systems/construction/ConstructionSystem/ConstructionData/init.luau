local State = {}
local ConstructionData = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local plotsFolder = Workspace:WaitForChild("Plots")

local Context = {
	State = State,
	ConstructionData = ConstructionData,
	Workspace = Workspace,
	ReplicatedStorage = ReplicatedStorage,
	HttpService = HttpService,
	plotsFolder = plotsFolder,
}
require(script:WaitForChild("Coordinates"))(Context)
require(script:WaitForChild("Serialization"))(Context)
require(script:WaitForChild("Restoration"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return ConstructionData
