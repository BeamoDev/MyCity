local fs = require("@lune/fs")

local placement = fs.readFile("src/server/systems/building/BuildingSystem/BuildingPlacement.luau")
local construction = fs.readFile("src/server/systems/construction/ConstructionSystem/init.luau")
local builder = fs.readFile("src/server/systems/construction/ConstructionSystem/ConstructionBuilder.luau")
local client = fs.readFile("src/client/controllers/ui/NotificationController/RemoteBindings.luau")
local controller = fs.readFile("src/client/controllers/ui/NotificationController/init.luau")

assert(
	placement:find("BuilderLimitReached:FireClient%(player, not hasBuilderPass%)"),
	"placement does not report pass eligibility"
)
assert(
	builder:find("ConstructionBuilder.ownsBuilderGamePass = ownsBuilderGamePass", 1, true),
	"construction ownership helper is not exposed"
)
assert(
	builder:find('player:GetAttribute("MyCityBuilderUIReady") == true', 1, true),
	"builder snapshots are sent before the client listener is ready"
)
assert(
	construction:find('player:GetAttribute("MyCityBuilderUIReady") == true', 1, true),
	"periodic builder scans run before client readiness"
)
local lifecycle = fs.readFile("src/server/bootstrap/PlayerLifecycle.luau")
assert(
	lifecycle:find('player:SetAttribute("MyCityBuilderUIReady", true)', 1, true),
	"ClientReady does not unlock builder snapshots"
)
assert(
	construction:find("not ConstructionBuilder.ownsBuilderGamePass%(player%)"),
	"construction race does not report pass eligibility"
)
assert(client:find("BUILDER_GAMEPASS_ID = 1407360513", 1, true), "wrong eighth-builder pass ID")
assert(client:find("PromptGamePassPurchase", 1, true), "builder-limit event does not prompt the pass")
assert(client:find("canUpgrade == false", 1, true), "pass owners are not excluded")
assert(client:find("lastBuilderPassPrompt", 1, true), "duplicate prompt protection is missing")
assert(controller:find('GetService%("MarketplaceService"%)'), "notification controller lacks MarketplaceService")
print("PASS: builder-limit placement prompts the eighth-builder pass only when upgradeable")
