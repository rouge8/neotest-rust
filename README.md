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

Supports standard library tests, [`rstest`](https://github.com/la10736/rstest),
Tokio's `[#tokio::test]`, and more. Does not support `rstest`'s parametrized
tests.

## Limitations

- Does not support running the whole test suite, only individual tests or
  files.
- Assumes unit tests in `main.rs`, `mod.rs`, and `lib.rs` are in a `tests`
  module.
- Does not support `rstest`'s `#[case]` macro.
- When running tests for a `main.rs` in an integration test subdirectory (e.g.
  `tests/testsuite/main.rs`), all tests in that subdirectory will be run (e.g.
  all tests in `tests/testsuite/`). This is because Cargo lacks the capability
  to specify a test file.
