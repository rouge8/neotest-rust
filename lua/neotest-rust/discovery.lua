local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Path = require("plenary.path")

local M = {}

--- Build a query to find parameterized tests given the name of a function
--- @param test string name of the test function, i.e. `foo` for  `#[test_case(...)] fn foo(...) {}`
--- @return string
local function build_query(test)
    return [[
;; Matches `#[test_case(... ; "<test.name>")]*fn <parent>()`   (test_case)
;; ...  or `#[case(...)]*fn <parent>()`                        (rstest)
(
  (attribute_item 
    (attribute (identifier) @macro (#any-of? @macro "test_case" "case")
    arguments: (token_tree ((_) (string_literal)? @test.name . ))
  )) @test.definition
  .
  [
    (line_comment)
    (attribute_item)
  ]*
  .
  (function_item name: (identifier) @parent) (#eq? @parent "]] .. test .. [[")
)
]]
end

-- See https://github.com/frondeus/test-case/blob/master/crates/test-case-core/src/utils.rs#L4
local function escape_testcase_name(name)
    name = name:gsub('"', "") -- remove any surrounding dquotes from string literal
    if name == nil or name == "" then
        return "_empty"
    end
    name = string.lower(name) -- make all letters lowercase
    local ident = {}
    local last_under = false
    for c in name:gmatch(".") do
        if c:match("%w") then
            -- alphanumeric character
            last_under = false
            table.insert(ident, c)
        elseif not last_under then
            -- non alphanumeric char not yet prefixed with underscore
            last_under = true
            table.insert(ident, "_")
        end
    end
    if ident[1] ~= "_" and not ident[1]:match("%a") then
        table.insert(ident, 1, "_")
    end
    name = table.concat(ident, "")
    return name
end

--- Discover paramterized tests with treesitter
---
--- @param path string path to test file
--- @param positions neotest.Tree of already parsed namespaces and tests (without parameterized tests)
--- @return neotest.Tree `positions` with additional leafs for parameterized tests
function M.treesitter(path, positions)
    local content = lib.files.read(path, positions)
    local root, lang = lib.treesitter.get_parse_root(path, content, { fast = true })
    for _, value in positions:iter_nodes() do
        local data = value:data()
        local query = build_query(data.name)
        if data.parameterization ~= nil then
            local q = lib.treesitter.normalise_query(lang, query)
            local case_index = 1
            for _, match in q:iter_matches(root, content) do
                local captured_nodes = {}
                for i, capture in ipairs(q.captures) do
                    captured_nodes[capture] = match[i]
                end
                if captured_nodes["test.definition"] then
                    local id = "case_" .. tostring(case_index)
                    local name = id
                    case_index = case_index + 1

                    if captured_nodes["test.name"] ~= nil then
                        name = vim.treesitter.get_node_text(captured_nodes["test.name"], content)
                        name = name:gsub('"', "") -- remove any surrounding dquotes from string literal
                        id = escape_testcase_name(name)
                    end
                    local definition = captured_nodes["test.definition"]

                    local new_data = {
                        type = "test",
                        id = data.id .. "::" .. id,
                        name = name,
                        range = { definition:range() },
                        path = path,
                    }
                    local new_pos = value:new(new_data, {}, value._key, {}, {})
                    value:add_child(new_data.id, new_pos)
                end
            end
        end
    end
    return positions
end

--- Given a certain path to a rust file, guess its [test binary name](https://nexte.st/book/running.html)
--
--- unit tests:   <package>/src/<path>  -> <package>
--- integration:  <package>/tests/<mod>.rs  -> <package>::<mod>
--- binary:       <package>/src/bin/<bin>.rs -> <package>::bin/<bin>
--- example:      <package>/examples/<bin>.rs -> <package>::example/<bin>
--- @param path string
--- @return string|nil
local function binary_name(path)
    local workspace = lib.files.match_root_pattern("Cargo.toml")(path)
    local parts = Path:new(workspace):_split()
    if parts == nil or #parts == 0 then
        return nil
    end
    local package = parts[#parts]
    path = Path:new(path):make_relative(workspace):gsub(".rs$", "")
    if path:match("^src" .. Path.path.sep .. "bin") then
        -- tests in binary
        return package .. "::" .. path:gsub("^src" .. Path.path.sep)
    end
    if path:match("^tests") then
        -- integration test
        return package .. "::" .. path:gsub("^tests" .. Path.path.sep, "")
    end
    if path:match("^examples") then
        -- tests in example
        return package .. "::example" .. path:gsub("^examples", "")
    end
    if path:match("^src") then
        -- unit test
        return package
    end
    logger.warn("Cannot guess unit, binary, integration or example test target of " .. path)
    return nil
end

--- Heueristically guess a file name from a cargo test identifier, depending if such a file
--- exists within a given `workspace`
---
--- Examples (assuming such a file exists beneath `workspace`):
--- * `foo` -> `foo`
--- * `foo_bar` -> `foo/bar`
--- * `foo_bar_baz` -> `foo/bar/baz`
--- * `foo_bar_baz` -> `foo/bar/baz`
--- * `foo_bar_rs` -> `foo/bar.rs`
--- * `foo_bar_rs` -> `foo_bar.rs`
--- * `foo_bar_rs` -> `foo_bar_rs`
---
--- @param id string the cargo test identifier where `/`, `.` and `_` got replaced by underscore. Assumed the original path was relative
--- @param workspace Path the folder on which to look for files/folders for each part between underscores in `id`.
--- @return Path|nil The _relative_ path to `id` (relative to `workspace`) if it exists, otherwise `nil`
local function guess_file_path(id, workspace)
    -- #[files] will always be relative
    local path = nil
    local stem = nil

    for _, part in pairs(vim.split(id:gsub("_UP", ".."), "_")) do
        local cwd = path or workspace
        local candidate = cwd:joinpath(part)
        if candidate:exists() then
            path = candidate
            goto continue
        end
        if not stem then
            stem = part
            goto continue
        end

        candidate = cwd:joinpath(stem .. "." .. part)
        if candidate:exists() then
            path = candidate
            stem = nil
            goto continue
        end

        stem = stem .. "_" .. part
        candidate = cwd:joinpath(stem)
        if candidate:exists() then
            path = candidate
            stem = nil
            goto continue
        end

        ::continue::
    end
    if not path or not path:exists() then
        return nil
    end
    return path:make_relative(tostring(workspace))
end

--- Prettify test case IDs into a more human readable format.
---
--- This is a heureristic process only and does not cover all edge cases. Users are free
--- to use a custom implementation here by overwriting `resolve_case_name` in the adapter.
---
--- @param id string the test case identifier returned by `cargo nextest list`
--- @param macro string the (first) macro name which makes this test parameterized (e.g. `values`, `files`, `test_case`, ...)
--- @param file Path the path to the file under test
--- @return string any string which should be shown in the neotest summary panel for this case, or `nil` to not show this case
M.resolve_case_name = function(id, macro, file)
    if macro == "values" then
        -- Turn `foo_3___blub__::bar_10_3` -> `foo[blub] bar[3]`
        return table.concat(
            vim.tbl_map(function(x)
                local _, _, key, value = x:find("([%w_]+)_%d+_(.*)")
                return key .. "[" .. value:gsub("__", '"') .. "]"
            end, vim.split(id, "::")),
            " "
        )
    end
    if macro == "files" then
        -- Turn `file_1_src_bin_main_rs` -> `file[src/bin/main.rs]`
        local workspace = Path:new(lib.files.match_root_pattern("Cargo.toml")(tostring(file)))
        return table.concat(
            vim.tbl_map(function(x)
                local _, _, key, path = x:find("([%w_]+)_%d+_(.*)")
                path = guess_file_path(path, workspace)
                if not path then
                    return x
                end
                return key .. "[" .. path .. "]"
            end, vim.split(id, "::")),
            " "
        )
    end
    if macro == "<injected>" or "from" then
        -- Strip namespaces from test name `test::foo::bar` -> `bar`
        local parts = vim.split(id, "::")
        return parts[#parts]
    end

    return id
end

--- Discover paramterized tests with `cargo nextest list`
---
--- @param path string path to test file
--- @param positions neotest.Tree of already parsed namespaces and tests (without parameterized tests)
--- @param name_mapper (fun(string, string, Path): string|nil)|nil a custom mapping function to map test ids, macro names and file path to humand readable case names. See `resolve_case_name` for an example
--- @return neotest.Tree `positions` with additional leafs for parameterized tests
function M.cargo(path, positions, name_mapper)
    name_mapper = name_mapper or M.resolve_case_name
    local command = "cargo nextest list --message-format json"

    local result = { lib.process.run(vim.split(command, "%s+"), { stdout = true, stderr = true }) }
    local code = result[1]
    local output = result[2]
    if code ~= 0 then
        logger.error("Cargo failed with exit code " .. tostring(code) .. ": " .. output.stderr)
        return positions
    end
    local json = vim.json.decode(output.stdout)

    local tests = {}
    for key, value in pairs(json["rust-suites"]) do
        tests[key] = {}
        for case, _ in pairs(value["testcases"]) do
            table.insert(tests[key], case)
        end
    end
    local target = binary_name(path)
    if target == nil then
        return positions
    end

    for _, value in positions:iter_nodes() do
        local data = value:data()
        if data.type == "test" and data.parameterization ~= nil then
            for _, case in pairs(tests[target]) do
                if case:match("^" .. data.id) then
                    -- `case` is a parameterized version of `value`, so add it as child
                    local name = name_mapper(case:gsub("^" .. data.id .. "::", ""), data.parameterization, path)
                    if name ~= nil then
                        value:add_child(
                            case,
                            value:new({
                                type = "test",
                                id = case,
                                name = name,
                                range = data.range,
                                path = path,
                            }, {}, value._key, {}, {})
                        )
                    end
                end
            end
        end
    end

    return positions
end

return M
