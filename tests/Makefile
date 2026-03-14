ROOT_DIR ?= $(abspath ..)

CC_WASM ?= emcc
CC_DESKTOP ?= gcc
NODE ?= $(shell command -v node 2>/dev/null || command -v nodejs 2>/dev/null)
CHROME ?= $(shell command -v google-chrome 2>/dev/null || command -v chromium-browser 2>/dev/null || command -v chromium 2>/dev/null)
EM_CACHE_DIR ?= $(abspath $(ROOT_DIR)/.emcache)
EM_ENV := EM_CACHE=$(EM_CACHE_DIR)

CORE_INC_DIR := $(ROOT_DIR)/deps/wgutils/include
CORE_LIB_DIR := $(ROOT_DIR)/deps/wgutils/lib
CORE_DESKTOP_ARCHIVE := $(CORE_LIB_DIR)/libwgutils.a
CORE_WASM_ARCHIVE := $(CORE_LIB_DIR)/libwgutils.wasm.a
CORE_DESKTOP_LINK_FILE := $(CORE_LIB_DIR)/libwgutils.desktop.link
UNIT_TEST_DIR := $(ROOT_DIR)/tests/unit
HEADLESS_PROBE_C := $(ROOT_DIR)/tests/headless/fileio_probe_wasm.c
HEADLESS_PROBE_JS := $(ROOT_DIR)/tests/headless/fileio_probe.js
HEADLESS_PROBE_RUNNER := $(ROOT_DIR)/tests/headless/run_idbfs_probe.py
OUT_WASM := $(ROOT_DIR)/lib/librl.js

UNIT_TEST_MAIN := $(UNIT_TEST_DIR)/tests_main.c
UNIT_TEST_SRCS := \
	$(UNIT_TEST_DIR)/fetch_url_stub.c \
	$(UNIT_TEST_DIR)/raylib_loader_stub.c \
	$(UNIT_TEST_DIR)/rl_handle_pool_test.c \
	$(UNIT_TEST_DIR)/rl_loader_test.c
UNIT_TEST_LIB_SRCS := \
	$(ROOT_DIR)/src/rl_handle_pool.c \
	$(ROOT_DIR)/src/rl_loader.c \
	$(ROOT_DIR)/src/rl_scratch.c
UNIT_TEST_DESKTOP_BIN := /tmp/librl_unit_tests
UNIT_TEST_WASM_JS := /tmp/librl_unit_tests.js

WASM_COMMON_LDFLAGS ?= \
	-s WASM=1 \
	-lidbfs.js \
	-s USE_GLFW=3 \
	-s FETCH=1 \
	-s EXPORT_ES6=1 \
	-s MODULARIZE=1 \
	-s MIN_WEBGL_VERSION=2 \
	-s MAX_WEBGL_VERSION=2 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1

CFLAGS ?= -Wall -Wextra -fdiagnostics-color=always -Isrc -O2
INCLUDES := -I$(ROOT_DIR) -I$(ROOT_DIR)/include -I$(ROOT_DIR)/deps/libraylib/include -I$(ROOT_DIR)/src -I$(CORE_INC_DIR)

.PHONY: test test_desktop test_wasm unit_test_desktop unit_test_wasm probe_idbfs_build probe_idbfs check_node check_chrome check_probe_python

test_desktop:
	@$(MAKE) -C $(ROOT_DIR) desktop
	@$(MAKE) unit_test_desktop
	@echo "Desktop smoke test passed (build + librl unit tests)."

test_wasm:
	@$(MAKE) -C $(ROOT_DIR) wasm
	@$(MAKE) unit_test_wasm
	@$(MAKE) probe_idbfs
	@test -s "$(OUT_WASM)" || (echo "Missing or empty wasm JS loader: $(OUT_WASM)" && exit 1)
	@test -s "$(OUT_WASM:.js=.wasm)" || (echo "Missing or empty wasm binary: $(OUT_WASM:.js=.wasm)" && exit 1)
	@echo "WASM smoke test passed (build + unit tests + artifact checks + IDBFS probe)."

test: test_desktop test_wasm
	@echo "All smoke tests passed."

unit_test_desktop:
	@$(MAKE) -C $(ROOT_DIR)/deps/wgutils desktop
	$(CC_DESKTOP) $(CFLAGS) -DHEADLESS $(INCLUDES) -I$(UNIT_TEST_DIR) $(UNIT_TEST_MAIN) $(UNIT_TEST_SRCS) $(UNIT_TEST_LIB_SRCS) $(CORE_DESKTOP_ARCHIVE) $$(cat $(CORE_DESKTOP_LINK_FILE)) -o $(UNIT_TEST_DESKTOP_BIN)
	@$(UNIT_TEST_DESKTOP_BIN) > /tmp/librl_unit_tests_desktop.log 2>&1 || (cat /tmp/librl_unit_tests_desktop.log && exit 1)
	@tail -n 1 /tmp/librl_unit_tests_desktop.log

unit_test_wasm: check_node
	@$(MAKE) -C $(ROOT_DIR)/deps/wgutils wasm
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(CFLAGS) -DHEADLESS $(INCLUDES) -I$(UNIT_TEST_DIR) $(UNIT_TEST_MAIN) $(UNIT_TEST_SRCS) $(UNIT_TEST_LIB_SRCS) $(CORE_WASM_ARCHIVE) -o $(UNIT_TEST_WASM_JS) $(WASM_COMMON_LDFLAGS) -s ENVIRONMENT=node -s EXIT_RUNTIME=1
	@$(NODE) $(UNIT_TEST_WASM_JS) > /tmp/librl_unit_tests_wasm.log 2>&1 || (cat /tmp/librl_unit_tests_wasm.log && exit 1)
	@tail -n 1 /tmp/librl_unit_tests_wasm.log

probe_idbfs_build:
	@$(MAKE) -C $(ROOT_DIR)/deps/wgutils wasm
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) -o $(HEADLESS_PROBE_JS) \
		$(HEADLESS_PROBE_C) \
		-Isrc \
		-I$(CORE_INC_DIR) \
		$(CORE_WASM_ARCHIVE) \
		$(WASM_COMMON_LDFLAGS) \
		-s EXPORTED_FUNCTIONS='["_probe_fileio_init","_probe_fileio_write_text","_probe_fileio_exists","_probe_fileio_deinit"]' \
		-O2

probe_idbfs: probe_idbfs_build check_chrome check_probe_python
	@CHROME_BIN="$(CHROME)" python3 $(HEADLESS_PROBE_RUNNER)

check_node:
	@if [ -z "$(NODE)" ]; then \
		echo "Missing Node.js runtime: install node (or set NODE=/path/to/node) to run wasm unit tests."; \
		exit 1; \
	fi
	@echo "Using Node runtime: $(NODE)"

check_chrome:
	@if [ -z "$(CHROME)" ]; then \
		echo "Missing Chrome/Chromium: set CHROME=/path/to/browser for probe_idbfs."; \
		exit 1; \
	fi
	@echo "Using headless browser: $(CHROME)"

check_probe_python:
	@python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('websocket') else 1)" || (echo "Missing Python websocket-client module (import websocket)" && exit 1)
	@echo "Python websocket-client module available"
