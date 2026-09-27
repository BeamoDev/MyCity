-- Execute the lifetime new-player funnel against AnalyticsService mocks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function value(initial)
	return { Value = initial }
end

local function node(fields)
	fields = fields or {}
	function fields:FindFirstChild(name)
		return self[name]
	end
	return fields
end

local calls = {}
local analyticsService = {
	LogFunnelStepEvent = function(_, player, funnelName, funnelId, step, stepName)
		table.insert(calls, {
			player = player,
			funnelName = funnelName,
			funnelId = funnelId,
			step = step,
			stepName = stepName,
		})
	end,
	LogCustomEvent = function() end,
}
local playersService = {
	PlayerAdded = { Connect = function() end },
	PlayerRemoving = { Connect = function() end },
	GetPlayers = function()
		return {}
	end,
}
local heartbeat = {
	Connect = function()
		return { Disconnect = function() end }
	end,
}
local root = { config = { TutorialConfig = { OwnerUserId = 1790165114 } } }
local scriptMock = { Parent = { Parent = root } }

local analytics = luau.load(fs.readFile("src/server/persistence/FunnelAnalytics.luau"), {
	environment = {
		script = scriptMock,
		require = function(module)
			return module
		end,
		tick = function()
			return 100
		end,
		game = {
			GetService = function(_, name)
				if name == "AnalyticsService" then
					return analyticsService
				elseif name == "HttpService" then
					return { GenerateGUID = function()
						return "new-player-guid"
					end }
				elseif name == "Players" then
					return playersService
				elseif name == "RunService" then
					return { Heartbeat = heartbeat }
				end
				error("Unexpected service " .. name)
			end,
		},
	},
})()

local function player(userId, isNew, version, funnelId, tutorialStage, inTutorial, questProgression, allDone)
	local attributes = { MyCityNewProfile = isNew }
	local object = node({
		Name = "Player" .. userId,
		UserId = userId,
		Parent = true,
		Data = node({
			PlayerInfo = node({
				ProgressionFunnelVersion = value(version or 0),
				ProgressionFunnelId = value(funnelId or ""),
				Tutorial = node({ ServerStage = value(tutorialStage or 0), IsInTutorial = value(inTutorial ~= false) }),
				Quests = node({
					QuestProgression = value(questProgression or 0),
					PostTutorialQuestComplete = value(allDone == true),
				}),
			}),
		}),
	})
	function object:GetAttribute(name)
		return attributes[name]
	end
	return object
end

local fresh = player(10, true)
assert(analytics.prepareProgression(fresh))
assert(fresh.Data.PlayerInfo.ProgressionFunnelVersion.Value == 1)
assert(fresh.Data.PlayerInfo.ProgressionFunnelId.Value == "new-player-guid")
analytics.Tutorial.Started(fresh)
analytics.Tutorial.BankGiven(fresh)
analytics.Tutorial.BankEquipped(fresh)
analytics.Tutorial.BankPlaced(fresh)
analytics.Tutorial.BankBuilt(fresh)
analytics.Tutorial.IncomeCollected(fresh)
analytics.Tutorial.ShopOpened(fresh)
analytics.Tutorial.ShackPurchased(fresh)
analytics.Tutorial.ShackEquipped(fresh)
analytics.Tutorial.ShackPlaced(fresh)
analytics.Tutorial.ShackBuilt(fresh)
analytics.Tutorial.Completed(fresh)
analytics.Quest.Completed(fresh, 1, "collect_income")
analytics.Quest.Completed(fresh, 35, "population_11000")
analytics.Quest.AllCompleted(fresh)

assert(calls[1].funnelName == "NewPlayerProgression_v1" and calls[1].step == 1)
assert(calls[1].stepName == "PlayerJoined")
assert(calls[13].step == 13 and calls[13].stepName == "TutorialCompleted")
assert(calls[14].step == 14 and calls[14].stepName == "Q01_collect_income")
assert(calls[15].step == 48 and calls[15].stepName == "Q35_population_11000")
assert(calls[16].step == 49 and calls[16].stepName == "AllProgressionCompleted")

local before = #calls
local established = player(11, false)
assert(not analytics.prepareProgression(established) and #calls == before, "Established profile entered new funnel")

local resumed = player(12, false, 1, "saved-guid", 7, false, 12, false)
assert(analytics.prepareProgression(resumed))
analytics.Quest.Reconcile(resumed, 12, false, "population_650")
assert(calls[#calls].funnelId == "saved-guid")
assert(calls[#calls].step == 25 and calls[#calls].stepName == "Q12_population_650")

local owner = player(1790165114, true)
before = #calls
assert(not analytics.prepareProgression(owner) and #calls == before, "Owner polluted progression funnel")

print("PASS: one 49-step lifetime funnel enrolls only new profiles, survives rejoin and maps tutorial/quests")
