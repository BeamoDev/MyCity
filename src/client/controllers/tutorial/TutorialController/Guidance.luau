-- Guidance: focused implementation for TutorialController.
return function(Context)
	local State = Context.State
	local RunService = Context.RunService
	local player = Context.player
	local tutorialState = Context.tutorialState

	function Context.createPlayerAnchor()
		if tutorialState.playerAnchor then
			return
		end

		local beamTemplate = script.Parent:FindFirstChild("TutorialBeamAnchor")
		if beamTemplate then
			tutorialState.playerAnchor = beamTemplate:Clone()
			tutorialState.playerAnchor.Name = player.Name .. "Anchor"
			tutorialState.playerAnchor.Parent = game.Workspace:WaitForChild("Misc"):WaitForChild("PlayerAnchors")

			tutorialState.connections.anchorUpdate = Context.connections:connect(RunService.RenderStepped, function()
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					tutorialState.playerAnchor.Position = player.Character.HumanoidRootPart.Position
				end
			end)

			tutorialState.anchorAttachment = tutorialState.playerAnchor:FindFirstChild("AnchorAttachment")
		end
	end

	function Context.setupBeam()
		if tutorialState.beamInstance then
			return
		end

		local beamTemplate = script.Parent:FindFirstChild("BeamTemplate")
		if beamTemplate then
			tutorialState.beamInstance = beamTemplate:Clone()
			tutorialState.beamInstance.Attachment1 = tutorialState.anchorAttachment
			tutorialState.beamInstance.Parent = tutorialState.playerAnchor
		end
	end

	function Context.updateBeamTarget(targetPart)
		if not targetPart or not tutorialState.beamInstance then
			return
		end
		local targetAttachment = targetPart:FindFirstChild("Attachment")
		if targetAttachment then
			tutorialState.beamInstance.Attachment0 = targetAttachment
		end
	end

	function Context.cleanupBeam()
		if tutorialState.beamInstance then
			tutorialState.beamInstance:Destroy()
			tutorialState.beamInstance = nil
		end
		if tutorialState.playerAnchor then
			tutorialState.playerAnchor:Destroy()
			tutorialState.playerAnchor = nil
		end
		if tutorialState.connections.anchorUpdate then
			tutorialState.connections.anchorUpdate:Disconnect()
			tutorialState.connections.anchorUpdate = nil
		end
	end

	-- Unified camera orbit function
end
