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
MODULE_REGISTRY_SRC := $(OUT_DIR)/module_registry.c
USES_MODULE_LUA ?= 1
MODULE_LUA_DIR := $(ROOT)/modules/lua
MODULE_LUA_DESKTOP_ARCHIVE := $(MODULE_LUA_DIR)/lib/librl_lua.a
MODULE_LUA_WASM_ARCHIVE := $(MODULE_LUA_DIR)/lib/librl_lua.wasm.a
MODULE_LUA_LIBLUA_DESKTOP_ARCHIVE := $(MODULE_LUA_DIR)/deps/liblua/lib/liblua.a
MODULE_LUA_LIBLUA_WASM_ARCHIVE := $(MODULE_LUA_DIR)/deps/liblua/lib/liblua.wasm.a

INCLUDES := -I$(ROOT)/include -I$(ROOT)/deps/wgutils -I$(ROOT)/deps/libraylib/include
MODULE_DESKTOP_ARCHIVES :=
MODULE_WASM_ARCHIVES :=
ifeq ($(USES_MODULE_LUA),1)
INCLUDES += -I$(MODULE_LUA_DIR)/include
MODULE_DESKTOP_ARCHIVES += $(MODULE_LUA_DESKTOP_ARCHIVE) $(MODULE_LUA_LIBLUA_DESKTOP_ARCHIVE)
MODULE_WASM_ARCHIVES += $(MODULE_LUA_WASM_ARCHIVE) $(MODULE_LUA_LIBLUA_WASM_ARCHIVE)
endif
LIBS := -L$(ROOT)/lib $(MODULE_DESKTOP_ARCHIVES) -lrl -lcurl -lm -lpthread -ldl -lX11
WASM_LIBS := $(MODULE_WASM_ARCHIVES) $(ROOT)/lib/librl.wasm.a -lm

.PHONY: all deps ensure_deps desktop run wasm wasm-debug clean FORCE

all: desktop wasm

desktop: $(BIN)

wasm: $(WASM_JS)
wasm-debug: $(WASM_DEBUG_JS)

deps:
	@if [ ! -f "$(MODULE_LUA_DIR)/Makefile" ]; then \
		echo "Error: missing Lua module makefile at $(MODULE_LUA_DIR)/Makefile"; \
		exit 1; \
	fi
	@echo "Running make in $(MODULE_LUA_DIR)"
	@$(MAKE) -C "$(MODULE_LUA_DIR)" deps

ensure_deps:
	@if [ ! -f "$(MODULE_LUA_DIR)/Makefile" ]; then \
		echo "Missing Lua module at $(MODULE_LUA_DIR). Run 'make deps' first."; \
		exit 1; \
	fi

$(MODULE_LUA_DESKTOP_ARCHIVE): ensure_deps
	@if [ -f "$(MODULE_LUA_DESKTOP_ARCHIVE)" ] && [ -f "$(MODULE_LUA_LIBLUA_DESKTOP_ARCHIVE)" ]; then \
		echo "Using existing lua module desktop archives"; \
	else \
		echo "Missing lua module desktop archive(s)"; \
		$(MAKE) -C "$(MODULE_LUA_DIR)" desktop; \
	fi

$(MODULE_LUA_WASM_ARCHIVE): ensure_deps
	@if [ -f "$(MODULE_LUA_WASM_ARCHIVE)" ] && [ -f "$(MODULE_LUA_LIBLUA_WASM_ARCHIVE)" ]; then \
		echo "Using existing lua module wasm archives"; \
	else \
		echo "Missing lua module wasm archive(s)"; \
		$(MAKE) -C "$(MODULE_LUA_DIR)" wasm; \
	fi

$(MODULE_REGISTRY_SRC): FORCE | $(OUT_DIR)
	@echo "Generating module registry: $@ (USES_MODULE_LUA=$(USES_MODULE_LUA))"
	@{ \
		echo '#include "rl_module.h"'; \
		echo '#include <string.h>'; \
		echo ''; \
		if [ "$(USES_MODULE_LUA)" = "1" ]; then \
			echo 'extern const rl_module_api_t *rl_module_lua_get_api(void);'; \
		fi; \
		echo ''; \
		echo 'static const rl_module_entry_t g_example_modules[] = {'; \
		if [ "$(USES_MODULE_LUA)" = "1" ]; then \
			echo '    rl_module_register(lua),'; \
		fi; \
		echo '};'; \
		echo ''; \
		echo 'static const size_t g_example_module_count = sizeof(g_example_modules) / sizeof(g_example_modules[0]);'; \
		echo ''; \
		echo 'const rl_module_api_t *rl_module_lookup_registry(const char *name)'; \
		echo '{'; \
		echo '    size_t i = 0;'; \
		echo ''; \
		echo '    if (name == NULL || name[0] == 0) {'; \
		echo '        return NULL;'; \
		echo '    }'; \
		echo ''; \
		echo '    for (i = 0; i < g_example_module_count; i++) {'; \
		echo '        if (strcmp(name, g_example_modules[i].name) == 0 && g_example_modules[i].get_api_fn != NULL) {'; \
		echo '            return g_example_modules[i].get_api_fn();'; \
		echo '        }'; \
		echo '    }'; \
		echo ''; \
		echo '    return NULL;'; \
		echo '}'; \
	} > $@

$(BIN): $(SRC) $(MODULE_REGISTRY_SRC) $(MODULE_DESKTOP_ARCHIVES) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(MODULE_REGISTRY_SRC) $(LIBS) -o $(BIN)

$(WASM_JS): $(SRC) $(MODULE_REGISTRY_SRC) $(MODULE_WASM_ARCHIVES) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(SRC) $(MODULE_REGISTRY_SRC) $(WASM_LIBS) $(LDFLAGS_WASM) -o $(WASM_JS)

$(WASM_DEBUG_JS): $(SRC) $(MODULE_REGISTRY_SRC) $(MODULE_WASM_ARCHIVES) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) wasm_archive
	@mkdir -p "$(EM_CACHE_DIR)"
	$(EM_ENV) $(CC_WASM) $(DEBUG_CFLAGS_WASM) $(INCLUDES) $(SRC) $(MODULE_REGISTRY_SRC) $(WASM_LIBS) $(DEBUG_SOURCEMAP_LDFLAGS_WASM) -o $(WASM_DEBUG_JS)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
	rm -rf $(CACHE_DIR)

FORCE:
