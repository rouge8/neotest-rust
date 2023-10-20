local async = require("neotest.async")
local context_manager = require("plenary.context_manager")
local dap = require("neotest-rust.dap")
local util = require("neotest-rust.util")
local errors = require("neotest-rust.errors")
local Job = require("plenary.job")
local open = context_manager.open
local Path = require("plenary.path")
local lib = require("neotest.lib")
local with = context_manager.with
local xml = require("neotest.lib.xml")

local adapter = { name = "neotest-rust" }

local cargo_metadata = setmetatable({}, {
    __call = function(self, cwd)
        local metadata = self[cwd]
        if metadata ~= nil then
            return metadata
        else
            Job:new({
                command = "cargo",
                args = { "metadata", "--no-deps" },
                cwd = cwd,
                on_exit = function(j, return_val)
                    metadata = vim.json.decode(j:result()[1])
                end,
            }):sync()
            self[cwd] = metadata
            return metadata
        end
    end,
})

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function adapter.root(dir)
    local cwd = lib.files.match_root_pattern("Cargo.toml")(dir)

    if cwd == nil then
        return
    end

    return cargo_metadata(cwd).workspace_root
end

local package_name_by_root = function(package_root)
    local manifest_path = package_root .. "Cargo.toml"
    local metadata = cargo_metadata(package_root)

    return vim.tbl_filter(function(p)
        return p.manifest_path == manifest_path
    end, metadata.packages)[1].name
end

local get_args = function()
    return {}
end

local get_dap_adapter = function()
    return "codelldb"
end

local is_callable = function(obj)
    return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

---@async
---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
    return vim.endswith(file_path, ".rs") and #adapter.discover_positions(file_path):to_list() ~= 1
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function adapter.filter_dir(name, rel_path, root)
    return root .. Path.path.sep .. rel_path ~= cargo_metadata(root).target_directory
end

local get_package_root = lib.files.match_root_pattern("Cargo.toml")

local function is_unit_test(path)
    return vim.startswith(path, get_package_root(path) .. Path.path.sep .. "src" .. Path.path.sep)
end

local function is_integration_test(path)
    return vim.startswith(path, get_package_root(path) .. Path.path.sep .. "tests" .. Path.path.sep)
end

local function is_alternate_binary(path)
    return vim.startswith(
        path,
        get_package_root(path) .. Path.path.sep .. "src" .. Path.path.sep .. "bin" .. Path.path.sep
    )
end

local function path_to_test_path(path)
    local root = get_package_root(path)
    -- main.rs, lib.rs, and mod.rs aren't part of the test name
    for _, filename in ipairs({ "main", "lib", "mod" }) do
        path = path:gsub(filename .. ".rs$", "")
    end

    -- Trim '.rs'
    path = path:gsub(".rs$", "")

    if is_unit_test(path) then
        if is_alternate_binary(path) then
            return nil
        end
        path = Path:new(path)
        path = path:make_relative(root .. Path.path.sep .. "src")
    else
        path = Path:new(path)
        path = path:make_relative(root .. Path.path.sep .. "tests")
        -- Remove the first component of the path of an integration test in a
        -- subdirectory, e.g. 'testsuite/foo/bar.rs' becomes 'foo/bar.rs'
        if path:find(Path.path.sep) then
            path = path:gsub("^.+" .. Path.path.sep, "")
        else
            return nil
        end
    end

    -- Replace separators with '::'
    path = path:gsub(Path.path.sep, "::")

    -- If the file was main.rs, lib.rs, or mod.rs, the relative path will
    -- be "." after we strip the filename.
    if path == "." then
        return nil
    else
        return path
    end
end

local function integration_test_name(path)
    local package_root = get_package_root(path)

    path = Path:new(path)
    path = path:make_relative(package_root .. Path.path.sep .. "tests")
    path = path:gsub(".rs$", "")
    return vim.split(path, "/")[1]
end

local function binary_name(path)
    local package_root = get_package_root(path)

    path = Path:new(path)
    path = path:make_relative(package_root .. Path.path.sep .. "src" .. Path.path.sep .. "bin")
    path = path:gsub(".rs$", "")
    return vim.split(path, "/")[1]
end

local function get_match_type(captured_nodes)
    if captured_nodes["test.name"] then
        return "test"
    end
    if captured_nodes["namespace.name"] then
        return "namespace"
    end
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

-- Enrich `it.each` tests with metadata about TS node position
---Given a file path, parse all the tests within it.
---@async
---@param path string Absolute file path
---@return neotest.Tree | nil
function adapter.discover_positions(path)
    local query = [[;; query

;; Matches mod <namespace.name> {}
((mod_item name: (identifier) @namespace.name) @namespace.definition)

;; Matches `#[test]`
(
  (attribute_item 
    (attribute (identifier) @macro
      (#eq? @macro "test")
    )
  )
  (function_item name: (identifier) @test.name) @test.definition
) 

;; Matches `#[test_case(...)] fn <test.name>()`
(
  (attribute_item
    (attribute (identifier) @macro) (#eq? @macro "test_case")
  ) @parameterized
  .
  (line_comment)*
  .
  (function_item name: (identifier) @test.name) @test.definition
)

;; Matches `#[test_case(...)] #[{tokio,async_std}::test] async fn <test.name>()`
(
  (attribute_item
    (attribute (identifier) @macro) (#eq? @macro "test_case")
  ) @parameterized
  .
  (line_comment)*
  .
  (attribute_item
    (attribute
      (scoped_identifier
        path: (identifier) @package
        name: (identifier)
      )
    )
    ;; all packages which provide a #[<package>::test] macro
    (#any-of? @package "tokio" "async_std")
  )
  .
  (line_comment)*
  .
  (function_item
    (function_modifiers) @modifier
    name: (identifier) @test.name
  ) @test.definition
  (#eq? @modifier "async")
)

;; Matches `#[rstest] fn <test.name>(#[case] ...)`
(
  (attribute_item (attribute (identifier) @macro) (#eq? @macro "rstest"))
  .
  [
    (line_comment)
    (attribute_item)
  ]*
  .
  (function_item 
    name: (identifier) @test.name
    parameters: (parameters (attribute_item (attribute (identifier) @parameterized)))
    (#eq? @parameterized "case")
  ) @test.definition
)
    ]]
    local positions = lib.treesitter.parse_positions(path, query, {
        require_namespaces = true,
        nested_tests = true,
        build_position = function(file_path, source, captured_nodes)
            local match_type = get_match_type(captured_nodes)
            if not match_type then
                return
            end

            local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
            local definition = captured_nodes[match_type .. ".definition"]
            local range = { definition:range() }
            local is_parameterized = captured_nodes["parameterized"] and true or false

            return {
                type = match_type,
                path = file_path,
                name = name,
                range = range,
                is_parameterized = is_parameterized,
            }
        end,
        position_id = function(position, namespaces)
            local id = table.concat(
                vim.tbl_flatten({
                    path_to_test_path(path),
                    vim.tbl_map(function(pos)
                        return pos.name
                    end, namespaces),
                    position.name,
                }),
                "::"
            )
            return id
        end,
    })
    local content = lib.files.read(path)
    local root, lang = lib.treesitter.get_parse_root(path, content, { fast = true })
    for _, value in positions:iter_nodes() do
        local data = value:data()
        if data.is_parameterized then
            local query = [[
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
  (function_item name: (identifier) @parent) (#eq? @parent "]] .. data.name .. [[")
)
]]
            local q = lib.treesitter.normalise_query(lang, query)
            local case_index = 1
            for _, match in q:iter_matches(root, content) do
                local captured_nodes = {}
                for i, capture in ipairs(q.captures) do
                    captured_nodes[capture] = match[i]
                end
                if captured_nodes["test.definition"] then
                    local name = "case_" .. tostring(case_index)
                    case_index = case_index + 1
                    if captured_nodes["test.name"] ~= nil then
                        name = vim.treesitter.get_node_text(captured_nodes["test.name"], content)
                        name = escape_testcase_name(name)
                    end
                    local definition = captured_nodes["test.definition"]

                    local new_data = {
                        type = "test",
                        id = data.id .. "::" .. name,
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

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
    local tmp_nextest_config = async.fn.tempname() .. ".nextest.toml"
    local junit_path = async.fn.tempname() .. ".junit.xml"
    local position = args.tree:data()
    local cwd = adapter.root(position.path)

    local nextest_config = Path:new(cwd .. ".config/nextest.toml")
    if nextest_config:exists() then
        nextest_config:copy({ destination = tmp_nextest_config })
    end

    with(open(tmp_nextest_config, "a"), function(writer)
        writer:write("[profile.neotest.junit]\npath = '" .. junit_path .. "'")
    end)

    local command = vim.tbl_flatten({
        "cargo",
        "nextest",
        "run",
        "--workspace",
        "--no-fail-fast",
        "--config-file",
        tmp_nextest_config,
        "--profile",
        "neotest",
        vim.list_extend(get_args(), args.extra_args or {}),
    })

    if is_integration_test(position.path) then
        vim.list_extend(command, { "--test", integration_test_name(position.path) })
    end

    if is_alternate_binary(position.path) then
        vim.list_extend(command, { "--bin", binary_name(position.path) })
    end

    -- Determine the package name if we're in a workspace
    local workspace_root = adapter.root(position.path) .. Path.path.sep
    local package_root = lib.files.match_root_pattern("Cargo.toml")(position.path)
    local belongs_to_workspace = (package_root:sub(0, #workspace_root) == workspace_root)
    local package_name = belongs_to_workspace and package_name_by_root(package_root .. Path.path.sep)

    local package_filter = ""
    if package_name then
        package_filter = "package(" .. package_name .. ") & "
    end

    local position_id
    local test_filter
    if position.type == "test" then
        position_id = position.id
        -- TODO: Support rstest parametrized tests
        test_filter = "-E " .. vim.fn.shellescape(package_filter .. "test(/^" .. position_id .. "/)")
    elseif position.type == "file" then
        if package_name then
            -- A basic filter to run tests within the package that will be
            -- overridden later if 'position_id' is not nil
            test_filter = "-E " .. vim.fn.shellescape("package(" .. package_name .. ")")
        end

        position_id = path_to_test_path(position.path)

        if is_unit_test(position.path) and position_id == nil then
            -- main.rs or lib.rs
            position_id = "tests"
        end

        if position_id then
            -- Either a unit test or an integration test in a subdirectory
            test_filter = "-E " .. vim.fn.shellescape(package_filter .. "test(/^" .. position_id .. "::/)")
        end
    end
    table.insert(command, test_filter)

    local context = {
        junit_path = junit_path,
        file = position.path,
        test_filter = test_filter,
        position_id = position_id,
        strategy = args.strategy,
    }

    -- Debug
    if args.strategy == "dap" then
        local dap_args = { "--nocapture" }

        if position.type == "test" then
            context.test_filter = position.id
            table.insert(dap_args, "--exact")
        else
            position_id = path_to_test_path(position.path)
            if position_id == nil then
                context.test_filter = "tests"
            else
                context.test_filter = position_id
            end
        end

        table.insert(dap_args, context.test_filter)

        local strategy = {
            name = "Debug Rust Tests",
            type = get_dap_adapter(),
            request = "launch",
            cwd = cwd or "${workspaceFolder}",
            stopOnEntry = false,
            args = dap_args,
            program = dap.get_test_binary(cwd, position.path),
        }

        -- codelldb must be provided with a file for stdout in its launch parameters.
        -- https://github.com/vadimcn/codelldb/blob/v1.9.0/MANUAL.md#stdio-redirection
        if get_dap_adapter() == "codelldb" then
            strategy["stdio"] = { nil, async.fn.tempname() }
        end

        return {
            cwd = cwd,
            context = context,
            strategy = strategy,
        }
    end

    -- Run
    return {
        command = table.concat(command, " "),
        cwd = cwd,
        context = context,
    }
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
    ---@type table<string, neotest.Result>
    local results = {}
    local output_path = spec.strategy.stdio and spec.strategy.stdio[2] or result.output

    if util.file_exists(spec.context.junit_path) then
        local data
        with(open(spec.context.junit_path, "r"), function(reader)
            data = reader:read("*a")
        end)

        local root = xml.parse(data)

        if root.testsuites.testsuite == nil then
            lib.notify("Test didn't produce any output")
            return results
        end

        local testsuites
        if root.testsuites.testsuite == nil then
            testsuites = {}
        elseif #root.testsuites.testsuite == 0 then
            testsuites = { root.testsuites.testsuite }
        else
            testsuites = root.testsuites.testsuite
        end
        for _, testsuite in pairs(testsuites) do
            local testcases
            if #testsuite.testcase == 0 then
                testcases = { testsuite.testcase }
            else
                testcases = testsuite.testcase
            end
            for _, testcase in pairs(testcases) do
                if testcase.failure then
                    local output = testcase.failure[1]

                    results[testcase._attr.name] = {
                        status = "failed",
                        short = output,
                        errors = errors.parse_errors(output),
                    }
                else
                    results[testcase._attr.name] = {
                        status = "passed",
                    }
                end
            end
        end
    elseif spec.context.strategy == "dap" and util.file_exists(output_path) then
        results = dap.translate_results(output_path)
    else
        local output = result.output

        results[spec.context.position_id] = {
            status = "failed",
            output = output,
        }
    end

    return results
end

setmetatable(adapter, {
    __call = function(_, opts)
        if is_callable(opts.args) then
            get_args = opts.args
        elseif opts.args then
            get_args = function()
                return opts.args
            end
        end
        if is_callable(opts.dap_adapter) then
            get_dap_adapter = opts.dap_adapter
        elseif opts.dap_adapter then
            get_dap_adapter = function()
                return opts.dap_adapter
            end
        end
        return adapter
    end,
})

return adapter
