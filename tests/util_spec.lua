local async = require("nio.tests")
local util = require("neotest-rust.util")

describe("file_exists", function()
    local cwd = vim.loop.cwd()

    async.it("returns true when the file exists", function()
        local path = cwd .. "/tests/data/simple-package/src/mymod/foo.rs"

        local exists = util.file_exists(path)

        assert.equal(exists, true)
    end)

    async.it("returns false when the file does not exist", function()
        local path = cwd .. "/tests/data/src/simple-package/mymod/bar.rs"

        local exists = util.file_exists(path)

        assert.equal(exists, false)
    end)
end)
