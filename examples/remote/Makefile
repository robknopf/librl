ROOT := ../..
CC_WASM ?= emcc
CC ?= gcc
EM_CACHE_DIR ?= $(abspath $(ROOT)/.emcache)
EM_ENV := EM_CACHE=$(EM_CACHE_DIR)
CFLAGS ?= -Wall -Wextra -O2
WASM_PLATFORM_CFLAGS ?= -DPLATFORM_WEB
WASM_COMMON_LDFLAGS ?= \
	-s WASM=1 \
	-lidbfs.js \
	-lwebsocket.js \
	--pre-js src/module_env.pre.js \
	-s USE_GLFW=3 \
	-s FETCH=1 \
	-s EXPORT_ES6=1 \
	-s MODULARIZE=1 \
	-s MIN_WEBGL_VERSION=2 \
	-s MAX_WEBGL_VERSION=2 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s STACK_SIZE=262144 \
	-s STACK_OVERFLOW_CHECK=0
CFLAGS_WASM ?= $(WASM_PLATFORM_CFLAGS)
LDFLAGS_WASM ?= $(WASM_COMMON_LDFLAGS)

OUT_DIR := out
BIN := $(OUT_DIR)/main
WASM_JS := $(OUT_DIR)/main.js
SRC_DIR := src
SRC := $(SRC_DIR)/main.c $(SRC_DIR)/rl_ws_client.c $(SRC_DIR)/rl_protocol.c $(SRC_DIR)/rl_resource_handler.c
OBJS := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.o,$(SRC))
WASM_OBJS := $(patsubst $(SRC_DIR)/%.c,$(OUT_DIR)/%.wasm.o,$(SRC))

INCLUDES := -Iinclude -I$(ROOT)/include -I$(ROOT)/deps/wgutils/include -I$(ROOT)/deps/libraylib/include 
RL_STATIC_LIB := $(ROOT)/lib/librl.a
LIBS := $(RL_STATIC_LIB) -lnghttp2 -lssl -lcrypto -lz -lm -lpthread -ldl -lX11
WASM_LIBS := $(ROOT)/lib/librl.wasm.a -lm

.PHONY: all desktop wasm clean

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(OUT_DIR)/%.o: $(SRC_DIR)/%.c | $(OUT_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

$(OUT_DIR)/%.wasm.o: $(SRC_DIR)/%.c | $(OUT_DIR)
	$(EM_ENV) $(CC_WASM) $(CFLAGS_WASM) $(INCLUDES) -c $< -o $@

$(BIN): $(OBJS)
	$(CC) $(OBJS) $(LIBS) -o $@
	@echo "Built desktop remote client: $@"

$(WASM_JS): $(WASM_OBJS)
	$(EM_ENV) $(CC_WASM) $(WASM_OBJS) $(WASM_LIBS) $(LDFLAGS_WASM) -o $@
	@echo "Built WASM remote client: $@"

clean:
	rm -rf $(OUT_DIR)

run: $(BIN)
	./$(BIN)
