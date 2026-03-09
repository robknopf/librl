ROOT := ../..
CC_WASM ?= emcc
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
CFLAGS_WASM ?= -DPLATFORM_WEB
LDFLAGS_WASM ?= \
	-s WASM=1 \
	-lidbfs.js \
	-s USE_GLFW=3 \
	-s FETCH=1 \
	-s ASYNCIFY=1 \
	-s EXPORT_ES6=1 \
	-s MODULARIZE=1 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1
DEBUG_CFLAGS_WASM ?= -Wall -Wextra -O0 -g3 -DPLATFORM_WEB
DEBUG_LDFLAGS_WASM ?= \
	-s WASM=1 \
	-lidbfs.js \
	-s USE_GLFW=3 \
	-s FETCH=1 \
	-s ASYNCIFY=1 \
	-s EXPORT_ES6=1 \
	-s MODULARIZE=1 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s ASSERTIONS=2 \
	-s SAFE_HEAP=1 \
	-s STACK_OVERFLOW_CHECK=2
DEBUG_SOURCEMAP_LDFLAGS_WASM ?= $(DEBUG_LDFLAGS_WASM) -gsource-map -g

OUT_DIR := out
BIN := $(OUT_DIR)/main
WASM_JS := $(OUT_DIR)/main.js
WASM_DEBUG_JS := $(OUT_DIR)/main.debug.js
SRC := main.c lua_interop.c
LIBLUA_REPO ?= git@github.com:robknopf/liblua-builder.git
LIBLUA_ROOT ?= deps/lua
LIBLUA_INC := $(LIBLUA_ROOT)/include
LIBLUA_DESKTOP_ARCHIVE := $(LIBLUA_ROOT)/lib/liblua.a
LIBLUA_WASM_ARCHIVE := $(LIBLUA_ROOT)/lib/liblua.wasm.a

INCLUDES := -I$(ROOT)/include -I$(ROOT)/deps/wgutils -I$(ROOT)/deps/libraylib/include -I$(LIBLUA_INC)
LIBS := -L$(ROOT)/lib -L$(LIBLUA_ROOT)/lib -lrl -llua -lcurl -lm -lpthread -ldl -lX11
WASM_LIBS := $(ROOT)/lib/librl.wasm.a $(LIBLUA_WASM_ARCHIVE) -lm

.PHONY: all deps ensure_deps desktop run wasm wasm-debug clean

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)
wasm-debug: $(WASM_DEBUG_JS)

deps:
	@if [ ! -d "$(LIBLUA_ROOT)" ]; then \
		if [ -z "$(LIBLUA_REPO)" ]; then \
			echo "Error: LIBLUA_REPO is not set and $(LIBLUA_ROOT) does not exist."; \
			echo "Set LIBLUA_REPO to your lua-builder repo (or pre-populate $(LIBLUA_ROOT))."; \
			exit 1; \
		fi; \
		echo "Cloning lua builder from $(LIBLUA_REPO) into $(LIBLUA_ROOT)"; \
		mkdir -p "$$(dirname "$(LIBLUA_ROOT)")"; \
		git clone $(LIBLUA_REPO) $(LIBLUA_ROOT); \
	else \
		echo "Updating existing lua builder directory: $(LIBLUA_ROOT)"; \
		git -C "$(LIBLUA_ROOT)" pull --ff-only; \
	fi
	@if [ ! -f "$(LIBLUA_ROOT)/Makefile" ]; then \
		echo "Error: missing Lua dependency makefile at $(LIBLUA_ROOT)/Makefile"; \
		exit 1; \
	fi
	@echo "Running make in $(LIBLUA_ROOT)"
	@$(MAKE) -C "$(LIBLUA_ROOT)" wasm desktop

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

$(BIN): $(SRC) $(LIBLUA_DESKTOP_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(LIBS) -o $(BIN)

$(WASM_JS): $(SRC) $(LIBLUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) $(LIBLUA_WASM_ARCHIVE) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
