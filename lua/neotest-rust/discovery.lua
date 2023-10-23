local lib = require("neotest.lib")

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
        if data.is_parameterized then
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

return M
