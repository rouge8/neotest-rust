local async = require("plenary.async.tests")
local plugin = require("neotest-rust")
local Tree = require("neotest.types").Tree

describe("is_test_file", function()
    it("matches Rust files", function()
        assert.equals(true, plugin.is_test_file("foo.rs"))
    end)
end)

describe("discover_positions", function()
    async.it("discovers positions in unit tests in main.rs", function()
        local positions = plugin.discover_positions("tests/data/src/main.rs"):to_list()

        local expected_positions = {
            {
                id = "tests/data/src/main.rs",
                name = "main.rs",
                path = "tests/data/src/main.rs",
                range = { 0, 0, 23, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = "tests/data/src/main.rs",
                    range = { 5, 0, 22, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::basic_math",
                        name = "basic_math",
                        path = "tests/data/src/main.rs",
                        range = { 7, 4, 9, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "tests::failed_math",
                        name = "failed_math",
                        path = "tests/data/src/main.rs",
                        range = { 12, 4, 14, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "tests::nested",
                        name = "nested",
                        path = "tests/data/src/main.rs",
                        range = { 16, 4, 21, 5 },
                        type = "namespace",
                    },
                    {
                        {
                            id = "tests::nested::nested_math",
                            name = "nested_math",
                            path = "tests/data/src/main.rs",
                            range = { 18, 8, 20, 9 },
                            type = "test",
                        },
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in lib.rs", function()
        local positions = plugin.discover_positions("tests/data/src/lib.rs"):to_list()

        local expected_positions = {
            {
                id = "tests/data/src/lib.rs",
                name = "lib.rs",
                path = "tests/data/src/lib.rs",
                range = { 0, 0, 7, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = "tests/data/src/lib.rs",
                    range = { 1, 0, 6, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::math",
                        name = "math",
                        path = "tests/data/src/lib.rs",
                        range = { 3, 4, 5, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in mod.rs", function()
        local positions = plugin.discover_positions("tests/data/src/mymod/mod.rs"):to_list()

        local expected_positions = {
            {
                id = "tests/data/src/mymod/mod.rs",
                name = "mod.rs",
                path = "tests/data/src/mymod/mod.rs",
                range = { 0, 0, 7, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = "tests/data/src/mymod/mod.rs",
                    range = { 1, 0, 6, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::math",
                        name = "math",
                        path = "tests/data/src/mymod/mod.rs",
                        range = { 3, 4, 5, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in unit tests in a regular Rust file", function()
        local positions = plugin.discover_positions("tests/data/src/mymod/foo.rs"):to_list()

        local expected_positions = {
            {
                id = "tests/data/src/mymod/foo.rs",
                name = "foo.rs",
                path = "tests/data/src/mymod/foo.rs",
                range = { 0, 0, 7, 0 },
                type = "file",
            },
            {
                {
                    id = "tests",
                    name = "tests",
                    path = "tests/data/src/mymod/foo.rs",
                    range = { 1, 0, 6, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "tests::math",
                        name = "math",
                        path = "tests/data/src/mymod/foo.rs",
                        range = { 3, 4, 5, 5 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)

    async.it("discovers positions in integration tests", function()
        local positions = plugin.discover_positions("tests/data/tests/test_it.rs"):to_list()

        local expected_positions = {
            {
                id = "tests/data/tests/test_it.rs",
                name = "test_it.rs",
                path = "tests/data/tests/test_it.rs",
                range = { 0, 0, 18, 0 },
                type = "file",
            },
            {
                {
                    id = "top_level_math",
                    name = "top_level_math",
                    path = "tests/data/tests/test_it.rs",
                    range = { 1, 0, 3, 1 },
                    type = "test",
                },
            },
            {
                {
                    id = "nested",
                    name = "nested",
                    path = "tests/data/tests/test_it.rs",
                    range = { 5, 0, 17, 1 },
                    type = "namespace",
                },
                {
                    {
                        id = "nested::nested_math",
                        name = "nested_math",
                        path = "tests/data/tests/test_it.rs",
                        range = { 7, 4, 9, 5 },
                        type = "test",
                    },
                },
                {
                    {
                        id = "nested::extra_nested",
                        name = "extra_nested",
                        path = "tests/data/tests/test_it.rs",
                        range = { 11, 4, 16, 5 },
                        type = "namespace",
                    },
                    {
                        {
                            id = "nested::extra_nested::extra_nested_math",
                            name = "extra_nested_math",
                            path = "tests/data/tests/test_it.rs",
                            range = { 13, 8, 15, 9 },
                            type = "test",
                        },
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)
    end)
end)

describe("build_spec", function()
    it("can run a single test", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
            id = "mymod::foo::tests::math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^mymod::foo::tests::math$/)'")
    end)

    it("can run a test file", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
            id = vim.loop.cwd() .. "/tests/data/src/mymod/foo.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^mymod::foo::/)'")
    end)

    it("can run tests in main.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/main.rs",
            id = vim.loop.cwd() .. "/tests/data/src/main.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^tests::/)'")
    end)

    it("can run tests in lib.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/lib.rs",
            id = vim.loop.cwd() .. "/tests/data/src/lib.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^tests::/)'")
    end)

    it("can run tests in mod.rs", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/src/mymod/mod.rs",
            id = vim.loop.cwd() .. "/tests/data/src/mymod/mod.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^mymod::/)'")
    end)

    it("can run a single integration test", function()
        local tree = Tree:new({
            type = "test",
            path = vim.loop.cwd() .. "/tests/data/tests/test_it.rs",
            id = "top_level_math",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, "-E 'test(/^top_level_math$/)'")
        assert.matches(".+ %-%-test test_it", spec.command)
    end)

    it("can run a file of integration tests", function()
        local tree = Tree:new({
            type = "file",
            path = vim.loop.cwd() .. "/tests/data/tests/test_it.rs",
            id = vim.loop.cwd() .. "/tests/data/src/tests/test_it.rs",
        }, {}, function(data)
            return data
        end, {})

        local spec = plugin.build_spec({ tree = tree })
        assert.equal(spec.context.test_filter, nil)
        assert.matches(".+ %-%-test test_it", spec.command)
    end)
end)
