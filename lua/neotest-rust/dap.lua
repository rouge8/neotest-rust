local M = {}

local function get_src_paths(root)

    local sep = require("plenary.path").path.sep
	local cmd = "cargo test --no-run --message-format=JSON --manifest-path=" .. root .. sep .. "Cargo.toml"
    local handle = assert(io.popen(cmd))

	local src_paths = {}
    local src_filter = '"src_path":"(.+' .. sep  .. '.+.rs)",'
    local exe_filter = '"executable":"(.+' .. sep  .. 'deps' .. sep .. '.+)",'

    local line = handle:read("l")
    while line do
        if
            string.find(line, src_filter)
            and string.find(line, exe_filter)
        then
            local src_path = string.match(line, src_filter)
			local executable = string.match(line, exe_filter)
			src_paths[src_path] = executable
        end
        line = handle:read("l")
    end

    if handle then
        handle:close()
    end

    return src_paths
end

---- TODO: :help vim.treesitter
--local function check_mods(path)
--    local query = [[
--    ]]
--
--    --local tree = lib.treesitter.parse_positions(path, query, {
--    --    require_namespaces = false,
--    --    position_id = function(position, namespaces)
--    --        return table.concat(
--    --            vim.tbl_flatten({
--    --                path_to_test_path(path),
--    --                vim.tbl_map(function(pos)
--    --                    return pos.name
--    --                end, namespaces),
--    --                position.name,
--    --            }),
--    --            "::"
--    --        )
--    --    end,
--    --})
--end

M.get_test_binary = function(root, path)

	for src_path, executable in pairs(get_src_paths(root)) do
		if path == src_path then
			return executable
		end
	end

	return nil
end

M.file_exists = function(file)
    local f = io.open(file, "r")

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

-- Translate plain test output to a neotest results object
M.translate_results = function(junit_path)
    local result_map = {
        ok = "passed",
        FAILED = "failed",
        ignored = "skipped",
    }

    local results = {}
    local results_file = get_results_file(junit_path)

    local handle = assert(io.open(results_file))
    local line = handle:read("l")

    while line do
        if string.find(line, "^test result:") then
            --
        elseif string.find(line, "^test .+ %.%.%. %w+") then
            local test_name, cargo_result = string.match(line, "^test (.+) %.%.%. (%w+)")

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
