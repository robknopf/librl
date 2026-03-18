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
CACHE_DIR := cache
WASM_JS := $(OUT_DIR)/main.js
WASM_DEBUG_JS := $(OUT_DIR)/main.debug.js
SRC := main.c

INCLUDES := -I$(ROOT)/include
LIBS := -L$(ROOT)/lib -lrl -lssl -lcrypto -lz -lm -lpthread -ldl -lX11
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
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
	rm -rf $(CACHE_DIR)
