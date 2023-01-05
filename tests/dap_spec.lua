local async = require("plenary.async.tests")
local dap = require("neotest-rust.dap")
local plugin = require("neotest-rust")
local Tree = require("neotest.types").Tree

local it = async.it
local describe = async.describe

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

-- TODO: These won't work in CI
describe("get_test_binary", function()

	local cwd = vim.loop.cwd()
	local root = cwd .. "/tests/data"

	it("returns the test binary for src/lib.rs", function()

		local expected = root .. "/target/debug/deps/data-071ea79d6338284b"
		local actual = dap.get_test_binary(root, root .. "/src/lib.rs")

		assert.equal(expected, actual)
		--local unexpected = root .. "/target/debug/deps/data-.*"
		--assert.matches(actual, unexpected)
	end)

	it("returns the test binary for src/main.rs", function()

		local expected = root .. "/target/debug/deps/data-7dd6d45fc077308b"
		local actual = dap.get_test_binary(root, root .. "/src/main.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for src/mymod/foo.rs", function()

		local expected = root .. "/target/debug/deps/data-7dd6d45fc077308b"
		local actual = dap.get_test_binary(root, root .. "/src/mymod/foo.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for src/mymod/mod.rs", function()

		local expected = root .. "/target/debug/deps/data-7dd6d45fc077308b"
		local actual = dap.get_test_binary(root, root .. "/src/mymod/mod.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for src/mymod/notests.rs", function()

		local expected = nil
		local actual = dap.get_test_binary(root, root .. "/src/mymod/notests.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for tests/test_it.rs", function()

		local expected = root .. "/target/debug/deps/test_it-6a27e87431b46ac9"
		local actual = dap.get_test_binary(root, root .. "/tests/test_it.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for tests/testsuite/it.rs", function()

		local expected = root .. "/target/debug/deps/testsuite-37806187190b2d0b"
		local actual = dap.get_test_binary(root, root .. "/tests/testsuite/it.rs")

		assert.equal(expected, actual)
	end)

	it("returns the test binary for tests/testsuite/main.rs", function()

		local expected = root .. "/target/debug/deps/testsuite-37806187190b2d0b"
		local actual = dap.get_test_binary(root, root .. "/tests/testsuite/main.rs")

		assert.equal(expected, actual)
	end)
end)

describe("translate_results", function()

    it("parses results with a single test suite in it", function()
        local path = vim.loop.cwd() .. "/tests/data/0"

        local results = dap.translate_results(path)

        local expected = {
            ["tests::math"] = { status = "passed" },
        }

        assert.are.same(expected, results)
    end)

    it("translates raw results with multiple test suites in it", function()
        local path = vim.loop.cwd() .. "/tests/data/2"

        local results = dap.translate_results(path)

        local expected = {

            ["tests::math"] = { status = "passed" },

            ["mymod::tests::math"] = { status = "passed" },
            ["mymod::foo::tests::math"] = { status = "passed" },
            ["tests::nested::nested_math"] = { status = "passed" },
            ["tests::basic_math"] = { status = "skipped" },
            ["tests::failed_math"] = { status = "failed" },
        }

        assert.are.same(expected, results)
	end)
end)

describe("build_spec", function()
    it("can debug a single test", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
            id = "mymod::foo::tests::math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"--exact",
			"mymod::foo::tests::math",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug a test file", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
            id = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"mymod::foo",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug tests in main.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/main.rs",
            id = vim.loop.cwd() .. "/tests/data/src/main.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"tests",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug tests in lib.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/lib.rs",
            id = vim.loop.cwd() .. "/tests/data/src/lib.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"tests",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

	-- TODO: Fix
    it("can debug tests in mod.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/mod.rs",
            id = vim.loop.cwd() .. "/tests/data/src/mymod/mod.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"mymod",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug a single integration test", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/tests/test_it.rs",
            id = "top_level_math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"--exact",
			"top_level_math",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug a file of integration tests", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/tests/test_it.rs",
            id = vim.loop.cwd() .. "/tests/data/src/tests/test_it.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"tests",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug an integration test in main.rs in a subdirectory", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/tests/testsuite/main.rs",
            id = "testsuite_top_level_math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"--exact",
			"testsuite_top_level_math",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug all integration tests in main.rs in a subdirectory", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/tests/testsuite/main.rs",
            id = vim.loop.cwd() .. "/tests/data/src/tests/testsuite/main.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"tests",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug an integration test in another test file in a subdirectory", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/tests/testsuite/it.rs",
            id = "it::testsuite_it_math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"--exact",
			"it::testsuite_it_math",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)

    it("can debug all integration tests in another test file in a subdirectory", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/tests/testsuite/it.rs",
            id = "it::",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
        assert.are.same(spec.strategy.args, {
			"--nocapture",
			"it",
		})
        assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data")
    end)
end)
