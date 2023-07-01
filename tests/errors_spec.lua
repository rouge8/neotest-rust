local errors = require("neotest-rust.errors")

describe("parses errors from output", function()
    it("non-parsable errors in output", function()
        local output = "something\nwent\nwrong"
        local results = errors.parse_errors(output)

        assert.is_true(#results == 0)
    end)

    it("assert_eq", function()
        local output = "test tests::failed_math ... FAILED\n"
            .. "failures:\n\n"
            .. "---- tests::failed_math stdout ----\n"
            .. "thread 'tests::failed_math' panicked at 'assertion failed: `(left == right)`\n"
            .. "  left: `2`,\n"
            .. " right: `3`', src/main.rs:16:9\n"
            .. "note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace"

        local results = errors.parse_errors(output)
        local expected = {
            {
                line = 15,
                message = "assertion failed: `(left == right)`\n  left: `2`,\n right: `3`",
            },
        }

        assert.are.same(expected, results)
    end)
end)
