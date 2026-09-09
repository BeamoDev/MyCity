-- Short, retargetable visual tweens. Placement always uses the exact grid target.
return function(Context)
	local state = Context.state
	local MOVE_DURATION = 0.16
	local ROTATE_DURATION = 0.18
	function Context.getTargetCFrame()
		if not state.targetPosition then
			return nil
		end
		return CFrame.new(state.targetPosition) * CFrame.Angles(0, math.rad(state.rotationAngle), 0)
	end
	function Context.smoothMoveToTarget(dt)
		if not state.targetPosition or not state.previewBuilding then
			return
		end
		local base = state.previewBuilding:FindFirstChild("Base") or state.previewBuilding:FindFirstChild("Hitbox")
		if not base then
			return
		end
		local motion = state.motion
		if not motion then
			motion = { position = base.Position, angle = 0, targetAngle = 0 }
			state.motion = motion
		end
		local angle = state.motionTargetAngle or state.rotationAngle
		if motion.targetPosition ~= state.targetPosition then
			motion.fromPosition = motion.position
			motion.targetPosition = state.targetPosition
			motion.moveTime = 0
		end
		if motion.targetAngle ~= angle then
			motion.fromAngle = motion.angle
			motion.targetAngle = angle
			motion.rotateTime = 0
		end
		motion.moveTime = math.min(MOVE_DURATION, (motion.moveTime or 0) + dt)
		motion.rotateTime = math.min(ROTATE_DURATION, (motion.rotateTime or 0) + dt)
		local moveAlpha = math.sin(motion.moveTime / MOVE_DURATION * math.pi / 2)
		local rotateAlpha = math.sin(motion.rotateTime / ROTATE_DURATION * math.pi / 2)
		motion.position = motion.fromPosition:Lerp(motion.targetPosition, moveAlpha)
		motion.angle = (motion.fromAngle or 0) + (motion.targetAngle - (motion.fromAngle or 0)) * rotateAlpha
		local visual = CFrame.new(motion.position) * CFrame.Angles(0, math.rad(motion.angle), 0)
		if motion.lastCFrame ~= visual then
			state.previewBuilding:SetPrimaryPartCFrame(visual)
			motion.lastCFrame = visual
		end
		Context.updateBuildingVisuals()
	end
end
