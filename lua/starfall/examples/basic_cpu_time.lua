--@name Basic CPU Time Limits
--@author Vurv
--@server

-- If you go over the cpu limit, your chip will error.
-- To avoid that, you are given cpu functions to check your usage.

-- cpuUsed() returns the current cpu time used for the chip.
-- cpuTotalUsed() returnns the cpu time used for ALL of your chips

-- cpuAverage() returns the average cpu time used for the chip.
-- cpuTotalAverage() returns the average cpu time used for ALL of your chips.

-- cpuMax() returns the maximum cpu time allowed for ALL of your chips COMBINED.
-- So you likely want to use the cpuTotal* functions for quota limiting.

-- This function allows passing a ratio of the cpu limit.
-- You don't want to just check cpuMax since doing this check uses cpu in the first place..
local function isWithinCPURatio(n)
	return cpuTotalAverage() < cpuMax() * n
end

hook.add("think", "", function()
	local i = 0
	while isWithinCPURatio(0.95) do
		-- This will run until the cpu usage is over 95% of the cpu limit.
		i = i + 1
	end

	-- Then print the final counter, this is how many times the while loop executed this think
	print(i)
end)
