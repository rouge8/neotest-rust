local async = require("nio.tests")
local discovery = require("neotest-rust.discovery")
local plugin = require("neotest-rust")
local lib = require("neotest.lib")
local Tree = require("neotest.types.tree")
local Path = require("plenary.path")
local say = require("say")

describe("escape_testcase_name", function()
    describe("converts", function()
        it("single word", function()
            assert.equals("word", discovery._escape_testcase_name("word"))
        end)
        it("simple sentence", function()
            assert.equals("a_simple_sentence", discovery._escape_testcase_name("a simple sentence"))
        end)
        it("converts extra spaces inbetween", function()
            assert.equals("extra_spaces_inbetween", discovery._escape_testcase_name("extra  spaces  inbetween"))
        end)
        it("extra end and start spaces", function()
            assert.equals(
                "_extra_end_and_start_spaces_",
                discovery._escape_testcase_name(" extra end and start spaces ")
            )
        end)
        it("alphabet", function()
            assert.equals(
                "abcdefghijklmnoqprstuwvxyz1234567890",
                discovery._escape_testcase_name("abcdefghijklmnoqprstuwvxyz1234567890")
            )
        end)
    end)
    describe("converts to lowercase", function()
        it("ALL UPPER", function()
            assert.equals("all_upper", discovery._escape_testcase_name("ALL_UPPER"))
        end)
        it("MiXeD CaSe", function()
            assert.equals("mixed_case", discovery._escape_testcase_name("MiXeD CaSe"))
        end)
    end)
    it("handles numeric first char", function()
        assert.equals("_1test", discovery._escape_testcase_name("1test"))
    end)
    it("omits unicode", function()
        assert.equals("from_to", discovery._escape_testcase_name("from⟶to"))
    end)
    it("handles empty input", function()
        assert.equals("_empty", discovery._escape_testcase_name(""))
    end)
end)

describe("binary_path", function()
    local function workspace()
        return vim.fn.expand("%:p:h") .. "/package"
    end

    it("checks module file", function()
        assert.equals("package", discovery._binary_name(workspace() .. "/src/foo.rs", workspace()))
    end)

    it("checks integration test file", function()
        assert.equals("package::foo", discovery._binary_name(workspace() .. "/tests/foo.rs", workspace()))
    end)

    it("checks binary file", function()
        assert.equals("package::bin/foo", discovery._binary_name(workspace() .. "/src/bin/foo.rs", workspace()))
    end)

    it("checks example file", function()
        assert.equals("package::example/foo", discovery._binary_name(workspace() .. "/examples/foo.rs", workspace()))
    end)

    it("returns nil for unknown path", function()
        assert.equals(nil, discovery._binary_name(workspace() .. "foo/bar"))
    end)
end)

describe("resolve_case_name", function()
    local function p()
        return Path:new("")
    end
    describe("#[values]", function()
        it("resolves numeric parameter", function()
            assert.equals("foo[42]", discovery.resolve_case_name("foo_1_42", "values", p()))
            assert.equals("foo[43]", discovery.resolve_case_name("foo_2_43", "values", p()))
            assert.equals("foo[44]", discovery.resolve_case_name("foo_10_44", "values", p()))
        end)
        it("resolves string parameter", function()
            assert.equals('blub["foo"]', discovery.resolve_case_name("blub_1___foo__", "values", p()))
            assert.equals('blub["bar"]', discovery.resolve_case_name("blub_2___bar__", "values", p()))
            assert.equals('blub["baz"]', discovery.resolve_case_name("blub_10___baz__", "values", p()))
        end)

        it("resolves multiple value parameter sets", function()
            assert.equals('foo["a"] bar[7]', discovery.resolve_case_name("foo_1___a__::bar_1_7", "values", p()))
            assert.equals('foo["b"] bar[8]', discovery.resolve_case_name("foo_2___b__::bar_2_8", "values", p()))
            assert.equals('foo["Z"] bar[9]', discovery.resolve_case_name("foo_20___Z__::bar_20_9", "values", p()))
        end)
    end)

    describe("#[case]", function()
        it("strips 'case_X' prefix", function()
            assert.equals("foo_bar", discovery.resolve_case_name("case_1_foo_bar", "case", p()))
            assert.equals("foo_bar", discovery.resolve_case_name("case_10_foo_bar", "case", p()))
        end)
        it("keeps 'case_X' prefix if no description provided", function()
            assert.equals("case_1", discovery.resolve_case_name("case_1", "case", p()))
            assert.equals("case_42", discovery.resolve_case_name("case_42", "case", p()))
        end)
    end)

    describe("#[files]", function()
        local function root()
            -- path to `rs-test/` crate
            return Path:new(vim.loop.cwd() .. "/tests/data/rs-test/")
        end
        it("resolves file", function()
            assert.equals("file[Cargo.toml]", discovery.resolve_case_name("file_1_Cargo_toml", "files", root()))
            assert.equals("file[Cargo.lock]", discovery.resolve_case_name("file_22_Cargo_lock", "files", root()))
        end)
        it("resolves folder", function()
            assert.equals("file[src]", discovery.resolve_case_name("file_2_src", "files", root()))
        end)
        it("resolves nested file", function()
            assert.equals("file[src/lib.rs]", discovery.resolve_case_name("file_1_src/lib.rs", "files", root()))
            assert.equals("file[src/foo.txt]", discovery.resolve_case_name("file_22_src_foo_txt", "files", root()))
            assert.equals(
                "file[src/bar/b_a_z.txt]",
                discovery.resolve_case_name("file_202_src_bar_b_a_z_txt", "files", root())
            )
        end)
        it("resolves nested folder", function()
            assert.equals("file[src/bar]", discovery.resolve_case_name("file_3_src_bar", "files", root()))
        end)
        it("isn't capable to resolve paths with special chars other than '_'", function()
            -- To bad =(
            assert.not_equals("file[foo-bar.txt]", discovery.resolve_case_name("file_3_foo_bar_txt", "files", root()))
        end)
    end)
end)

describe("discovery", function()
    -- Helper functions
    local function relative(file)
        return vim.loop.cwd() .. "/" .. file
    end

    local function discover(strategy, file, pred)
        plugin.set_param_discovery(strategy)
        local tree = plugin.discover_positions(file)
        local tests = {}
        for _, node in tree:iter_nodes() do
            local data = node:data()
            if pred(data) then
                table.insert(tests, data)
            end
        end
        return tests
    end

    local function with_type(t)
        return function(n)
            return n.type == t
        end
    end
    local function with_id(pattern)
        return function(n)
            return string.match(n.id, pattern) ~= nil
        end
    end

    describe("testcase/src/lib.rs", function()
        local file = relative("tests/data/testcase/src/lib.rs")
        describe("strategy=`treesitter`", function()
            local strategy = "treesitter"
            async.it("has namespace `tests`", function()
                local namespaces = discover(strategy, file, with_type("namespace"))
                assert.are.same(namespaces, {
                    {
                        path = file,
                        id = "tests",
                        name = "tests",
                        type = "namespace",
                        range = { 1, 0, 29, 1 },
                        parameterization = nil,
                    },
                })
            end)

            async.it("has tests named `first`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::first$")), {
                    {
                        id = "tests::first",
                        name = "first",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                        parameterization = "test_case",
                    },
                })
            end)

            async.it("has tests named `second`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::second$")), {
                    {
                        id = "tests::second",
                        name = "second",
                        path = file,
                        type = "test",
                        range = { 18, 4, 20, 5 },
                        parameterization = '#[test_case(false ; "no")]',
                    },
                })
            end)

            async.it("has tests named `third`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::third$")), {
                    {
                        id = "tests::third",
                        name = "third",
                        path = file,
                        type = "test",
                        range = { 26, 4, 28, 5 },
                        parameterization = '#[test_case(false ; "no")]',
                    },
                })
            end)

            async.it("`first` test has five cases", function()
                local tests = discover(strategy, file, with_id("^tests::first::.*$"))
                assert.are.same(tests, {
                    { id = "tests::first::_empty", name = "", path = file, type = "test", range = { 4, 4, 4, 24 } },
                    { id = "tests::first::one", name = "one", path = file, type = "test", range = { 5, 4, 5, 27 } },
                    {
                        id = "tests::first::name_with_spaces",
                        name = "name with spaces",
                        path = file,
                        type = "test",
                        range = { 6, 4, 6, 40 },
                    },
                    {
                        id = "tests::first::mixed_case",
                        name = "MixEd-CaSe",
                        path = file,
                        type = "test",
                        range = { 8, 4, 8, 34 },
                    },
                    {
                        id = "tests::first::sp3_a_ar5",
                        name = "sp3(|a/-(ar5",
                        path = file,
                        type = "test",
                        range = { 9, 4, 9, 36 },
                    },
                })
            end)

            async.it("`second` test has two cases", function()
                local tests = discover(strategy, file, with_id("^tests::second::.*$"))
                assert.are.same(tests, {
                    { id = "tests::second::yes", name = "yes", path = file, type = "test", range = { 14, 4, 14, 30 } },
                    { id = "tests::second::no", name = "no", path = file, type = "test", range = { 16, 4, 16, 30 } },
                })
            end)

            async.it("`third` test has three cases", function()
                local tests = discover(strategy, file, with_id("^tests::third::.*$"))
                assert.are.same(tests, {
                    { id = "tests::third::yes", name = "yes", path = file, type = "test", range = { 22, 4, 22, 30 } },
                    { id = "tests::third::no", name = "no", path = file, type = "test", range = { 24, 4, 24, 30 } },
                })
            end)
        end)

        describe("strategy=`cargo`", function()
            local strategy = "cargo"

            async.it("has namespace `tests`", function()
                local namespaces = discover(strategy, file, with_type("namespace"))
                assert.are.same(namespaces, {
                    {
                        path = file,
                        id = "tests",
                        name = "tests",
                        type = "namespace",
                        range = { 1, 0, 29, 1 },
                        parameterization = nil,
                    },
                })
            end)

            async.it("has tests named `first`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::first$")), {
                    {
                        id = "tests::first",
                        name = "first",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                        parameterization = "test_case",
                    },
                })
                --
            end)

            async.it("named `second`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::second$")), {
                    {
                        id = "tests::second",
                        name = "second",
                        path = file,
                        type = "test",
                        range = { 18, 4, 20, 5 },
                        parameterization = '#[test_case(false ; "no")]',
                    },
                })
            end)
            async.it("named `third`", function()
                assert.is.same(discover(strategy, file, with_id("^tests::third$")), {
                    {
                        id = "tests::third",
                        name = "third",
                        path = file,
                        type = "test",
                        range = { 26, 4, 28, 5 },
                        parameterization = '#[test_case(false ; "no")]',
                    },
                })
            end)

            async.it("`first` test has five cases", function()
                local tests = discover(strategy, file, with_id("^tests::first::.*$"))
                assert.are.same(tests, {
                    {
                        id = "tests::first::_empty",
                        name = "_empty",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                    },
                    {
                        id = "tests::first::mixed_case",
                        name = "mixed_case",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                    },
                    {
                        id = "tests::first::name_with_spaces",
                        name = "name_with_spaces",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                    },
                    { id = "tests::first::one", name = "one", path = file, type = "test", range = { 10, 4, 12, 5 } },
                    {
                        id = "tests::first::sp3_a_ar5",
                        name = "sp3_a_ar5",
                        path = file,
                        type = "test",
                        range = { 10, 4, 12, 5 },
                    },
                })
            end)

            async.it("`second` test has two cases", function()
                local tests = discover(strategy, file, with_id("^tests::second::.*$"))
                assert.are.same(tests, {
                    { id = "tests::second::no", name = "no", path = file, type = "test", range = { 18, 4, 20, 5 } },
                    { id = "tests::second::yes", name = "yes", path = file, type = "test", range = { 18, 4, 20, 5 } },
                })
            end)

            async.it("`third` test has three cases", function()
                local tests = discover(strategy, file, with_id("^tests::third::.*$"))
                assert.are.same(tests, {
                    { id = "tests::third::no", name = "no", path = file, type = "test", range = { 26, 4, 28, 5 } },
                    { id = "tests::third::yes", name = "yes", path = file, type = "test", range = { 26, 4, 28, 5 } },
                })
            end)
        end)
    end)

    describe("rs-test/src/lib.rs", function()
        local file = relative("tests/data/rs-test/src/lib.rs")
        describe("strategy=`treesitter`", function()
            local strategy = "treesitter"
            async.it("has namespace `tests`", function()
                assert.is.same(discover(strategy, file, with_type("namespace")), {
                    {
                        path = file,
                        id = "tests",
                        name = "tests",
                        type = "namespace",
                        range = { 1, 0, 138, 1 },
                        parameterization = nil,
                    },
                })
            end)

            describe("contains test...", function()
                async.it("`timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::timeout$")), {
                        {
                            id = "tests::timeout",
                            name = "timeout",
                            path = file,
                            type = "test",
                            range = { 7, 4, 10, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`fixture_injected`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_injected$")), {
                        {
                            id = "tests::fixture_injected",
                            name = "fixture_injected",
                            path = file,
                            type = "test",
                            range = { 17, 4, 19, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`fixture_rename`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_rename$")), {
                        {
                            id = "tests::fixture_rename",
                            name = "fixture_rename",
                            path = file,
                            type = "test",
                            range = { 26, 4, 28, 5 },
                            parameterization = "from",
                        },
                    })
                end)

                async.it("`fixture_partial_injection`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_partial_injection$")), {
                        {
                            id = "tests::fixture_partial_injection",
                            name = "fixture_partial_injection",
                            path = file,
                            type = "test",
                            range = { 36, 4, 38, 5 },
                            parameterization = "with",
                        },
                    })
                end)

                async.it("`fixture_async`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_async$")), {
                        {
                            id = "tests::fixture_async",
                            name = "fixture_async",
                            path = file,
                            type = "test",
                            range = { 46, 4, 48, 5 },
                            parameterization = "future",
                        },
                    })
                end)

                async.it("`parameterized`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized$")), {
                        {
                            id = "tests::parameterized",
                            name = "parameterized",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_timeout$")), {
                        {
                            id = "tests::parameterized_timeout",
                            name = "parameterized_timeout",
                            path = file,
                            type = "test",
                            range = { 109, 4, 112, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_with_descriptions`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_with_descriptions$")), {
                        {
                            id = "tests::parameterized_with_descriptions",
                            name = "parameterized_with_descriptions",
                            path = file,
                            type = "test",
                            range = { 64, 4, 66, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_tokio`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_tokio$")), {
                        {
                            id = "tests::parameterized_tokio",
                            name = "parameterized_tokio",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_async_std`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_std$")), {
                        {
                            id = "tests::parameterized_async_std",
                            name = "parameterized_async_std",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_async_parameter`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_parameter$")), {
                        {
                            id = "tests::parameterized_async_parameter",
                            name = "parameterized_async_parameter",
                            path = file,
                            type = "test",
                            range = { 95, 4, 102, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`parameterized_async_timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_timeout$")), {
                        {
                            id = "tests::parameterized_async_timeout",
                            name = "parameterized_async_timeout",
                            path = file,
                            type = "test",
                            range = { 120, 4, 126, 5 },
                            parameterization = "case",
                        },
                    })
                end)
            end)

            describe("contains cases...", function()
                async.it("4 x `parameterized`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized::.*$")), {
                        {
                            id = "tests::parameterized::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 51, 4, 51, 14 },
                        },
                        {
                            id = "tests::parameterized::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 52, 4, 52, 14 },
                        },
                        {
                            id = "tests::parameterized::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 53, 4, 53, 14 },
                        },
                        {
                            id = "tests::parameterized::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 55, 4, 55, 15 },
                        },
                    })
                end)

                async.it("3 x `parameterized_with_descriptions`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_with_descriptions::.*$")), {
                        {
                            id = "tests::parameterized_with_descriptions::case_1_one",
                            name = "one",
                            path = file,
                            type = "test",
                            range = { 61, 4, 61, 19 },
                        },
                        {
                            id = "tests::parameterized_with_descriptions::case_2_two",
                            name = "two",
                            path = file,
                            type = "test",
                            range = { 62, 4, 62, 19 },
                        },
                        {
                            id = "tests::parameterized_with_descriptions::case_3_ten",
                            name = "ten",
                            path = file,
                            type = "test",
                            range = { 63, 4, 63, 20 },
                        },
                    })
                end)
                async.it("4 x `parameterized_tokio`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_tokio::.*$")), {
                        {
                            id = "tests::parameterized_tokio::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 69, 4, 69, 14 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 71, 4, 71, 14 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 72, 4, 72, 14 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 73, 4, 73, 15 },
                        },
                    })
                end)

                async.it("4 x `parameterized_async_std`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_std::.*$")), {
                        {
                            id = "tests::parameterized_async_std::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 80, 4, 80, 14 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 82, 4, 82, 14 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 83, 4, 83, 14 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 84, 4, 84, 15 },
                        },
                    })
                end)

                async.it("2 x `parameterized_async_parameter`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_parameter::.*$")), {
                        {
                            id = "tests::parameterized_async_parameter::case_1_even",
                            name = "even",
                            path = file,
                            type = "test",
                            range = { 91, 4, 91, 30 },
                        },
                        {
                            id = "tests::parameterized_async_parameter::case_2_odd",
                            name = "odd",
                            path = file,
                            type = "test",
                            range = { 93, 4, 93, 29 },
                        },
                    })
                end)

                async.it("2 x `parameterized_timeout`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_timeout::.*$")), {
                        {
                            id = "tests::parameterized_timeout::case_1_pass",
                            name = "pass",
                            path = file,
                            type = "test",
                            range = { 105, 4, 105, 43 },
                        },
                        {
                            id = "tests::parameterized_timeout::case_2_fail",
                            name = "fail",
                            path = file,
                            type = "test",
                            range = { 107, 4, 107, 44 },
                        },
                    })
                end)

                async.it("3 x `parameterized_async_timeout`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_timeout::.*$")), {
                        {
                            id = "tests::parameterized_async_timeout::case_1_pass",
                            name = "pass",
                            path = file,
                            type = "test",
                            range = { 115, 4, 115, 46 },
                        },
                        {
                            id = "tests::parameterized_async_timeout::case_2_fail_timeout",
                            name = "fail_timeout",
                            path = file,
                            type = "test",
                            range = { 117, 4, 117, 55 },
                        },
                        {
                            id = "tests::parameterized_async_timeout::case_3_fail_value",
                            name = "fail_value",
                            path = file,
                            type = "test",
                            range = { 118, 4, 118, 52 },
                        },
                    })
                end)
            end)
        end)

        describe("strategy=`cargo`", function()
            local strategy = "cargo"
            async.it("has namespace `tests`", function()
                assert.are.same(discover(strategy, file, with_type("namespace")), {
                    {
                        path = file,
                        id = "tests",
                        name = "tests",
                        type = "namespace",
                        range = { 1, 0, 138, 1 },
                        parameterization = nil,
                    },
                })
            end)

            describe("contains test...", function()
                async.it("`timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::timeout$")), {
                        {
                            id = "tests::timeout",
                            name = "timeout",
                            path = file,
                            type = "test",
                            range = { 7, 4, 10, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`fixture_injected`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_injected$")), {
                        {
                            id = "tests::fixture_injected",
                            name = "fixture_injected",
                            path = file,
                            type = "test",
                            range = { 17, 4, 19, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`fixture_rename`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_rename$")), {
                        {
                            id = "tests::fixture_rename",
                            name = "fixture_rename",
                            path = file,
                            type = "test",
                            range = { 26, 4, 28, 5 },
                            parameterization = "from",
                        },
                    })
                end)

                async.it("`fixture_partial_injection`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_partial_injection$")), {
                        {
                            id = "tests::fixture_partial_injection",
                            name = "fixture_partial_injection",
                            path = file,
                            type = "test",
                            range = { 36, 4, 38, 5 },
                            parameterization = "with",
                        },
                    })
                end)

                async.it("`fixture_async`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::fixture_async$")), {
                        {
                            id = "tests::fixture_async",
                            name = "fixture_async",
                            path = file,
                            type = "test",
                            range = { 46, 4, 48, 5 },
                            parameterization = "future",
                        },
                    })
                end)

                async.it("`parameterized`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized$")), {
                        {
                            id = "tests::parameterized",
                            name = "parameterized",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_with_descriptions`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_with_descriptions$")), {
                        {
                            id = "tests::parameterized_with_descriptions",
                            name = "parameterized_with_descriptions",
                            path = file,
                            type = "test",
                            range = { 64, 4, 66, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_tokio`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_tokio$")), {
                        {
                            id = "tests::parameterized_tokio",
                            name = "parameterized_tokio",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_async_std`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_std$")), {
                        {
                            id = "tests::parameterized_async_std",
                            name = "parameterized_async_std",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_async_parameter`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_parameter$")), {
                        {
                            id = "tests::parameterized_async_parameter",
                            name = "parameterized_async_parameter",
                            path = file,
                            type = "test",
                            range = { 95, 4, 102, 5 },
                            parameterization = "<injected>",
                        },
                    })
                end)

                async.it("`parameterized_timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_timeout$")), {
                        {
                            id = "tests::parameterized_timeout",
                            name = "parameterized_timeout",
                            path = file,
                            type = "test",
                            range = { 109, 4, 112, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`parameterized_async_timeout`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::parameterized_async_timeout$")), {
                        {
                            id = "tests::parameterized_async_timeout",
                            name = "parameterized_async_timeout",
                            path = file,
                            type = "test",
                            range = { 120, 4, 126, 5 },
                            parameterization = "case",
                        },
                    })
                end)

                async.it("`combinations`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::combinations$")), {
                        {
                            id = "tests::combinations",
                            name = "combinations",
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                            parameterization = "values",
                        },
                    })
                end)

                async.it("`files`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::files$")), {
                        {
                            id = "tests::files",
                            name = "files",
                            path = file,
                            type = "test",
                            range = { 135, 4, 137, 5 },
                            parameterization = "files",
                        },
                    })
                end)
            end)

            describe("contains cases...", function()
                async.it("4 x `parameterized`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized::.*$")), {
                        {
                            id = "tests::parameterized::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                        },
                        {
                            id = "tests::parameterized::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                        },
                        {
                            id = "tests::parameterized::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                        },
                        {
                            id = "tests::parameterized::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 56, 4, 58, 5 },
                        },
                    })
                end)

                async.it("3 x `parameterized_with_descriptions`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_with_descriptions::.*$")), {
                        {
                            id = "tests::parameterized_with_descriptions::case_1_one",
                            name = "one",
                            path = file,
                            type = "test",
                            range = { 64, 4, 66, 5 },
                        },
                        {
                            id = "tests::parameterized_with_descriptions::case_2_two",
                            name = "two",
                            path = file,
                            type = "test",
                            range = { 64, 4, 66, 5 },
                        },
                        {
                            id = "tests::parameterized_with_descriptions::case_3_ten",
                            name = "ten",
                            path = file,
                            type = "test",
                            range = { 64, 4, 66, 5 },
                        },
                    })
                end)

                async.it("4 x `parameterized_tokio`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_tokio::.*$")), {
                        {
                            id = "tests::parameterized_tokio::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                        },
                        {
                            id = "tests::parameterized_tokio::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 75, 4, 77, 5 },
                        },
                    })
                end)

                async.it("4 x `parameterized_async_std`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_std::.*$")), {
                        {
                            id = "tests::parameterized_async_std::case_1",
                            name = "case_1",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_2",
                            name = "case_2",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_3",
                            name = "case_3",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                        },
                        {
                            id = "tests::parameterized_async_std::case_4",
                            name = "case_4",
                            path = file,
                            type = "test",
                            range = { 86, 4, 88, 5 },
                        },
                    })
                end)

                async.it("2 x `parameterized_async_parameter`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_parameter::.*$")), {
                        {
                            id = "tests::parameterized_async_parameter::case_1_even",
                            name = "case_1_even",
                            path = file,
                            type = "test",
                            range = { 95, 4, 102, 5 },
                        },
                        {
                            id = "tests::parameterized_async_parameter::case_2_odd",
                            name = "case_2_odd",
                            path = file,
                            type = "test",
                            range = { 95, 4, 102, 5 },
                        },
                    })
                end)

                async.it("2 x `parameterized_timeout`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_timeout::.*$")), {
                        {
                            id = "tests::parameterized_timeout::case_1_pass",
                            name = "pass",
                            path = file,
                            type = "test",
                            range = { 109, 4, 112, 5 },
                        },
                        {
                            id = "tests::parameterized_timeout::case_2_fail",
                            name = "fail",
                            path = file,
                            type = "test",
                            range = { 109, 4, 112, 5 },
                        },
                    })
                end)

                async.it("3 x `parameterized_async_timeout`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::parameterized_async_timeout::.*$")), {
                        {
                            id = "tests::parameterized_async_timeout::case_1_pass",
                            name = "pass",
                            path = file,
                            type = "test",
                            range = { 120, 4, 126, 5 },
                        },
                        {
                            id = "tests::parameterized_async_timeout::case_2_fail_timeout",
                            name = "fail_timeout",
                            path = file,
                            type = "test",
                            range = { 120, 4, 126, 5 },
                        },
                        {
                            id = "tests::parameterized_async_timeout::case_3_fail_value",
                            name = "fail_value",
                            path = file,
                            type = "test",
                            range = { 120, 4, 126, 5 },
                        },
                    })
                end)

                async.it("9 x `combinations`", function()
                    assert.are.same(discover(strategy, file, with_id("^tests::combinations::.*$")), {
                        {
                            id = "tests::combinations::word_1___a__::has_chars_1_1",
                            name = 'word["a"] has_chars[1]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_1___a__::has_chars_2_2",
                            name = 'word["a"] has_chars[2]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_1___a__::has_chars_3_3",
                            name = 'word["a"] has_chars[3]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_2___bb__::has_chars_1_1",
                            name = 'word["bb"] has_chars[1]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_2___bb__::has_chars_2_2",
                            name = 'word["bb"] has_chars[2]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_2___bb__::has_chars_3_3",
                            name = 'word["bb"] has_chars[3]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_3___ccc__::has_chars_1_1",
                            name = 'word["ccc"] has_chars[1]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_3___ccc__::has_chars_2_2",
                            name = 'word["ccc"] has_chars[2]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                        {
                            id = "tests::combinations::word_3___ccc__::has_chars_3_3",
                            name = 'word["ccc"] has_chars[3]',
                            path = file,
                            type = "test",
                            range = { 130, 4, 132, 5 },
                        },
                    })
                end)

                async.it("3 x `files`", function()
                    assert.is.same(discover(strategy, file, with_id("^tests::files::.*$")), {
                        {
                            id = "tests::files::file_1_foo_bar_txt",
                            name = "file_1_foo_bar_txt",
                            path = file,
                            type = "test",
                            range = { 135, 4, 137, 5 },
                        },
                        {
                            id = "tests::files::file_2_src_bar_b_a_z_txt",
                            name = "file[src/bar/b_a_z.txt]",
                            path = file,
                            type = "test",
                            range = { 135, 4, 137, 5 },
                        },
                        {
                            id = "tests::files::file_3_src_foo_txt",
                            name = "file[src/foo.txt]",
                            path = file,
                            type = "test",
                            range = { 135, 4, 137, 5 },
                        },
                    })
                end)
            end)
        end)
    end)
end)
