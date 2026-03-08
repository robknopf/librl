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

INCLUDES := -I$(ROOT)/include -I$(ROOT)/src -I$(ROOT)/deps/libraylib/include -I$(ROOT)/deps/lua/include
LIBS := -L$(ROOT)/lib -lrl -lcurl -lm -lpthread -ldl -lX11
WASM_LIBS := $(ROOT)/lib/librl.wasm.a -lm

.PHONY: all desktop run wasm wasm-debug clean

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)
wasm-debug: $(WASM_DEBUG_JS)

$(BIN): $(SRC) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(LIBS) -o $(BIN)

$(WASM_JS): $(SRC) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	$(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
