local async = require("nio.tests")
local plugin = require("neotest-rust")
local Tree = require("neotest.types").Tree

describe("is_test_file", function()
    async.it("matches Rust files with tests in them", function()
        assert.equals(true, plugin.is_test_file(vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs"))
    end)

    async.it("doesn't discover non-Rust files", function()
        assert.equals(false, plugin.is_test_file(vim.loop.cwd() .. "/tests/data/simple-package/Cargo.toml"))
    end)

    async.it("doesn't discover Rust file without tests in it", function()
        assert.equals(false, plugin.is_test_file(vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/notests.rs"))
    end)
end)

describe("discover_positions", function()
    async.it("discovers positions in unit tests in main.rs", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                name = "main.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                range = { 0, 0, 27, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                    range = { 9, 0, 26, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::basic_math",
                        name = "basic_math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                        range = { 11, 4, 13, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "tests::failed_math",
                        name = "failed_math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                        range = { 16, 4, 18, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "tests::nested",
                        name = "nested",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                        range = { 20, 4, 25, 5 },
                        type = "namespace",
                    },
                    {
                        {
                            id = "tests::nested::nested_math",
                            name = "nested_math",
                            path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                            range = { 22, 8, 24, 9 },
                            type = "test",
                        },
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in alt-bin.rs", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                name = "alt-bin.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                range = { 0, 0, 11, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                    range = { 5, 0, 10, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::test_alt_bin",
                        name = "test_alt_bin",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                        range = { 7, 4, 9, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in lib.rs", function()
        local positions = plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                name = "lib.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                range = { 0, 0, 13, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                    range = { 1, 0, 12, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::math",
                        name = "math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                        range = { 3, 4, 5, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "tests::same_string",
                        name = "same_string",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                        range = { 9, 4, 11, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in mod.rs", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                name = "mod.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                range = { 0, 0, 9, 0 },
                type = "file",
            },
            {
                {
                    id = "mymod::tests",
                    name = "tests",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                    range = { 3, 0, 8, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "mymod::tests::math",
                        name = "math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                        range = { 5, 4, 7, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in a regular Rust file", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                name = "foo.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                range = { 0, 0, 7, 0 },
                type = "file",
            },
            {
                {
                    id = "mymod::foo::tests",
                    name = "tests",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                    range = { 1, 0, 6, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "mymod::foo::tests::math",
                        name = "math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                        range = { 3, 4, 5, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in integration tests", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                name = "test_it.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                range = { 0, 0, 18, 0 },
                type = "file",
            },
            {
                {
                    id = "top_level_math",
                    name = "top_level_math",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                    range = { 1, 0, 3, 1 },
                    type = "test",
                },
            },
            {
                {
                    id = "nested",
                    name = "nested",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                    range = { 5, 0, 17, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "nested::nested_math",
                        name = "nested_math",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                        range = { 7, 4, 9, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "nested::extra_nested",
                        name = "extra_nested",
                        path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                        range = { 11, 4, 16, 5 },
                        type = "namespace",
                    },
                    {
                        {
                            id = "nested::extra_nested::extra_nested_math",
                            name = "extra_nested_math",
                            path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                            range = { 13, 8, 15, 9 },
                            type = "test",
                        },
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in main.rs in a subdirectory of integration tests", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                name = "main.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                range = { 0, 0, 6, 0 },
                type = "file",
            },
            {
                {
                    id = "testsuite_top_level_math",
                    name = "testsuite_top_level_math",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                    range = { 3, 0, 5, 1 },
                    type = "test",
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in a test file in a subdirectory of integration tests", function()
        local positions =
            plugin.discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs"):to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                name = "it.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                range = { 0, 0, 4, 0 },
                type = "file",
            },
            {
                {
                    id = "it::testsuite_it_math",
                    name = "testsuite_it_math",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                    range = { 1, 0, 3, 1 },
                    type = "test",
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions when there are multiple macros present", function()
        local positions = plugin
            .discover_positions(vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/multiple_macros.rs")
            :to_list()

        local expected_positions = {
            {
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/multiple_macros.rs",
                name = "multiple_macros.rs",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/multiple_macros.rs",
                range = { 0, 0, 15, 0 },
                type = "file",
            },
            {
                {
                    id = "mymod::multiple_macros::should_panic_last",
                    name = "should_panic_last",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/multiple_macros.rs",
                    range = { 2, 0, 4, 1 },
                    type = "test",
                },
            },
            {
                {
                    id = "mymod::multiple_macros::should_panic_first",
                    name = "should_panic_first",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/multiple_macros.rs",
                    range = { 8, 0, 10, 1 },
                    type = "test",
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)
end)

describe("build_spec", function()
    describe("for a simple-package", function()
        it("can run a single test", function()
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                id = "mymod::foo::tests::math",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^mymod::foo::tests::math$/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run a test file", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^mymod::foo::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run tests in main.rs", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^tests::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run tests in alt-bin.rs", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.is.truthy(string.find(spec.command, "%-%-bin alt%-bin"))
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^tests::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run tests in lib.rs", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^tests::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run tests in mod.rs", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^mymod::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run tests in other_mod/foo.rs", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/src/other_mod/foo.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/other_mod/foo.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^other_mod::foo::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
        end)

        it("can run a single integration test", function()
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                id = "top_level_math",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^top_level_math$/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test test_it", spec.command)
        end)

        it("can run a file of integration tests", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/tests/test_it.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, nil)
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test test_it", spec.command)
        end)

        it("can run an integration test in main.rs in a subdirectory", function()
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                id = "testsuite_top_level_math",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^testsuite_top_level_math$/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test testsuite ", spec.command)
        end)

        it("can run all integration tests in main.rs in a subdirectory", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                id = vim.loop.cwd() .. "/tests/data/simple-package/src/tests/testsuite/main.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, nil)
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test testsuite$", spec.command)
        end)

        it("can run an integration test in another test file in a subdirectory", function()
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                id = "it::testsuite_it_math",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^it::testsuite_it_math$/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test testsuite ", spec.command)
        end)

        it("can run all integration tests in another test file in a subdirectory", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                id = "it::",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("test(/^it::/)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            assert.matches(".+ %-%-test testsuite ", spec.command)
        end)

        it("can add args for command", function()
            local adapter = require("neotest-rust")({
                args = {
                    "--no-capture",
                    "--test-threads",
                    3,
                },
            })
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                id = "top_level_math",
            }, {}, function(data)
                return data
            end, {})

            local spec = adapter.build_spec({ tree = tree })
            assert.matches(
                "cargo nextest run %-%-workspace %-%-no%-fail%-fast %-%-config%-file %g+ %-%-profile neotest %-%-no%-capture %-%-test%-threads 3 %-%-test test_it ",
                spec.command
            )
        end)
    end)

    describe("for a workspace", function()
        it("can run a single integration test", function()
            local tree = Tree:new({
                type = "test",
                path = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
                id = "it_works",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(
                spec.context.test_filter,
                "-E " .. vim.fn.shellescape("package(with_integration_tests) & test(/^it_works$/)")
            )
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            assert.matches(".+ %-%-test it", spec.command)
        end)

        it("can run a file of integration tests", function()
            local tree = Tree:new({
                type = "file",
                path = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
                id = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
            }, {}, function(data)
                return data
            end, {})

            local spec = plugin.build_spec({ tree = tree })
            assert.equal(spec.context.test_filter, "-E " .. vim.fn.shellescape("package(with_integration_tests)"))
            assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            assert.matches(".+ %-%-test it", spec.command)
        end)

        describe("where folder name is equal to the package name", function()
            it("can run a single test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                    id = "test_it",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree })
                assert.equal(
                    spec.context.test_filter,
                    "-E " .. vim.fn.shellescape("package(with_unit_tests) & test(/^test_it$/)")
                )
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)

            it("can run a test file", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                    id = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree })
                assert.equal(
                    spec.context.test_filter,
                    "-E " .. vim.fn.shellescape("package(with_unit_tests) & test(/^tests::/)")
                )
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)
        end)

        describe("where folder name is different than the package name", function()
            it("can run a single test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_other_folder_name/src/main.rs",
                    id = "test_it",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree })
                assert.equal(
                    spec.context.test_filter,
                    "-E " .. vim.fn.shellescape("package(some_other_name) & test(/^test_it$/)")
                )
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)

            it("can run a test file", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_other_folder_name/src/main.rs",
                    id = vim.loop.cwd() .. "/tests/data/workspace/with_other_folder_name/src/main.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree })
                assert.equal(
                    spec.context.test_filter,
                    "-E " .. vim.fn.shellescape("package(some_other_name) & test(/^tests::/)")
                )
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)
        end)
    end)

    describe("debug adapter protocol", function()
        describe("for a simple-package", function()
            async.it("can debug a single test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
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
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug a test file", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/foo.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "mymod::foo",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug tests in main.rs", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/main.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug tests in alt-bin.rs", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/bin/alt-bin.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug tests in lib.rs", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/lib.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug tests in mod.rs", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/mymod/mod.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "mymod",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug tests in other_mod/foo.rs", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/src/other_mod/foo.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/other_mod/foo.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "other_mod::foo",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug a single integration test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
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
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug a file of integration tests", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/test_it.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/tests/test_it.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug an integration test in main.rs in a subdirectory", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
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
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug all integration tests in main.rs in a subdirectory", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/main.rs",
                    id = vim.loop.cwd() .. "/tests/data/simple-package/src/tests/testsuite/main.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug an integration test in another test file in a subdirectory", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
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
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)

            async.it("can debug all integration tests in another test file in a subdirectory", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/simple-package/tests/testsuite/it.rs",
                    id = "it::",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "it",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/simple-package")
            end)
        end)

        describe("for a workspace", function()
            it("can debug a single test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                    id = "test_it",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "--exact",
                    "test_it",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)

            it("can debug a test file", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                    id = vim.loop.cwd() .. "/tests/data/workspace/with_unit_tests/src/main.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)

            it("can debug a single integration test", function()
                local tree = Tree:new({
                    type = "test",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
                    id = "it_works",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "--exact",
                    "it_works",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)

            it("can debug a file of integration tests", function()
                local tree = Tree:new({
                    type = "file",
                    path = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
                    id = vim.loop.cwd() .. "/tests/data/workspace/with_integration_tests/tests/it.rs",
                }, {}, function(data)
                    return data
                end, {})

                local spec = plugin.build_spec({ tree = tree, strategy = "dap" })
                assert.are.same(spec.strategy.args, {
                    "--nocapture",
                    "tests",
                })
                assert.equal(spec.cwd, vim.loop.cwd() .. "/tests/data/workspace")
            end)
        end)
    end)
end)

describe("results", function()
    it("parses results with a single test suite in it", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/single_test_suite.xml"
        local spec = { context = { junit_path = path }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = "/some/path" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            ["foo::tests::should_fail"] = {
                short = "thread 'foo::tests::should_fail' panicked at src/foo.rs:10:9:\nassertion failed: false\nnote: run with `RUST_BACKTRACE=1` environment variable to display a backtrace",
                status = "failed",
                errors = {
                    {
                        line = 9,
                        message = "assertion failed: false\n",
                    },
                },
            },
            ["foo::tests::should_pass"] = {
                status = "passed",
            },
        }

        assert.are.same(expected, results)
    end)

    it("parses results with no test suite in it", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/no_test_suite.xml"
        local spec = { context = { junit_path = path }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = "/some/path" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {}

        assert.are.same(expected, results)
    end)

    it("parses results with empty system-out and system-err", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/test_failure_with_empty_stdout_stder.xml"
        local spec = { context = { junit_path = path }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = "/some/path" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            ["foo::tests::should_not_crash"] = {
                status = "failed",
                errors = {},
            },
        }

        assert.are.same(expected, results)
    end)

    it("parses results with a multiple test suites in it", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/multiple_test_suites.xml"
        local spec = { context = { junit_path = path }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = "/some/path" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            ["foo::tests::should_fail"] = {
                short = "thread 'foo::tests::should_fail' panicked at src/foo.rs:10:9:\nassertion failed: false\nnote: run with `RUST_BACKTRACE=1` environment variable to display a backtrace",
                status = "failed",
                errors = { { line = 9, message = "assertion failed: false\n" } },
            },
            ["foo::tests::should_pass"] = {
                status = "passed",
            },
            should_fail = {
                short = "thread 'should_fail' panicked at tests/tests.rs:8:5:\nassertion failed: false\nnote: run with `RUST_BACKTRACE=1` environment variable to display a backtrace",
                status = "failed",
                errors = { { line = 7, message = "assertion failed: false\n" } },
            },
            should_pass = {
                status = "passed",
            },
        }

        assert.are.same(expected, results)
    end)

    it("parses raw results from result.output after debugging", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/does-not-exist.xml"
        local spec = { context = { junit_path = path, strategy = "dap" }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = vim.loop.cwd() .. "/tests/data/simple-package/1" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            ["tests::math"] = {
                status = "passed",
            },
        }

        assert.are.same(expected, results)
    end)

    it("parses raw results from strategy.stdio after debugging with codelldb", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/tests/data/simple-package/does-not-exist.xml"
        local spec = {
            context = { junit_path = path, strategy = "dap" },
            strategy = { stdio = { nil, vim.loop.cwd() .. "/tests/data/simple-package/3" } },
        }
        local strategy_result = { code = 101, output = vim.loop.cwd() .. "/tests/data/simple-package/1" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            ["tests::math"] = {
                status = "passed",
            },
            ["tests::basic_math"] = {
                status = "skipped",
            },
            ["mymod::foo::tests::math"] = {
                status = "passed",
            },
            ["mymod::tests::math"] = {
                status = "passed",
            },
            ["tests::nested::nested_math"] = {
                status = "passed",
            },
            ["tests::failed_math"] = {
                status = "failed",
            },
        }

        assert.are.same(expected, results)
    end)

    it("returns the cargo-nextest output if there is no junit file", function()
        local adapter = require("neotest-rust")({})
        local path = vim.loop.cwd() .. "/does-not-exist.xml"
        local position_id = "some_test"
        local spec = { context = { junit_path = path, position_id = position_id }, strategy = { stdio = nil } }
        local strategy_result = { code = 101, output = "/some/path" }

        local results = adapter.results(spec, strategy_result, nil)

        local expected = {
            [position_id] = {
                output = "/some/path",
                status = "failed",
            },
        }

        assert.are.same(expected, results)
    end)
end)

describe("filter_dir", function()
    it("doesn't exclude the src directory", function()
        local adapter = require("neotest-rust")({})
        local root = vim.loop.cwd() .. "/tests/data/simple-package"

        assert.equals(adapter.filter_dir("src", "src", root), true)
    end)

    it("excludes the target directory", function()
        local adapter = require("neotest-rust")({})
        local root = vim.loop.cwd() .. "/tests/data/simple-package"

        assert.equals(adapter.filter_dir("target", "target", root), false)
    end)
end)
