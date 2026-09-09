local Codes = {}
function Codes.bind(root, scope, event, soundService)
	local status = root:FindFirstChild("CodeStatus", true)
	local submit = root:FindFirstChild("CodeSubmit", true)
	local textbox = root:FindFirstChild("TextBox", true)
	if not status or not submit or not textbox then
		warn("[Settings] Missing CodeStatus/CodeSubmit/TextBox")
		return
	end
	local originalText, originalColor = status.Text, status.TextColor3
	local pending, generation = false, 0
	local function show(text, success)
		generation += 1
		local token = generation
		status.Text = text
		status.TextColor3 = if success then Color3.fromRGB(92, 255, 67) else Color3.fromRGB(255, 64, 64)
		scope:delay(2, function()
			if token == generation then
				status.Text = originalText
				status.TextColor3 = originalColor
			end
		end)
	end
	local function request()
		if pending then
			return
		end
		local code = textbox.Text:gsub("%s+", "")
		if code == "" then
			show("Please enter a code!", false)
			local sfx = soundService:FindFirstChild("SFX")
			local sound = sfx and sfx:FindFirstChild("Error")
			if sound then
				sound:Play()
			end
			return
		end
		generation += 1
		local token = generation
		pending = true
		event:FireServer(code)
		scope:delay(12, function()
			if pending and token == generation then
				pending = false
				show("No response. Please try again.", false)
			end
		end)
	end
	scope:connect(submit.Activated, request)
	scope:connect(textbox.FocusLost, function(enterPressed)
		if enterPressed then
			request()
		end
	end)
	scope:connect(event.OnClientEvent, function(success, message)
		pending = false
		local text = tostring(message or (if success then "Successfully redeemed!" else "Invalid code!"))
		if success then
			textbox.Text = ""
		elseif text:lower():find("already", 1, true) then
			text = "Already redeemed!"
		elseif text:lower():find("invalid", 1, true) then
			text = "Invalid code!"
		end
		show(text, success == true)
		-- NotificationController owns server-feedback sounds and the common feed.
	end)
end
return Codes
