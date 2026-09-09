local Config = require(script.Parent.Config)
local Animations = {}
local warned = {}
function Animations.start(record)
	local humanoid = record.humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local ids = Config.AnimationIds[if humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15"]
	record.tracks = {}
	for _, name in { "Idle", "Walk" } do
		local animation = Instance.new("Animation")
		animation.AnimationId = ids[name]
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		animation:Destroy()
		if ok and track then
			track.Looped = true
			track.Priority = if name == "Walk" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Idle
			record.tracks[name] = track
		elseif not warned[ids[name]] then
			warned[ids[name]] = true
			warn("[Civilian] Could not load animation", ids[name], track)
		end
	end
	Animations.moving(record, false)
end
function Animations.moving(record, moving)
	if record.moving == moving then
		return
	end
	record.moving = moving
	local tracks = record.tracks or {}
	local play = if moving then tracks.Walk else tracks.Idle
	local stop = if moving then tracks.Idle else tracks.Walk
	if stop then
		stop:Stop(0.18)
	end
	if play then
		play:Play(0.18, 1, 1)
	end
end
function Animations.destroy(record)
	for _, track in record.tracks or {} do
		track:Stop(0)
		track:Destroy()
	end
	record.tracks = nil
end
return Animations
