-- Original centered popup sizing. No screen fades, stagger, slide or UIScale effects.
local TweenService = game:GetService("TweenService")
local Transitions = {}
local active = setmetatable({}, { __mode = "k" })
function Transitions.cancel(root)
	local current = active[root]
	if not current then
		return
	end
	active[root] = nil
	current.tween:Cancel()
	current.connection:Disconnect()
end
function Transitions.panel(root, visible)
	if not root then
		return
	end
	Transitions.cancel(root)
	root.Position = UDim2.fromScale(0.5, 0.5)
	if visible and not root.Visible then
		root.Size = UDim2.fromScale(0, 0)
	end
	root.Visible = true
	local tween = TweenService:Create(
		root,
		TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(if visible then 1 else 0, if visible then 1 else 0) }
	)
	local record = { tween = tween }
	active[root] = record
	record.connection = tween.Completed:Connect(function()
		if active[root] ~= record then
			return
		end
		active[root] = nil
		record.connection:Disconnect()
		root.Visible = visible
	end)
	tween:Play()
end
function Transitions.immediate(root, visible)
	if not root then
		return
	end
	Transitions.cancel(root)
	root.Visible = visible
end
function Transitions.cancelTree(root)
	for node in active do
		if node == root or node:IsDescendantOf(root) then
			Transitions.cancel(node)
		end
	end
end
return Transitions
