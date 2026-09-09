local Controller = {}
local started = false
function Controller.start()
	if started then
		return
	end
	started = true
	--// ========================================================================
	--// SERVICES & VARIABLES
	--// ========================================================================
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local localPlayer = Players.LocalPlayer
	local highlightTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Highlight")
	local activeHighlight = nil

	--// ========================================================================
	--// CONFIGURATION
	--// ========================================================================
	local PROMPT_CONFIGS = {
		Tile = {
			getTarget = function(parent)
				return parent
			end,
			outlineColor = Color3.new(1, 1, 1),
			billboardPath = nil,
		},
		Character = {
			getTarget = function(parent)
				return parent:FindFirstChild("Beamo") or parent
			end,
			outlineColor = Color3.new(1, 1, 1),
			billboardPath = nil,
		},
		Building = {
			getTarget = function(parent)
				return parent
			end,
			outlineColor = Color3.new(1, 1, 1),
			billboardPath = { "Hitbox", "BuildingInfo" },
		},
		Construction = {
			getTarget = function(parent)
				return parent
			end,
			outlineColor = Color3.new(1, 1, 0),
			billboardPath = { "Base", "ConstructionInfo" },
		},
	}

	--// ========================================================================
	--// UTILITY FUNCTIONS
	--// ========================================================================
	local function debugPrint(message)
		if RunService:IsStudio() then
			print("[ProximityHighlight]: " .. message)
		end
	end

	local function cleanupHighlight()
		if activeHighlight then
			activeHighlight:Destroy()
			activeHighlight = nil
		end
	end

	local function getBillboard(parent, pathArray)
		if not pathArray or #pathArray < 2 then
			return nil
		end

		local container = parent:FindFirstChild(pathArray[1])
		if container then
			return container:FindFirstChild(pathArray[2])
		end
		return nil
	end

	local function setBillboardEnabled(parent, pathArray, enabled)
		local billboard = getBillboard(parent, pathArray)
		if billboard then
			billboard.Enabled = enabled
			return true
		end
		return false
	end

	local function createHighlight(adornee, color)
		if not adornee then
			return nil
		end

		cleanupHighlight() -- Always cleanup existing highlight first

		local highlight = highlightTemplate:Clone()
		highlight.Adornee = adornee
		highlight.OutlineColor = color
		highlight.Parent = Workspace

		return highlight
	end

	--// ========================================================================
	--// PROMPT HANDLERS
	--// ========================================================================
	local function handlePromptShown(prompt)
		-- Validate prompt structure
		local promptParent = prompt.Parent
		if not promptParent then
			debugPrint("Prompt parent not found")
			return
		end

		local promptVal = promptParent:FindFirstChild("PromptVal")
		if not promptVal then
			return
		end -- Other prompts do not opt into building highlights.
		if not promptVal:IsA("StringValue") then
			debugPrint("PromptVal must be a StringValue")
			return
		end

		local promptType = promptVal.Value
		local config = PROMPT_CONFIGS[promptType]

		if not config then
			debugPrint("Unhandled prompt type: " .. promptType)
			return
		end

		local targetParent = promptParent.Parent
		if not targetParent then
			debugPrint("Target parent not found")
			return
		end

		-- Get the target adornee using the getTarget function (not calling targetPath as function)
		local adornee = nil
		if config.getTarget then
			adornee = config.getTarget(targetParent)
		else
			adornee = targetParent
		end

		if not adornee then
			debugPrint(promptType .. " target not found")
			return
		end

		-- Handle billboard if needed
		if config.billboardPath then
			setBillboardEnabled(targetParent, config.billboardPath, true)
		end

		-- Create the highlight
		activeHighlight = createHighlight(adornee, config.outlineColor)
	end

	local function handlePromptHidden(prompt)
		-- Always cleanup highlight
		cleanupHighlight()

		-- Handle billboard disabling if prompt is valid
		if prompt and prompt.Parent then
			local promptVal = prompt.Parent:FindFirstChild("PromptVal")
			if promptVal and promptVal:IsA("StringValue") then
				local promptType = promptVal.Value
				local config = PROMPT_CONFIGS[promptType]

				if config and config.billboardPath then
					local targetParent = prompt.Parent.Parent
					if targetParent then
						setBillboardEnabled(targetParent, config.billboardPath, false)
					end
				end
			end
		end
	end

	--// ========================================================================
	--// CONNECTIONS
	--// ========================================================================
	ProximityPromptService.PromptShown:Connect(handlePromptShown)
	ProximityPromptService.PromptHidden:Connect(handlePromptHidden)

	--// ========================================================================
	--// CLEANUP ON PLAYER LEAVING
	--// ========================================================================
	Players.PlayerRemoving:Connect(function(player)
		if player == localPlayer then
			cleanupHighlight()
		end
	end)
end
return Controller
