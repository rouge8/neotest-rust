.PHONY: test clean

test: deps/plenary.nvim deps/nvim-treesitter deps/nvim-treesitter/parser/rust.so deps/neotest
	./scripts/test

deps/plenary.nvim:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/nvim-treesitter/parser/rust.so: deps/nvim-treesitter
	nvim --headless -u tests/minimal_init.vim -c "TSInstallSync rust | quit"

deps/neotest:
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

clean:
	rm -rf deps/plenary.nvim deps/nvim-treesitter deps/neotest
