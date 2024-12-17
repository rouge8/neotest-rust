local cwd = vim.loop.cwd()

vim.opt.rtp:append(cwd)
vim.opt.rtp:append(cwd .. "/deps/lazy.nvim")

require("lazy.minit").busted({
    spec = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-treesitter/nvim-treesitter",
            config = function()
                local configs = require("nvim-treesitter.configs")

                configs.setup({
                    ensure_installed = { "rust" },
                    sync_install = true,
                })
            end,
        },
        "nvim-neotest/nvim-nio",
        "nvim-neotest/neotest",
    },
})
