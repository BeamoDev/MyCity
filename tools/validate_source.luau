-- Compile source without executing gameplay, maintenance scripts, or DataStore calls.
-- Run from the project root: lune run tools/validate_source.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local count = 0
local failures = {}
local function visit(directory)
	local names = fs.readDir(directory)
	table.sort(names)
	for _, name in names do
		local path = directory .. "/" .. name
		if fs.isDir(path) then
			visit(path)
		elseif name:match("%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				table.insert(failures, path .. ": " .. tostring(err))
			end
		end
	end
end

visit("src")
local sourceCount = count
visit("tools")
for _, failure in failures do
	warn(failure)
end
assert(#failures == 0, string.format("%d/%d files failed compilation", #failures, count))
print(
	string.format(
		"PASS: compiled all %d Luau source files and %d tooling files (no game code executed)",
		sourceCount,
		count - sourceCount
	)
)
