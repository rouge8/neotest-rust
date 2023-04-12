# neotest-rust

[Neotest](https://github.com/rcarriga/neotest) adapter for Rust, using
[cargo-nextest](https://nexte.st/).

Requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
and the parser for Rust.

```lua
require("neotest").setup({
  adapters = {
    require("neotest-rust")
  }
})
```

If you wish to give additional arguments to the `cargo nextest`,
you can specify the args when initializing the adapter.

```lua
require("neotest").setup({
  adapters = {
    require("neotest-rust") {
        args = { "--no-capture" },
    }
  }
})
```

Supports standard library tests, [`rstest`](https://github.com/la10736/rstest),
Tokio's `[#tokio::test]`, and more. Does not support `rstest`'s parametrized
tests.

## Debugging Tests

Codelldb is the default adapter used for debugging.
Alternatives can be specified via the `dap_adapter` property during initialization.

```lua
require("neotest").setup({
  adapters = {
    require("neotest-rust") {
        args = { "--no-capture" },
        dap_adapter = "lldb",
    }
  }
})
```

See [nvim-dap](https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation),
and [rust-tools#debugging](https://github.com/simrat39/rust-tools.nvim/wiki/Debugging) if you are using rust-tools.nvim,
for more information.

## Limitations

The following limitations apply to both running and debugging tests.

- Assumes unit tests in `main.rs`, `mod.rs`, and `lib.rs` are in a `tests`
  module.
- Does not support `rstest`'s `#[case]` macro.
- When running tests for a `main.rs` in an integration test subdirectory (e.g.
  `tests/testsuite/main.rs`), all tests in that subdirectory will be run (e.g.
  all tests in `tests/testsuite/`). This is because Cargo lacks the capability
  to specify a test file.

Additionally, when debugging tests, no output from failed tests will be captured in the results provided to Neotest.
