local async = require("neotest.async")
local context_manager = require("plenary.context_manager")
local Job = require("plenary.job")
local open = context_manager.open
local Path = require("plenary.path")
local lib = require("neotest.lib")
local with = context_manager.with
local xml = require("neotest.lib.xml")

local adapter = { name = "neotest-rust" }

function adapter.root(dir)
    local cwd = lib.files.match_root_pattern("Cargo.toml")(dir)

    if cwd == nil then
        return
    end

    local metadata
    Job:new({
        command = "cargo",
        args = { "metadata" },
        cwd = cwd,
        on_exit = function(j, return_val)
            metadata = vim.json.decode(j:result()[1])
        end,
    }):sync()

    return metadata.workspace_root
end

local get_args = function()
    return {}
end

local is_callable = function(obj)
    return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

function adapter.is_test_file(file_path)
    return vim.endswith(file_path, ".rs") and #adapter.discover_positions(file_path):to_list() ~= 1
end

local get_package_root = lib.files.match_root_pattern("Cargo.toml")

local function is_unit_test(path)
    return vim.startswith(path, get_package_root(path) .. Path.path.sep .. "src" .. Path.path.sep)
end

local function is_integration_test(path)
    return vim.startswith(path, get_package_root(path) .. Path.path.sep .. "tests" .. Path.path.sep)
end

local function file_exists(file)
    local f = io.open(file, "r")

    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
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

function adapter.discover_positions(path)
    local query = [[
(
  (attribute_item
    [
      (attribute
        (identifier) @macro_name
      )
      (attribute
        [
	  (identifier) @macro_name
	  (scoped_identifier
	    name: (identifier) @macro_name
          )
        ]
      )
    ]
  )
  (attribute_item
    (attribute
      (identifier)
    )
  )*
  .
  (function_item
    name: (identifier) @test.name
  ) @test.definition
  (#any-of? @macro_name "test" "rstest" "case")

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
        writer:write("[profile.neotest.junit]\npath = '" .. junit_path .. "'")
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

    if is_integration_test(position.path) then
        vim.list_extend(command, { "--test", integration_test_name(position.path) })
    end

    -- Determine the package name if we're in a workspace
    local workspace_root = adapter.root(position.path) .. Path.path.sep
    local package_root = lib.files.match_root_pattern("Cargo.toml")(position.path)
    local package_name = (package_root:sub(0, #workspace_root) == workspace_root)
        and package_root:sub(#workspace_root + 1)

    local package_filter = ""
    if package_name then
        package_filter = "package(" .. package_name .. ") & "
    end

    local position_id
    local test_filter
    if position.type == "test" then
        position_id = position.id
        -- TODO: Support rstest parametrized tests
        test_filter = "-E '" .. package_filter .. "test(/^" .. position_id .. "$/)'"
    elseif position.type == "file" then
        if package_name then
            -- A basic filter to run tests within the package that will be
            -- overridden later if 'position_id' is not nil
            test_filter = "-E 'package(" .. package_name .. ")'"
        end

        position_id = path_to_test_path(position.path)

        if is_unit_test(position.path) and position_id == nil then
            -- main.rs or lib.rs
            position_id = "tests"
        end

        if position_id then
            -- Either a unit test or an integration test in a subdirectory
            test_filter = "-E '" .. package_filter .. "test(/^" .. position_id .. "::/)'"
        end
    end
    table.insert(command, test_filter)

    return {
        command = table.concat(command, " "),
        cwd = adapter.root(position.path),
        context = {
            junit_path = junit_path,
            file = position.path,
            test_filter = test_filter,
            position_id = position_id,
        },
    }
end

function adapter.results(spec, result, tree)
    local results = {}

    if file_exists(spec.context.junit_path) then
        local data
        with(open(spec.context.junit_path, "r"), function(reader)
            data = reader:read("*a")
        end)

        local root = xml.parse(data)

        local testsuites
        if not root.testsuites.testsuite == nil and #root.testsuites.testsuite == 0 then
            testsuites = { root.testsuites.testsuite }
        else
            testsuites = root.testsuites.testsuite
        end
	if testsuites == nil then
	    return results
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
        end
    else
        results[spec.context.position_id] = {
            status = "failed",
            output = result.output,
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
        return adapter
    end,
})

return adapter
