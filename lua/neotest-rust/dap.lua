local M = {}

local function get_test_binary(test_directory)

    local cmd = "cargo test --no-run --message-format=JSON"
    local handle = assert(io.popen(cmd))

	local sep = require("plenary.path").path.sep
	local filter = '"src_path":".+' .. sep .. test_directory .. sep .. '.+.rs",'

    local line = handle:read("l")
    while line do

        if string.find(line, filter) and
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

M.resolve_strategy = function(position, cwd, integration_test)

    local test_filter

    for s in string.gmatch(position.id, "([^::]+)") do
        test_filter = s
    end

	local test_directory = 'src'
	if integration_test then
		test_directory = 'tests'
	end

    local command = {
        get_test_binary(test_directory),
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

local function get_results_file(junit_path)

    local match_str = "(.-)[^\\/]-%.?(%d+)%.?[^\\/]*$"
    local tmp_dir, idx = string.match(junit_path, match_str)

    local tmp_file = tonumber(idx) + 1

    return tmp_dir .. tmp_file
end

M.translate_results = function(junit_path)

	local result_map = {
		ok = "passed",
		FAILED = "failed",
		ignored ="skipped",
	}

	local results = {}
    local results_file = get_results_file(junit_path)

    local handle = assert(io.open(results_file))
    local line = handle:read("l")

    while line do

		if string.find(line, '^test result:') then
			--
		elseif string.find(line, '^test .+ %.%.%. %w+') then

			local test_name, cargo_result =
				string.match(line, '^test (.+) %.%.%. (%w+)')

			-- TODO: Short for failures
			results[test_name] = { status = assert(result_map[cargo_result]) }
        end

        line = handle:read("l")
    end

    if handle then
        handle:close()
    end

	return results
end

return M
