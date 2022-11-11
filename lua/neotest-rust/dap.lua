local M = {}

local function uuid()

	math.randomseed(os.time())
	local random = math.random

	local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

	return string.gsub(template, '[xy]', function (c)
		local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
		return string.format('%x', v)
	end)
end

local function get_test_binary()

	local cmd = "cargo test --no-run --message-format=JSON"
	local handle = assert(io.popen(cmd))

	local line = handle:read("l")
	while line do

		if string.find(line, '"src_path":".+/src/lib.rs",') and
			not string.find(line, '"executable":null')
		then
			local i, j = string.find(line, '"executable":".+",')
			local executable = string.sub(line, i+14, j-2)

			if handle then
				handle:close()
			end

			return executable
		end
		line = handle:read("l")
	end

	if handle then
		handle:close()
	end

	return nil
end

M.resolve_strategy = function(position_id, cwd)

	local test_filter

	for s in string.gmatch(position_id, "([^::]+)") do
		test_filter = s
	end

	local command = {
		get_test_binary(),
		"--nocapture",
		"--test",
		test_filter,
	}

	local strategy = {
		name = "Debug Rust Tests",
		type = "lldb",
		request = "launch",
		program = command[1],
		cwd = cwd or "${workspaceFolder}",
		stopOnEntry = false,
		args = { unpack(command, 2) },
	}

	test_filter = "--nocapture --test " .. test_filter

	return strategy, command, test_filter
end

M.test_file = function(file)

	local f = io.open(file, 'r')

	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

local function parse_results(results_file)

	local tests = 0
	local failures = 0
	-- Rust test binaries do not differentiate between errors and failures
	local errors = 0
	local disabled = 0
	local time = "0.00"

	local handle = assert(io.open(results_file))
	local line = handle:read("l")

	while line do

		if string.find(line, '^running %d+ test') then

			tests = string.match(line, "^running (%d+) test") or 0

		elseif string.find(line, '^test result: ') then

			local ignored, filtered

			failures = string.match(line, '(%d+) failed;') or 0
			ignored  = string.match(line, '(%d+) ignored;') or 0
			filtered = string.match(line, '(%d+) filtered out;') or 0

			time = string.match(line, 'finished in (%d+%.%d+)s') or "0.00"

			disabled = ignored + filtered
		end

		line = handle:read("l")
	end

	if handle then
		handle:close()
	end

	return tests, failures, errors, disabled, time
end

M.translate_results = function(junit_path, position_id)

	-- TODO: Better file finding
	local match_str = "(.-)[^\\/]-%.?[^%.\\/]*$"
	local result_file = string.match(junit_path, match_str) .. '2'

	local tests, failures, errors, disabled, time = parse_results(result_file)

	local timestamp = os.date("%Y-%m-%dT%X") .. ".000+00:00"

	-- TODO
	local testsuite_name = "mud"
	local testcase_name = position_id or "UNKNOWN"
	local classname = "mud"

	local out_data = '<?xml version="1.0" encoding="UTF-8"?>' ..
		'<testsuites name="neotest-rust-dap" tests="' .. tests ..
			'" failures="' .. failures .. '" errors="' .. errors ..
			'" uuid="' .. uuid() .. '" timestamp="' .. timestamp ..
			'" time="' .. time .. '">' ..
		'<testsuite name="' .. testsuite_name .. '" tests="' .. tests ..
			'" disabled="' .. disabled .. '" errors="' .. errors ..
			'" failures="' .. failures .. '">' ..
		'<testcase name="' .. testcase_name ..
			'" classname="' .. classname ..
			'" timestamp="' .. timestamp ..
			'" time="' .. time .. '">' ..
		'</testcase></testsuite></testsuites>'

	return out_data
end

return M
