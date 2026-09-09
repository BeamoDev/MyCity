-- Presentation follows durable server state, so missed/late remotes cannot strand it.
return function(Context)
	local State, tutorialState = Context.State, Context.tutorialState
	local TutorialController = Context.TutorialController
	local events = Context.ReplicatedStorage.Events.Tutorial
	local function close(frame)
		if frame then
			State.UIController.closeUIFrame(frame)
		end
	end
	function Context.cancelStagePresentation()
		local thread = tutorialState.stageThread
		tutorialState.stageThread = nil
		if thread and thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then
			task.cancel(thread)
			Context.connections.threads[thread] = nil
		end
	end
	local function showIncomeGuidance()
		tutorialState.currentStage = 4
		close(State.TutorialStageTwo)
		Context.updateTutorialText("Walk on the green cash pile to collect your income!")
		local plot = Context.getPlayerPlot()
		local ui = plot and plot:FindFirstChild("UI")
		local button = ui and ui:FindFirstChild("CollectIncome")
		if not button then
			return
		end
		local hover = button:FindFirstChild("Hover")
		local info = hover and hover:FindFirstChild("HoverInfo")
		if info then
			info.Enabled = true
		end
		Context.createPlayerAnchor()
		Context.setupBeam()
		Context.updateBeamTarget(button:FindFirstChild("Base"))
	end
	function Context.presentServerStage()
		if not tutorialState.isActive then
			return
		end
		if not State.serverTutorial.IsInTutorial.Value then
			if tutorialState.finishing then
				return
			end
			tutorialState.finishing = true
			Context.cancelStagePresentation()
			State.UIController.finishTutorial(function()
				Context.cleanupTutorial(true)
				State.UIController.updateTutorialStatus(false)
				tutorialState.finishing = false
			end)
			return
		end
		local stage = State.serverTutorial.ServerStage.Value
		if tutorialState.serverStage == stage then
			return
		end
		tutorialState.serverStage = stage
		Context.cancelStagePresentation()
		Context.cleanupCameraOrbit()
		Context.cleanupBeam()
		Context.cleanupIncomeHover()
		Context.clearTileHighlights()
		Context.refreshPlacementHighlights()
		close(State.TutorialStageOne)
		close(State.TutorialStageTwo)
		close(State.FramesFolder:FindFirstChild("TutorialItemShop"))
		tutorialState.stageThread = Context.connections:defer(function()
			if stage == 0 then
				tutorialState.currentStage = 0
				Context.updateTutorialText("Welcome! Let's build your city!")
				State.UIController.openUIFrame(State.TutorialStageOne)
			elseif stage == 1 then
				tutorialState.currentStage = 1
				Context.updateTutorialText("Equip your Bank and place it on your plot!")
				events.GiveBank:FireServer()
			elseif stage == 2 then
				tutorialState.currentStage = 2
				Context.updateTutorialText("Wait for your Bank to build!")
				Context.setupOrbitCamera("Bank", true)
			elseif stage == 3 then
				tutorialState.currentStage = 3
				Context.updateTutorialText("Bank complete! Collect your city's taxes.")
				State.UIController.openUIFrame(State.TutorialStageTwo)
			elseif stage == 4 then
				tutorialState.currentStage = 5
				Context.updateTutorialText("You collected your city's taxes!")
				task.wait(2.5)
				Context.updateTutorialText("Let's buy another building!")
				task.wait(2)
				local shop = State.FramesFolder:FindFirstChild("TutorialItemShop")
				if shop then
					State.FramesFolder.Visible = true
					State.UIController.openUIFrame(shop)
					events.ShopOpened:FireServer()
					Context.showcaseShopItems()
				else
					warn("[Tutorial] Missing HUD.Frames.TutorialItemShop")
				end
			elseif stage == 5 then
				tutorialState.currentStage = 7
				Context.updateTutorialText("Place your new Shack!")
			elseif stage == 6 then
				tutorialState.currentStage = 7
				Context.updateTutorialText("Wait for your Shack to build!")
			elseif stage == 7 then
				tutorialState.currentStage = 8
				Context.updateTutorialText("Your Shack is complete!")
				Context.setupOrbitCamera("Shack", false)
				task.wait(7.5)
				Context.cleanupCameraOrbit()
				Context.updateTutorialText("Tutorial complete! Keep growing your city with the quests!")
				task.wait(3)
				-- Keep tutorial active until the server acknowledges completion. Retrying is
				-- safe because finishTutorial only accepts stage 7 while IsInTutorial is true.
				while tutorialState.isActive and State.serverTutorial.IsInTutorial.Value do
					Context.ReplicatedStorage.Events.TutorialFinished:FireServer()
					task.wait(2)
				end
			end
		end)
	end
	function Context.connectTutorialEvents()
		Context.connections:connect(
			Context.player:GetAttributeChangedSignal("MyCityPlacementTool"),
			Context.refreshPlacementHighlights
		)
		tutorialState.connections.toolEquipped = Context.connections:connect(
			events.ToolEquipped.OnClientEvent,
			function()
				Context.refreshPlacementHighlights()
			end
		)
		tutorialState.connections.displayPlace = Context.connections:connect(
			events.DisplayPlace.OnClientEvent,
			function()
				if tutorialState.isActive and tutorialState.currentStage == 1 then
					Context.updateTutorialText("Place the Bank on your plot!")
				end
			end
		)
		Context.connections:connect(
			State.serverTutorial.ServerStage:GetPropertyChangedSignal("Value"),
			Context.presentServerStage
		)
		Context.connections:connect(
			State.serverTutorial.IsInTutorial:GetPropertyChangedSignal("Value"),
			Context.presentServerStage
		)
	end
	function TutorialController.startTutorial()
		if tutorialState.isActive then
			return
		end
		tutorialState.isActive = true
		tutorialState.serverStage = nil
		State.ButtonFolder.Visible = false
		-- TutorialItemShop is inside Frames: its ancestors must remain visible.
		State.FramesFolder.Visible = true
		State.UIController.updateTutorialStatus(true)
		State.playerGui.TutorialHandler.Visible = true
		tutorialState.connections.stageOneButton = Context.connections:connect(
			State.TutorialStageOne.Frame.Start.Activated,
			function()
				if not tutorialState.isActive or tutorialState.currentStage ~= 0 then
					return
				end
				-- Keep Start available if the server is busy; stage 1 closes it.
				Context.updateTutorialText("Getting your Bank ready...")
				events.GiveBank:FireServer()
			end
		)
		tutorialState.connections.stageTwoButton = Context.connections:connect(
			State.TutorialStageTwo.Frame.Start.Activated,
			function()
				if tutorialState.isActive and tutorialState.currentStage == 3 then
					showIncomeGuidance()
				end
			end
		)
		Context.presentServerStage()
	end
end
