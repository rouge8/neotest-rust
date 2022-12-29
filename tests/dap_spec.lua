local async = require("plenary.async.tests")
local dap = require("neotest-rust.dap")
local Tree = require("neotest.types").Tree

local it = async.it
local describe = async.describe

-- TODO: M.resolve_strategy = function(position, cwd, context)
--	return { cwd = cwd, context = context, strategy = strategy }
describe("resolve_strategy", function()

	---- Does not support running the whole test suite
	---- only individual tests or files.
	--it("can create a strategy for a directory of tests", function()end)
	--it("can create a strategy for a namespace", function()end)
	local cwd = vim.loop.cwd()
	local path = cwd .. "/tests/data/src/mymod/foo.rs"
	local junit_path = "/nvim/mock/1.junit.xml"

	-- TODO: Integration test debugging

	it("can create a strategy for a single test", function()

		local tree = Tree:new({
			type = "test",
			path = path,
			id = "mymod::foo::tests::math",
		}, {}, function(data)
			return data
		end, {})

		local context = {
			junit_path = junit_path,
			file = path,
			test_filter = "",
			integration_test = false,
			test_path = nil
		}

		local spec = dap.resolve_strategy(tree:data(), cwd, context)

		assert.equal(spec.cwd, cwd)

		assert.are.same(spec.context, {
			junit_path = junit_path,
			file = path,
			test_filter = "math",
			integration_test = false,
			test_path = nil,
		})

		assert.are.same(spec.strategy, {
			name = "Debug Rust Tests",
			type = "lldb",
			request = "launch",
			cwd = cwd,
			stopOnEntry = false,
			args = {
				"--nocapture",
				"--test",
				"math",
			},
			program = nil,
		})
	end)

	it("can create a strategy for a file of tests", function()

        local tree = Tree:new({
            type = "file",
            path = path,
            id = path,
        }, {}, function(data)
            return data
        end, {})

		local context = {
			junit_path = junit_path,
			file = path,
			test_filter = "",
			integration_test = false,
			test_path = "mymod::foo"
		}

		local spec = dap.resolve_strategy(tree:data(), cwd, context)

		assert.equal(spec.cwd, cwd)

		assert.are.same(spec.context, {
			junit_path = junit_path,
			file = path,
			test_filter = "mymod::foo",
			integration_test = false,
			test_path = "mymod::foo"
		})

		assert.are.same(spec.strategy, {
			name = "Debug Rust Tests",
			type = "lldb",
			request = "launch",
			cwd = cwd,
			stopOnEntry = false,
			args = {
				"--nocapture",
				"--test",
				context.test_path,
			},
			program = nil,
		})
	end)
end)

describe("file_exists", function()

	local cwd = vim.loop.cwd()

	it("returns true when the file exists", function()

		local path = cwd .. "/tests/data/src/mymod/foo.rs"

		local exists = dap.file_exists(path)

		assert.equal(exists, true)
	end)

	it("returns false when the file does not exist", function()

		local path = cwd .. "/tests/data/src/mymod/bar.rs"

		local exists = dap.file_exists(path)

		assert.equal(exists, false)
	end)
end)

-- TODO:
describe("translate_results", function()

	-- TODO:
    it("parses results with a single test suite in it", function()
        --local adapter = require("neotest-rust")({})
        --local path = vim.loop.cwd() .. "/tests/data/single_test_suite.xml"
        --local spec = { context = { junit_path = path } }

        --local results = adapter.results(spec, nil, nil)

        --local expected = {
        --    ["foo::tests::should_fail"] = {
        --        short = "thread 'foo::tests::should_fail' panicked at 'assertion failed: false', src/foo.rs:10:9\nnote: run with `RUST_BACKTRACE=1` environment variable to display a backtrace",
        --        status = "failed",
        --    },
        --    ["foo::tests::should_pass"] = {
        --        status = "passed",
        --    },
        --}

        --assert.are.same(expected, results)
    end)

    it("translates raw results with multiple test suites in it", function()
        local path = vim.loop.cwd() .. "/tests/data/2"

        local results = dap.translate_results(path)

        local expected = {

            ["tests::math"] = { status = "passed",},

            ["mymod::tests::math"] = { status = "passed",},
            ["mymod::foo::tests::math"] = { status = "passed",},
            ["tests::nested::nested_math"] = { status = "passed",},
            ["tests::basic_math"] = { status = "passed",},
            ["tests::failed_math"] = {
				status = "failed",
			},
        }

        assert.are.same(expected, results)
	end)
end)
