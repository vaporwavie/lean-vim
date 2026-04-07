.PHONY: install

install:
	@if [ -n "$(INSTALL_PATH)" ]; then \
		./install.sh --path "$(INSTALL_PATH)"; \
	else \
		./install.sh; \
	fi
