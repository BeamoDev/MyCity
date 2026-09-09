-- READ ONLY: run in Studio Command Bar after syncing the source.
-- Fetches product metadata and checks authored models; never prompts or grants purchases.
local server = assert(game:GetService("ServerScriptService"):FindFirstChild("server"), "Missing server folder")
local products = require(server.services.MarketPlaceHandler.ProductConfig)
local buildings = require(server.config.BuildingConfig)
local marketplace = game:GetService("MarketplaceService")
local assets = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Assets"), "Missing Assets")
local ids = {}
for _, group in { products.Rewards, products.Shop, products.Skip } do
	for id in group do
		ids[id] = Enum.InfoType.Product
	end
end
for _, id in { products.BuildAll, products.Refresh, products.Steal } do
	ids[id] = Enum.InfoType.Product
end
for _, id in { 1406723890, 1407360513, 1406735933 } do
	ids[id] = Enum.InfoType.GamePass
end
local expected = {
	[3375058573] = 7,
	[3375058621] = 15,
	[3375058684] = 25,
	[3375058756] = 40,
	[3375058850] = 75,
	[3375058936] = 150,
	[3375061785] = 300,
}
local issues = 0
for id, kind in ids do
	local ok, info = pcall(function()
		return marketplace:GetProductInfoAsync(id, kind)
	end)
	if not ok then
		issues += 1
		warn("[Commerce] Product lookup failed", id, info)
	else
		print("[Commerce]", id, info.Name, "Robux:", info.PriceInRobux, "ForSale:", info.IsForSale)
		if info.IsForSale == false or (expected[id] and expected[id] ~= info.PriceInRobux) then
			issues += 1
			warn("[Commerce] Check availability/UI price", id, "UI tier", expected[id], "actual", info.PriceInRobux)
		end
	end
end
for name, definition in buildings do
	local models = game:GetService("ServerStorage"):FindFirstChild("Buildings")
	local model = models and models:FindFirstChild(name)
	local base = model and (model:FindFirstChild("Base") or model:FindFirstChild("Hitbox"))
	if not model or not model:IsA("Model") or not model.PrimaryPart or not base or not base:IsA("BasePart") then
		issues += 1
		warn("[Commerce] Missing/unplaceable building model", name)
	end
	if (definition.BuildTime or 0) > 0 then
		local template = assets:FindFirstChild("Constructions") and assets.Constructions:FindFirstChild(definition.Size)
		if not template or not template:IsA("Model") or not template.PrimaryPart then
			issues += 1
			warn("[Commerce] Missing construction template", name, definition.Size)
		end
	end
end
print(
	"[Commerce] Audit finished; issues:",
	issues,
	"Live receipts, pass benefits, UI bindings and mobile placement still require playtesting."
)
