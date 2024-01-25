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

    it("parses unexpected panics", function()
        local output = [[
running 1 test
test rocks::dependency::tests::parse_dependency ... FAILED

failures:

    Finished test [unoptimized + debuginfo] target(s) in 0.12s
    Starting 1 test across 2 binaries (17 skipped)
        FAIL [   0.004s] rocks-lib rocks::dependency::tests::parse_dependency
test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 17 filtered out; finis
hed in 0.00s


--- STDERR:              rocks-lib rocks::dependency::tests::parse_dependency ---
thread 'rocks::dependency::tests::parse_dependency' panicked at rocks-lib/src/rocks/dependency.rs:86:64:
called `Result::unwrap()` on an `Err` value: unexpected end of input while parsing min or version number

Location:
    rocks-lib/src/rocks/dependency.rs:62:22
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
]]
        local results = errors.parse_errors(output)
        local expected = {
            {
                line = 85,
                message = "called `Result::unwrap()` on an `Err` value: unexpected end of input while parsing min or version number",
            },
        }

        assert.are.same(expected, results)
    end)
end)
