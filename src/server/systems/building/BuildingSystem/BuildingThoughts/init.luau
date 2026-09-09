local State = {}
local BuildingThoughts = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local plotsFolder = Workspace:WaitForChild("Plots")

-- Configuration
local THOUGHT_DURATION = math.random(20, 40)
local MAX_CONCURRENT_THOUGHTS = 0.1
local CHECK_INTERVAL = 15
local FADE_DURATION = 1.5

-- More direct and helpful thought messages
local THOUGHTS = {
	-- Happy thoughts (all stats good)
	happy = {
		"I love living here!",
		"This neighborhood is perfect!",
		"Everything is great here!",
		"Best place to live!",
		"I feel so safe and healthy!",
		"Life is amazing here!",
		"This city is well-managed!",
		"I'm so happy here!",
		"Perfect place to raise kids!",
		"Everything works perfectly!",
	},

	-- Need police station
	crime = {
		"We need a Police Station nearby!",
		"Build a Police Station please!",
		"Crime is high - need police!",
		"Police Station would help!",
		"Too much crime without police!",
		"A Police Station would make us safer!",
		"Please build police protection!",
		"We're unsafe without police!",
		"Police Station needed urgently!",
		"Crime won't stop without police!",
	},

	-- Need fire station
	fire = {
		"We need a Fire Station nearby!",
		"Build a Fire Station please!",
		"Fire Station would help!",
		"No fire protection is scary!",
		"A Fire Station would save lives!",
		"Please build fire protection!",
		"Fire Station needed urgently!",
		"We're at risk without firefighters!",
		"Build Fire Station for safety!",
		"Fire danger - need Fire Station!",
	},

	-- Need hospital
	health = {
		"We need a Hospital nearby!",
		"Build a Hospital please!",
		"Hospital would help us!",
		"We need medical care!",
		"A Hospital would save lives!",
		"Please build a Hospital!",
		"Hospital needed urgently!",
		"No doctors nearby - need Hospital!",
		"Build Hospital for health!",
		"Medical emergency - need Hospital!",
	},

	-- Need decorations/trees for happiness
	unhappy = {
		"Plant some Trees to beautify!",
		"We need Trees and decorations!",
		"Add Trees for happiness!",
		"Decorations would cheer us up!",
		"Plant Trees to improve mood!",
		"We need parks and Trees!",
		"Trees make people happy!",
		"Add decorations please!",
		"Green spaces needed!",
		"Trees and parks would help!",
	},

	-- Neutral (some stats okay, some not)
	neutral = {
		"It's okay here, I guess...",
		"Could use some improvements.",
		"Not bad, but not great.",
		"Some services are missing.",
		"We need more city services.",
		"It's decent but needs work.",
		"Room for improvement here.",
		"Basic needs met, barely.",
		"Could be better with services.",
		"Needs police, fire, or hospital.",
	},
}

State.activeThoughts = {}

local Context = {
	State = State,
	BuildingThoughts = BuildingThoughts,
	TweenService = TweenService,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Workspace,
	RunService = RunService,
	plotsFolder = plotsFolder,
	THOUGHT_DURATION = THOUGHT_DURATION,
	MAX_CONCURRENT_THOUGHTS = MAX_CONCURRENT_THOUGHTS,
	CHECK_INTERVAL = CHECK_INTERVAL,
	FADE_DURATION = FADE_DURATION,
	THOUGHTS = THOUGHTS,
}
require(script:WaitForChild("Selection"))(Context)
require(script:WaitForChild("Presentation"))(Context)
require(script:WaitForChild("Lifecycle"))(Context)

return BuildingThoughts
