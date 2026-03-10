ROOT := ../..
CC_WASM ?= emcc
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
WASM_PLATFORM_CFLAGS ?= -DPLATFORM_WEB
WASM_COMMON_LDFLAGS ?= \
	-s WASM=1 \
	-lidbfs.js \
	-s USE_GLFW=3 \
	-s FETCH=1 \
	-s ASYNCIFY=1 \
	-s EXPORT_ES6=1 \
	-s MODULARIZE=1 \
	-s MIN_WEBGL_VERSION=2 \
	-s MAX_WEBGL_VERSION=2 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1
CFLAGS_WASM ?= $(WASM_PLATFORM_CFLAGS)
LDFLAGS_WASM ?= $(WASM_COMMON_LDFLAGS)
DEBUG_CFLAGS_WASM ?= -Wall -Wextra -O0 -g3 $(WASM_PLATFORM_CFLAGS)
DEBUG_LDFLAGS_WASM ?= $(WASM_COMMON_LDFLAGS) \
	-s ASSERTIONS=2 \
	-s SAFE_HEAP=1 \
	-s STACK_OVERFLOW_CHECK=2
DEBUG_SOURCEMAP_LDFLAGS_WASM ?= $(DEBUG_LDFLAGS_WASM) -gsource-map -g

OUT_DIR := out
BIN := $(OUT_DIR)/main
WASM_JS := $(OUT_DIR)/main.js
WASM_DEBUG_JS := $(OUT_DIR)/main.debug.js
SRC := main.c
ADDON_LUA_DIR := $(ROOT)/addons/lua
ADDON_LUA_DESKTOP_ARCHIVE := $(ADDON_LUA_DIR)/lib/librl_lua.a
ADDON_LUA_WASM_ARCHIVE := $(ADDON_LUA_DIR)/lib/librl_lua.wasm.a
ADDON_LUA_LIBLUA_DESKTOP_ARCHIVE := $(ADDON_LUA_DIR)/deps/liblua/lib/liblua.a
ADDON_LUA_LIBLUA_WASM_ARCHIVE := $(ADDON_LUA_DIR)/deps/liblua/lib/liblua.wasm.a

INCLUDES := -I$(ROOT)/include -I$(ROOT)/deps/wgutils -I$(ROOT)/deps/libraylib/include
LIBS := -L$(ROOT)/lib -lrl $(ADDON_LUA_DESKTOP_ARCHIVE) $(ADDON_LUA_LIBLUA_DESKTOP_ARCHIVE) -lcurl -lm -lpthread -ldl -lX11
WASM_LIBS := $(ROOT)/lib/librl.wasm.a $(ADDON_LUA_WASM_ARCHIVE) $(ADDON_LUA_LIBLUA_WASM_ARCHIVE) -lm

.PHONY: all deps ensure_deps desktop run wasm wasm-debug clean

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)
wasm-debug: $(WASM_DEBUG_JS)

deps:
	@if [ ! -f "$(ADDON_LUA_DIR)/Makefile" ]; then \
		echo "Error: missing Lua addon makefile at $(ADDON_LUA_DIR)/Makefile"; \
		exit 1; \
	fi
	@echo "Running make in $(ADDON_LUA_DIR)"
	@$(MAKE) -C "$(ADDON_LUA_DIR)" deps

ensure_deps:
	@if [ ! -f "$(ADDON_LUA_DIR)/Makefile" ]; then \
		echo "Missing Lua addon at $(ADDON_LUA_DIR). Run 'make deps' first."; \
		exit 1; \
	fi

$(ADDON_LUA_DESKTOP_ARCHIVE): ensure_deps
	@if [ -f "$(ADDON_LUA_DESKTOP_ARCHIVE)" ] && [ -f "$(ADDON_LUA_LIBLUA_DESKTOP_ARCHIVE)" ]; then \
		echo "Using existing lua addon desktop archives"; \
	else \
		echo "Missing lua addon desktop archive(s)"; \
		$(MAKE) -C "$(ADDON_LUA_DIR)" desktop; \
	fi

$(ADDON_LUA_WASM_ARCHIVE): ensure_deps
	@if [ -f "$(ADDON_LUA_WASM_ARCHIVE)" ] && [ -f "$(ADDON_LUA_LIBLUA_WASM_ARCHIVE)" ]; then \
		echo "Using existing lua addon wasm archives"; \
	else \
		echo "Missing lua addon wasm archive(s)"; \
		$(MAKE) -C "$(ADDON_LUA_DIR)" wasm; \
	fi

$(BIN): $(SRC) $(ADDON_LUA_DESKTOP_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(LIBS) -o $(BIN)

$(WASM_JS): $(SRC) $(ADDON_LUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) $(ADDON_LUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
