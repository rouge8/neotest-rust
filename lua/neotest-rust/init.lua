local async = require("neotest.async")
local context_manager = require("plenary.context_manager")
local dap = require("neotest-rust.dap")
local lib = require("neotest.lib")
local open = context_manager.open
local Path = require("plenary.path")
local with = context_manager.with
local xml = require("neotest.lib.xml")
local xml_tree = require("neotest.lib.xml.tree")

local adapter = { name = "neotest-rust" }

adapter.root = lib.files.match_root_pattern("Cargo.toml")

local get_args = function()
    return {}
end

local is_callable = function(obj)
    return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

function adapter.is_test_file(file_path)
    return vim.endswith(file_path, ".rs")
end

local function is_unit_test(path)
    return vim.startswith(path, adapter.root(path) .. Path.path.sep .. "src" .. Path.path.sep)
end

local function is_integration_test(path)
    return vim.startswith(path, adapter.root(path) .. Path.path.sep .. "tests" .. Path.path.sep)
end

local function path_to_test_path(path)
    local root = adapter.root(path)
    -- main.rs, lib.rs, and mod.rs aren't part of the test name
    for _, filename in ipairs({ "main", "lib", "mod" }) do
        path = path:gsub(filename .. ".rs$", "")
    end

    -- Trim '.rs'
    path = path:gsub(".rs$", "")

    if is_unit_test(path) then
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
    local root = adapter.root(path)

    path = Path:new(path)
    path = path:make_relative(root .. Path.path.sep .. "tests")
    path = path:gsub(".rs$", "")
    return vim.split(path, "/")[1]
end

function adapter.discover_positions(path)
    local query = [[
(
  (attribute_item
    [
      (attribute
        (identifier) @macro_name
      )
      (scoped_identifier
        name: (identifier) @macro_name
          )
        ]
      )
    ]
  )+
  .
  (function_item
    name: (identifier) @test.name
  ) @test.definition
  (#contains? @macro_name "test" "rstest" "case")

)
(mod_item name: (identifier) @namespace.name)? @namespace.definition
    ]]

    return lib.treesitter.parse_positions(path, query, {
        require_namespaces = false,
        position_id = function(position, namespaces)
            return table.concat(
                vim.tbl_flatten({
                    path_to_test_path(path),
                    vim.tbl_map(function(pos)
                        return pos.name
                    end, namespaces),
                    position.name,
                }),
                "::"
            )
        end,
    })
end

function adapter.build_spec(args)
    local tmp_nextest_config = async.fn.tempname() .. ".nextest.toml"
    local junit_path = async.fn.tempname() .. ".junit.xml"
    local position = args.tree:data()

    local nextest_config = Path:new(adapter.root(position.path) .. ".config/nextest.toml")
    if nextest_config:exists() then
        nextest_config:copy({ destination = tmp_nextest_config })
    end

    with(open(tmp_nextest_config, "a"), function(writer)
        writer:write('[profile.neotest.junit]\npath = "' .. junit_path .. '"')
    end)

    local command = vim.tbl_flatten({
        "cargo",
        "nextest",
        "run",
        "--no-fail-fast",
        "--config-file",
        tmp_nextest_config,
        "--profile",
        "neotest",
        vim.list_extend(get_args(), args.extra_args or {}),
    })

    local integration_test = is_integration_test(position.path)
    if integration_test then
        vim.list_extend(command, { "--test", integration_test_name(position.path) })
    end

    local test_filter
    if position.type == "test" then
        -- TODO: Support rstest parametrized tests
        test_filter = "-E 'test(/^" .. position.id .. "$/)'"
    elseif position.type == "file" then
        local position_id = path_to_test_path(position.path)

        if is_unit_test(position.path) and position_id == nil then
            -- main.rs or lib.rs
            position_id = "tests"
        end

        if position_id then
            -- Either a unit test or an integration test in a subdirectory
            test_filter = "-E 'test(/^" .. position_id .. "::/)'"
        end
    end
    table.insert(command, test_filter)

    local cwd = adapter.root(position.path)

    local context = {
        junit_path = junit_path,
        file = position.path,
        test_filter = test_filter,
        integration_test = integration_test,
    }

    -- Debug
    if args.strategy == "dap" then
        return
            dap.resolve_strategy(
                position,
                cwd,
                context
            )
    end

    -- Run
    return {
        command = table.concat(command, " "),
        cwd = cwd,
        context = context,
    }
end

function adapter.results(spec, result, tree)
    local data

    local junit_path = spec.context.junit_path
    if dap.file_exists(junit_path) then
        with(open(junit_path, "r"), function(reader)
            data = reader:read("*a")
        end)
    else
        return dap.translate_results(junit_path)
    end

    local handler = xml_tree()
    local parser = xml.parser(handler)
    parser:parse(data)

    local testcases
    if #handler.root.testsuites.testsuite.testcase == 0 then
        testcases = { handler.root.testsuites.testsuite.testcase }
    else
        testcases = handler.root.testsuites.testsuite.testcase
    end

    local results = {}

    for _, testcase in pairs(testcases) do
        if testcase.failure then
            results[testcase._attr.name] = {
                status = "failed",
                short = testcase.failure[1],
            }
        else
            results[testcase._attr.name] = {
                status = "passed",
            }
        end
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
        return adapter
    end,
})

return adapter
