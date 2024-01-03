local async = require("nio.tests")
local strings = require("plenary.strings")
local dap = require("neotest-rust.dap")

describe("get_test_binary", function()
    -- Binaries are created for src/lib.rs, src/main.rs, tests/test_it.rs, and
    -- tests/testsuite/main.rs. We can only test that they match expected substrings
    -- and that the other modules resolve to their source binaries
    describe("for a simple-package", function()
        local cwd = vim.loop.cwd()
        local root = cwd .. "/tests/data/simple-package"

        local lib_actual = dap.get_test_binary(root, root .. "/src/lib.rs")
        local main_actual = dap.get_test_binary(root, root .. "/src/main.rs")
        local alt_bin_actual = dap.get_test_binary(root, root .. "/src/bin/alt-bin.rs")
        local test_it_actual = dap.get_test_binary(root, root .. "/tests/test_it.rs")
        local testsuite_actual = dap.get_test_binary(root, root .. "/tests/testsuite/main.rs")

        async.it("returns the test binary for src/lib.rs", function()
            assert(lib_actual)
            local expected = root .. "/target/debug/deps/simple_package-"
            local actual = strings.truncate(lib_actual, lib_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/main.rs", function()
            assert(main_actual)
            local expected = root .. "/target/debug/deps/simple_package-"
            local actual = strings.truncate(main_actual, main_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/bin/alt-bin.rs", function()
            assert(alt_bin_actual)
            local expected = root .. "/target/debug/deps/alt_bin-"
            local actual = strings.truncate(alt_bin_actual, alt_bin_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/mymod/foo.rs", function()
            local expected = main_actual
            local actual = dap.get_test_binary(root, root .. "/src/mymod/foo.rs")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/mymod/mod.rs", function()
            local expected = main_actual
            local actual = dap.get_test_binary(root, root .. "/src/mymod/mod.rs")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/mymod/notests.rs", function()
            local expected = nil
            local actual = dap.get_test_binary(root, root .. "/src/mymod/notests.rs")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for src/parent/child.rs", function()
            local expected = main_actual
            local actual = dap.get_test_binary(root, root .. "/src/parent/child.rs")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for tests/test_it.rs", function()
            assert(test_it_actual)
            local expected = root .. "/target/debug/deps/test_it-"
            local actual = strings.truncate(test_it_actual, test_it_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for tests/testsuite/it.rs", function()
            local expected = testsuite_actual
            local actual = dap.get_test_binary(root, root .. "/tests/testsuite/it.rs")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for tests/testsuite/main.rs", function()
            assert(testsuite_actual)
            local expected = root .. "/target/debug/deps/testsuite-"
            local actual = strings.truncate(testsuite_actual, testsuite_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)
    end)

    describe("for a workspace", function()
        local cwd = vim.loop.cwd()
        local root = cwd .. "/tests/data/workspace"

        async.it("returns the test binary for with_unit_tests/src/main.rs", function()
            local with_unit_actual = dap.get_test_binary(root, root .. "/with_unit_tests/src/main.rs")
            assert(with_unit_actual)

            local expected = root .. "/target/debug/deps/with_unit_tests-"
            local actual = strings.truncate(with_unit_actual, with_unit_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for with_integration_tests/src/main.rs", function()
            local with_integration_main_actual =
                dap.get_test_binary(root, root .. "/with_integration_tests/src/main.rs")
            assert(with_integration_main_actual)

            local expected = root .. "/target/debug/deps/with_integration_tests-"
            local actual = strings.truncate(with_integration_main_actual, with_integration_main_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)

        async.it("returns the test binary for with_integration_tests/tests/it.rs", function()
            local with_integration_it_actual = dap.get_test_binary(root, root .. "/with_integration_tests/tests/it.rs")
            assert(with_integration_it_actual)

            local expected = root .. "/target/debug/deps/it-"
            local actual = strings.truncate(with_integration_it_actual, with_integration_it_actual:len() - 16, "-")

            assert.equal(expected, actual)
        end)
    end)
end)

describe("translate_results", function()
    async.it("parses results with a single test suite in it", function()
        local path = vim.loop.cwd() .. "/tests/data/simple-package/1"

        local results = dap.translate_results(path)

        local expected = {
            ["tests::math"] = { status = "passed" },
        }

        assert.are.same(expected, results)
    end)

    async.it("translates raw results with multiple test suites in it", function()
        local path = vim.loop.cwd() .. "/tests/data/simple-package/3"

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
