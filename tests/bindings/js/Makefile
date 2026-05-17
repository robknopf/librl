ROOT_DIR ?= $(abspath ../../..)
NODE ?= $(shell command -v node 2>/dev/null || command -v nodejs 2>/dev/null)
SCRIPT_DIR := $(abspath .)

.PHONY: test build test_version_validate test_version_binding test_version_mismatch check_node

test: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_validate.mjs"
	@$(NODE) "$(SCRIPT_DIR)/test_version_binding.mjs"
	@bash "$(SCRIPT_DIR)/test_version_mismatch.sh" "$(ROOT_DIR)"
	@echo "JS binding version tests passed."

build:
	@$(MAKE) -C $(ROOT_DIR) wasm

test_version_validate: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_validate.mjs"

test_version_binding: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_binding.mjs"

test_version_mismatch: check_node build
	@bash "$(SCRIPT_DIR)/test_version_mismatch.sh" "$(ROOT_DIR)"

check_node:
	@if [ -z "$(NODE)" ]; then \
		echo "Error: no Node.js interpreter found (tried node, nodejs)"; \
		exit 1; \
	fi
