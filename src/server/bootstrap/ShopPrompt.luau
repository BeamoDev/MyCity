local Guard = require(script.Parent.Parent.systems.security.RequestGuard)
local Binding = {}
local started = false
function Binding.start()
	if started then
		return
	end
	started = true
	local map = workspace:FindFirstChild("Map")
	local interactives = map and map:FindFirstChild("Interactives")
	local area = interactives and interactives:FindFirstChild("BuyArea")
	local model = area and area:FindFirstChild("Model")
	local part = model and model:FindFirstChild("Prompt")
	local prompt = part and part:FindFirstChild("ShopPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn("[Shop] Missing Workspace.Map.Interactives.BuyArea.Model.Prompt.ShopPrompt")
		return
	end
	prompt.Triggered:Connect(function(player)
		if not Guard.ready(player) then
			return
		end
		local tutorial = player.Data.PlayerInfo.Tutorial.IsInTutorial
		if tutorial.Value then
			return
		end
		game:GetService("ReplicatedStorage").Events.UI.OpenItemShop:FireClient(player)
	end)
end
return Binding
