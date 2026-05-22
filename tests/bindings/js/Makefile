ROOT_DIR ?= $(abspath ../../..)
FIND_NODE_JSPI := $(abspath $(ROOT_DIR)/tools/find_node_jspi.py)
NODE := $(shell \
	_n="$(NODE)"; \
	if [ -n "$$_n" ] && "$$_n" -e 'process.exit(typeof WebAssembly.Suspending==="function"?0:1)' 2>/dev/null; then \
		printf '%s' "$$_n"; \
	else \
		python3 "$(FIND_NODE_JSPI)" 2>/dev/null; \
	fi)
export NODE
SCRIPT_DIR := $(abspath .)

SMOKE_TESTS := \
	test_boot_smoke.mjs \
	test_namespace_smoke.mjs \
	test_init_smoke.mjs

VERSION_TESTS := \
	test_version_validate.mjs \
	test_version_binding.mjs \
	test_version_mismatch.mjs

.PHONY: test build check_node \
	test_smoke test_version_validate test_version_binding test_version_mismatch

test: check_node build
	@for t in $(SMOKE_TESTS); do \
		echo "==> $$t"; \
		$(NODE) "$(SCRIPT_DIR)/$$t" || exit 1; \
	done
	@for t in $(VERSION_TESTS); do \
		echo "==> $$t"; \
		$(NODE) "$(SCRIPT_DIR)/$$t" || exit 1; \
	done
	@echo "JS binding tests passed."

build:
	@$(MAKE) -C $(ROOT_DIR) wasm binding-types

test_smoke: check_node build
	@for t in $(SMOKE_TESTS); do \
		echo "==> $$t"; \
		$(NODE) "$(SCRIPT_DIR)/$$t" || exit 1; \
	done
	@echo "JS binding smoke tests passed."

test_version_validate: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_validate.mjs"

test_version_binding: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_binding.mjs"

test_version_mismatch: check_node build
	@$(NODE) "$(SCRIPT_DIR)/test_version_mismatch.mjs"

check_node:
	@if [ -z "$(NODE)" ]; then \
		echo "Error: no Node.js with JSPI found (need Node >= 25; try nvm install 26)"; \
		exit 1; \
	fi
	@if ! "$(NODE)" -e 'process.exit(typeof WebAssembly.Suspending === "function" ? 0 : 1)' 2>/dev/null; then \
		echo "Error: $(NODE) lacks JSPI; set NODE=/path/to/node >= 25"; \
		exit 1; \
	fi
