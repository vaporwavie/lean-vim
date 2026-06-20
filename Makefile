.PHONY: install check

install:
	@if [ -n "$(INSTALL_PATH)" ]; then \
		./install.sh --path "$(INSTALL_PATH)"; \
	else \
		./install.sh; \
	fi

check:
	nvim --headless +"qa"
	nvim --headless +"checkhealth vim.lsp nvim-treesitter conform" +"qa"
	nvim --headless +"luafile scripts/check.lua" +"qa"
