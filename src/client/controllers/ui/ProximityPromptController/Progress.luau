-- Progress: focused implementation for Controller.
return function(Context)
	local State = Context.State

	function Context.setUpCircularProgressBar(bar)
		local leftGradient = bar.LeftGradient.ProgressBarImage.UIGradient
		local rightGradient = bar.RightGradient.ProgressBarImage.UIGradient

		local progress = bar.Progress
		progress.Changed:Connect(function(value)
			local angle = math.clamp(value * 360, 0, 360)
			leftGradient.Rotation = math.clamp(angle, 180, 360)
			rightGradient.Rotation = math.clamp(angle, 0, 180)
		end)
	end
end
