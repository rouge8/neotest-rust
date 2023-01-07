local lib = require("neotest.lib")
local sep = require("plenary.path").path.sep

local M = {}

M.file_exists = function(file)
    local f = io.open(file, "r")

    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function get_src_paths(root)
    local cmd = "cargo test --no-run --message-format=JSON --manifest-path=" .. root .. sep .. "Cargo.toml --quiet"
    local handle = assert(io.popen(cmd))

    local src_paths = {}
    local src_filter = '"src_path":"(.+' .. sep .. '.+.rs)",'
    local exe_filter = '"executable":"(.+' .. sep .. "deps" .. sep .. '.+)",'

    local line = handle:read("l")
    while line do
        print(line)
        if string.find(line, src_filter) and string.find(line, exe_filter) then
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

local function collect(query, source, root)
    local mods = {}

    for _, match in query:iter_matches(root, source) do
        local captured_nodes = {}
        for i, capture in ipairs(query.captures) do
            captured_nodes[capture] = match[i]
        end

        if captured_nodes["mod_name"] then
            local mod_name = vim.treesitter.get_node_text(captured_nodes["mod_name"], source)
            table.insert(mods, mod_name)
        end
    end

    return mods
end

local function get_mods(path)
    local content = lib.files.read(path)
    local query = [[
(mod_item
	name: (identifier) @mod_name
	.
)
    ]]

    local root, lang = lib.treesitter.get_parse_root(path, content, {})
    local parsed_query = lib.treesitter.normalise_query(lang, query)

    return collect(parsed_query, content, root)
end

local function construct_mod_path(src_path, mod)
    local match_str = "(.-)[^\\/]-%.?(%w+)%.?[^\\/]*$"
    local abs_path, _ = string.match(src_path, match_str)

    local mod_file = abs_path .. mod .. ".rs"
    local mod_dir = abs_path .. mod .. sep .. "mod.rs"

    if M.file_exists(mod_file) then
        return mod_file
    elseif M.file_exists(mod_dir) then
        return mod_dir
    end
end

local function search_modules(src_path, path)
    local mods = get_mods(src_path)

    if mods == {} then
        return false
    end

    for _, mod in ipairs(mods) do
        local mod_path = construct_mod_path(src_path, mod)
        if path == mod_path then
            return true
        elseif search_modules(mod_path, path) then
            return true
        end
    end

    return false
end

-- Debugging is only possible from the generated test binary
-- See: https://github.com/rust-lang/cargo/issues/1924#issuecomment-289764090
-- Identify the binary containing the tests defined in 'path'
M.get_test_binary = function(root, path)
    local src_paths = get_src_paths(root)

    -- If 'path' is the source of the binary we are done
    for src_path, executable in pairs(src_paths) do
        if path == src_path then
            return executable
        end
    end

    -- Otherwise we need to figure out which 'src_path' it is loaded from
    for src_path, executable in pairs(src_paths) do
        local mod_match = search_modules(src_path, path)
        if mod_match then
            return executable
        end
    end

    return nil
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
