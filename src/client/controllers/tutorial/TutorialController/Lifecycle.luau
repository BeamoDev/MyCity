-- Lifecycle: focused implementation for TutorialController.
return function(Context)
	local State = Context.State
	local TutorialController = Context.TutorialController
	local player = Context.player
	local tutorialState = Context.tutorialState

	function Context.cleanupTutorial(animate)
		Context.cancelStagePresentation()
		Context.clearSubtitleTweens()
		if not State.playerGui then
			return
		end
		for name, connection in pairs(tutorialState.connections) do
			if connection then
				connection:Disconnect()
			end
		end
		tutorialState.connections = {}

		Context.cleanupBeam()
		Context.cleanupCameraOrbit()
		Context.cleanupIncomeHover() -- ADD THIS LINE
		Context.clearTileHighlights()

		if State.UIController then
			State.UIController.clearStuckEffects()
		end

		tutorialState.isActive = false
		tutorialState.currentStage = 0
		tutorialState.serverStage = nil

		if State.playerGui and State.playerGui:FindFirstChild("TutorialHandler") then
			State.playerGui.TutorialHandler.Visible = false
		end

		-- Ensure UI is restored when tutorial ends
		State.ButtonFolder.Parent.CashDisplay.Visible = true
		State.ButtonFolder.Parent.FriendBoost.Visible = true
		State.ButtonFolder.Visible = true
		State.FramesFolder.Visible = true
		if animate then
			State.UIController.setGameplayUIVisible(true)
		end
	end

	function TutorialController.init(gui)
		State.playerGui = gui
		State.ButtonFolder = State.playerGui.Buttons
		State.FramesFolder = State.playerGui.Frames
		State.UIController = require(script.Parent.Parent.Parent:WaitForChild("ui"):WaitForChild("UIController"))

		State.TutorialStageOne = State.playerGui.TutorialHandler.StageOne
		State.TutorialStageTwo = State.playerGui.TutorialHandler.StageTwo
		State.TutorialFrame = State.playerGui.TutorialHandler.TutorialFrame

		State.serverTutorial = player:WaitForChild("Data"):WaitForChild("PlayerInfo"):WaitForChild("Tutorial")
		State.serverTutorial:WaitForChild("ServerStage")
		State.serverTutorial:WaitForChild("IsInTutorial")
		Context.connectTutorialEvents()

		-- Clean up any leftover tutorial elements on init
		Context.connections:spawn(function()
			task.wait(2) -- Wait for everything to load
			if not player:WaitForChild("Data").PlayerInfo.Tutorial.IsInTutorial.Value then
				-- Not in tutorial, ensure everything is cleaned
				Context.cleanupBeam()
				Context.cleanupIncomeHover()
				Context.clearTileHighlights()

				-- Ensure anchors folder is cleaned
				local anchorsFolder = game.Workspace:FindFirstChild("Misc")
					and game.Workspace.Misc:FindFirstChild("PlayerAnchors")
				if anchorsFolder then
					local playerAnchor = anchorsFolder:FindFirstChild(player.Name .. "Anchor")
					if playerAnchor then
						playerAnchor:Destroy()
					end
				end
			end
		end)

		if player:WaitForChild("Data").PlayerInfo.Tutorial.IsInTutorial.Value then
			TutorialController.startTutorial()
		end
	end
end
