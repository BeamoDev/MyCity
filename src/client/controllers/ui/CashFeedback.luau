-- Cash presentation only. All currency remains server-owned.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Counter = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("util"):WaitForChild("NumberCounter"))
local Feedback = {}
Feedback.__index = Feedback
local OPTIONS =
	{ Integer = true, Minimum = 0, BaseDuration = 0.2, DistanceDivisor = 4000, MinDuration = 0.2, MaxDuration = 0.7 }
local GAIN = Color3.fromRGB(123, 255, 151)
local SPEND = Color3.fromRGB(255, 126, 126)
local POPUP_LIFETIME = 0.84

function Feedback.new(label, format)
	local self = setmetatable(
		{ label = label, format = format, counter = {}, popups = {}, originalColor = label.TextColor3 },
		Feedback
	)
	self.destroyConnection = label.Destroying:Connect(function()
		self:Destroy()
	end)
	return self
end
local function visible(label)
	local current = label
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end
function Feedback:showDelta(delta, now)
	if not visible(self.label) then
		return
	end
	while #self.popups >= 3 do
		table.remove(self.popups, 1).label:Destroy()
	end
	local popup = Instance.new("TextLabel")
	popup.Name = "CashDelta"
	popup.BackgroundTransparency = 1
	popup.AnchorPoint = Vector2.new(0.5, 0)
	popup.Size = UDim2.new(1, 40, 0, 30)
	popup.Position = UDim2.fromScale(0.5, 1)
	popup.FontFace = self.label.FontFace
	popup.TextSize = math.clamp(self.label.TextSize, 18, 26)
	popup.TextColor3 = if delta > 0 then GAIN else SPEND
	popup.TextStrokeColor3 = Color3.fromRGB(20, 30, 24)
	popup.TextStrokeTransparency = 0.2
	popup.Text = (if delta > 0 then "+" else "-") .. self.format(math.abs(delta))
	popup.ZIndex = self.label.ZIndex + 1
	local scale = Instance.new("UIScale")
	scale.Scale = 0.8
	scale.Parent = popup
	popup.Parent = self.label
	table.insert(self.popups, { label = popup, scale = scale, started = now })
end
function Feedback:step(now)
	if self.destroyed then
		return
	end
	local changed, amount, finished = Counter.Step(self.counter, now)
	if changed then
		self.label.Text = self.format(amount)
	end
	local tintFinished = true
	if self.tintStarted then
		local alpha = math.clamp((now - self.tintStarted) / 0.45, 0, 1)
		self.label.TextColor3 = self.tintColor:Lerp(self.originalColor, alpha)
		tintFinished = alpha >= 1
	end
	for index = #self.popups, 1, -1 do
		local popup = self.popups[index]
		local alpha = math.clamp((now - popup.started) / POPUP_LIFETIME, 0, 1)
		if alpha >= 1 or not popup.label.Parent then
			popup.label:Destroy()
			table.remove(self.popups, index)
		else
			popup.label.Position = UDim2.new(0.5, 0, 1, -28 * (1 - (1 - alpha) ^ 2))
			popup.label.TextTransparency = alpha
			popup.label.TextStrokeTransparency = 0.2 + 0.8 * alpha
			popup.scale.Scale = 0.8 + 0.2 * math.min(1, alpha * 4)
		end
	end
	if finished and tintFinished and #self.popups == 0 and self.frameConnection then
		self.frameConnection:Disconnect()
		self.frameConnection = nil
	end
end
function Feedback:SetTarget(value)
	if self.destroyed then
		return
	end
	local now = os.clock()
	local changed, delta, initial = Counter.SetTarget(self.counter, value, OPTIONS, now)
	if not changed then
		return
	end
	if initial then
		self.label.Text = self.format(self.counter.Current)
		return
	end
	self.tintStarted = now
	self.tintColor = if delta > 0 then GAIN else SPEND
	self:showDelta(delta, now)
	if not self.frameConnection then
		self.frameConnection = RunService.RenderStepped:Connect(function()
			self:step(os.clock())
		end)
	end
end
function Feedback:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.frameConnection then
		self.frameConnection:Disconnect()
		self.frameConnection = nil
	end
	if self.destroyConnection then
		self.destroyConnection:Disconnect()
		self.destroyConnection = nil
	end
	for _, popup in self.popups do
		popup.label:Destroy()
	end
	table.clear(self.popups)
	if self.label.Parent then
		self.label.TextColor3 = self.originalColor
	end
end
return Feedback
