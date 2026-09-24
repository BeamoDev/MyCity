local fs = require("@lune/fs")
local luau = require("@lune/luau")
local record, saveOk, promptThrows, prompts = {}, true, false, 0
local finished
local data = {
	isLoaded = function()
		return true
	end,
	getRecord = function()
		return record
	end,
	savePlayerData = function()
		return saveOk
	end,
}
local guard = {
	ready = function()
		return true
	end,
}
local player = {}
local marketplace = {
	PromptProductPurchase = function()
		prompts += 1
		if promptThrows then
			error("prompt failed")
		end
	end,
	PromptProductPurchaseFinished = {
		Connect = function(_, fn)
			finished = fn
		end,
	},
}
local root = { persistence = { PlayerDataModule = data }, systems = { security = { RequestGuard = guard } } }
local intents = luau.load(
	fs.readFile("src/server/services/MarketPlaceHandler/PurchaseIntents.luau"),
	{
		environment = {
			script = { Parent = { Parent = { Parent = root } } },
			require = function(module)
				return module
			end,
			game = {
				GetService = function(_, name)
					return if name == "MarketplaceService"
						then marketplace
						else {
							GetPlayerByUserId = function()
								return player
							end,
						}
				end,
			},
		},
	}
)()
intents.init()
saveOk = false
assert(not intents.prompt(player, 1, { Name = "A" }) and prompts == 0 and not record.PurchaseIntents["1"])
saveOk, promptThrows = true, true
assert(not intents.prompt(player, 1, { Name = "A" }) and not record.PurchaseIntents["1"])
promptThrows = false
assert(intents.prompt(player, 1, { Name = "A" }))
-- A lost cancellation must never block the next purchase: the old choice is archived instead.
assert(intents.prompt(player, 1, { Name = "B" }) and record.PurchaseIntents["1"].Details.Name == "B")
assert(record.IntentArchive["1"][1].Details.Name == "A", "Replaced choice was not archived")
finished(7, 1, false)
assert(not record.PurchaseIntents["1"] and #record.IntentArchive["1"] == 1)
assert(intents.prompt(player, 1, { Name = "B" }))
record.PurchaseIntents["1"].PurchaseId = "paid"
finished(7, 1, false)
assert(record.PurchaseIntents["1"].PurchaseId == "paid")
-- A bound intent's plan lives in its receipt entry, so a new prompt replaces it without archiving.
assert(intents.prompt(player, 1, { Name = "C" }) and record.PurchaseIntents["1"].Details.Name == "C")
assert(#record.IntentArchive["1"] == 1)
for index = 1, 25 do
	intents.prompt(player, 1, { Name = "N" .. index })
end
assert(#record.IntentArchive["1"] == 20, "Archive is bounded")
print(
	"PASS: intent save failure, prompt failure retry, replacement archives instead of blocking, cancellation, bound paid intent preserved, bounded archive"
)
