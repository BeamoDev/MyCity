-- Owns HUD.CashDisplay; the label itself needs no LocalScript.
local CashFeedback = require(script.Parent.Parent.CashFeedback)
return function(Context)
	local State = Context.State
	local player = Context.player
	function Context.cleanupCashDisplay()
		if State.cashUpdateConnection then
			State.cashUpdateConnection:Disconnect()
			State.cashUpdateConnection = nil
		end
		if State.cashFeedback then
			State.cashFeedback:Destroy()
			State.cashFeedback = nil
		end
		State.cashLabel, State.cashSource = nil, nil
	end
	function Context.updateCashDisplay()
		local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
		local label = State.HUD and State.HUD:FindFirstChild("CashDisplay")
		if State.cashLabel == label and State.cashSource == cash then
			return
		end
		Context.cleanupCashDisplay()
		if not label then
			return
		end
		State.cashLabel, State.cashSource = label, cash
		local feedback = CashFeedback.new(label, Context.formatNumber)
		State.cashFeedback = feedback
		feedback:SetTarget(cash.Value)
		State.cashUpdateConnection = Context.connections:connect(cash:GetPropertyChangedSignal("Value"), function()
			feedback:SetTarget(cash.Value)
		end)
	end
end
