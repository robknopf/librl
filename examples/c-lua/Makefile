ROOT := ../..
CC_WASM ?= emcc
CC ?= gcc
EM_CACHE_DIR ?= $(abspath $(ROOT)/.emcache)
EM_ENV := EM_CACHE=$(EM_CACHE_DIR)
CFLAGS ?= -Wall -Wextra -O3
WASM_PLATFORM_CFLAGS ?= -DPLATFORM_WEB
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
	-s ALLOW_MEMORY_GROWTH=1 \
	-s EXPORTED_FUNCTIONS='["_main"]'
# The browser drives the Lua frame pump through `Module.ccall(..., { async: true })`,
# so the exported `rl_tick` entrypoint must be wrapped by JSPI.
WASM_SYNC_LDFLAGS ?= -s JSPI=1 -s JSPI_EXPORTS='["rl_tick"]' -fwasm-exceptions
CFLAGS_WASM ?= $(WASM_PLATFORM_CFLAGS) -fwasm-exceptions
LDFLAGS_WASM ?= $(WASM_COMMON_LDFLAGS) $(WASM_SYNC_LDFLAGS)
DEBUG_CFLAGS_WASM ?= -Wall -Wextra -O0 -g3 $(WASM_PLATFORM_CFLAGS)
DEBUG_LDFLAGS_WASM ?= $(WASM_COMMON_LDFLAGS) \
	$(WASM_SYNC_LDFLAGS) \
	-s ASSERTIONS=2 \
	-s SAFE_HEAP=1 \
	-s STACK_OVERFLOW_CHECK=2
DEBUG_SOURCEMAP_LDFLAGS_WASM ?= $(DEBUG_LDFLAGS_WASM) -gsource-map -g

OUT_DIR := out
BIN := $(OUT_DIR)/main
CACHE_DIR := cache
WASM_JS := $(OUT_DIR)/main.js
WASM_DEBUG_JS := $(OUT_DIR)/main.debug.js
SRC := main.c
LUA_BINDINGS_SRC := $(wildcard $(ROOT)/bindings/lua/*.c)
LIBLUA_ROOT := $(ROOT)/deps/liblua
LIBLUA_INC := $(LIBLUA_ROOT)/include
LIBLUA_DESKTOP_ARCHIVE := $(LIBLUA_ROOT)/lib/liblua.a
LIBLUA_WASM_ARCHIVE := $(LIBLUA_ROOT)/lib/liblua.wasm.a

INCLUDES := -I$(ROOT)/include -I$(ROOT)/bindings/lua -I$(ROOT)/deps/wgutils/include -I$(ROOT)/deps/libraylib/include -I$(LIBLUA_INC)
RL_STATIC_LIB := $(ROOT)/lib/librl.a
RL_WASM_ARCHIVE := $(ROOT)/lib/librl.wasm.a
DESKTOP_LIBS := $(LIBLUA_DESKTOP_ARCHIVE) $(RL_STATIC_LIB) -lnghttp2 -lssl -lcrypto -lz -lm -lpthread -ldl -lX11
WASM_LIBS := $(LIBLUA_WASM_ARCHIVE) $(RL_WASM_ARCHIVE) -lm

.PHONY: all deps ensure_deps desktop run wasm wasm-debug clean

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)
wasm-debug: $(WASM_DEBUG_JS)

deps:
	@$(MAKE) -C $(ROOT) deps

ensure_deps:
	@if [ ! -f "$(LIBLUA_ROOT)/Makefile" ]; then \
		echo "Missing Lua dependency at $(LIBLUA_ROOT). Run 'make deps' first."; \
		exit 1; \
	fi

$(LIBLUA_DESKTOP_ARCHIVE): ensure_deps
	@if [ -f "$(LIBLUA_DESKTOP_ARCHIVE)" ]; then \
		echo "Using existing lua desktop archive: $(LIBLUA_DESKTOP_ARCHIVE)"; \
	else \
		echo "Missing lua desktop archive: $(LIBLUA_DESKTOP_ARCHIVE)"; \
		$(MAKE) -C "$(LIBLUA_ROOT)" desktop; \
	fi

$(LIBLUA_WASM_ARCHIVE): ensure_deps
	@if [ -f "$(LIBLUA_WASM_ARCHIVE)" ]; then \
		echo "Using existing lua wasm archive: $(LIBLUA_WASM_ARCHIVE)"; \
	else \
		echo "Missing lua wasm archive: $(LIBLUA_WASM_ARCHIVE)"; \
		$(MAKE) -C "$(LIBLUA_ROOT)" wasm; \
	fi

$(BIN): $(SRC) $(LUA_BINDINGS_SRC) $(LIBLUA_DESKTOP_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(LUA_BINDINGS_SRC) $(DESKTOP_LIBS) -o $(BIN)

$(WASM_JS): $(SRC) $(LUA_BINDINGS_SRC) $(LIBLUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(LUA_BINDINGS_SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) $(LUA_BINDINGS_SRC) $(LIBLUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(LUA_BINDINGS_SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
	rm -rf $(CACHE_DIR)
