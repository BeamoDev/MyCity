-- Reuse successful ownership checks across building, builder and income systems.
local Marketplace = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Ownership = {}
local cache = {}
local TTL = 60
function Ownership.has(player, passId)
	if not player.Parent then
		return false
	end
	local entries = cache[player]
	if not entries then
		entries = {}
		cache[player] = entries
	end
	local entry = entries[passId]
	if entry and entry.loading then
		repeat
			task.wait()
		until not entry.loading or not player.Parent
		local current = entries[passId]
		return player.Parent ~= nil and (current or entry).value == true
	end
	if entry and entry.expires > os.clock() then
		return entry.value
	end
	entry = { loading = true, value = false, expires = 0 }
	entries[passId] = entry
	local ok, owned = pcall(Marketplace.UserOwnsGamePassAsync, Marketplace, player.UserId, passId)
	entry.value, entry.loading = ok and owned == true, false
	entry.expires = os.clock() + TTL
	if not ok and entries[passId] == entry then
		entries[passId] = nil
	end
	-- A completed purchase may replace the entry while the ownership call yields.
	return player.Parent ~= nil and (entries[passId] or entry).value == true
end
Marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and player.Parent then
		local entries = cache[player] or {}
		cache[player] = entries
		entries[passId] = { value = true, expires = os.clock() + TTL }
	end
end)
Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)
return Ownership
