local M = {}

--- Parse errors from rustc output
---@param output string
---@return neotest.Error[]
function M.parse_errors(output)
    local message, line = output:match("thread '[^']+' panicked at '([^']+)', [^:]+:(%d+):%d+")

    -- Note: we have to return the line index, not the line number
    return {
        { line = tonumber(line) - 1, message = message },
    }
end

return M
