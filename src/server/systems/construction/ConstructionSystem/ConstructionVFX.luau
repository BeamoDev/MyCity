local ConstructionVFX = {}

function ConstructionVFX.applyPlacementVFX(constructionSite)
	local hitbox = constructionSite:FindFirstChild("Hitbox")
	if hitbox then
		local placeVFX = hitbox:FindFirstChild("PlaceVFX")
		if placeVFX then
			for _, child in ipairs(placeVFX:GetChildren()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = true
				end
			end
			task.delay(0.2, function()
				if placeVFX and placeVFX.Parent then
					for _, child in ipairs(placeVFX:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							child.Enabled = false
						end
					end
				end
			end)
		end
	end
end

function ConstructionVFX.applyCompletionVFX(building)
	local hitbox = building:FindFirstChild("Hitbox")
	if hitbox then
		local vfxAttachment = hitbox:FindFirstChild("VFX")
		if vfxAttachment then
			for _, particle in ipairs(vfxAttachment:GetChildren()) do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true
				end
			end

			local achievementSFX = vfxAttachment:FindFirstChild("AchievementSFX")
			if achievementSFX then
				achievementSFX:Play()
			end

			task.delay(5, function()
				for _, particle in ipairs(vfxAttachment:GetChildren()) do
					if particle:IsA("ParticleEmitter") then
						particle.Enabled = false
					end
				end
				if achievementSFX and achievementSFX:IsA("Sound") then
					achievementSFX:Stop()
				end
			end)
		end
	end
end

function ConstructionVFX.init()
	-- Any initialization needed for VFX
end

return ConstructionVFX
