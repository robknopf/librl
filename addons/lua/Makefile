LUA_ADDON_DIR := $(abspath .)
ROOT_DIR := $(abspath ../..)

LIBLUA_REPO ?= git@github.com:robknopf/liblua-builder.git
LIBLUA_ROOT ?= $(LUA_ADDON_DIR)/deps/liblua
LIBLUA_INC ?= $(LIBLUA_ROOT)/include
LIBLUA_WASM_ARCHIVE ?= $(LIBLUA_ROOT)/lib/liblua.wasm.a
LIBLUA_DESKTOP_ARCHIVE ?= $(LIBLUA_ROOT)/lib/liblua.a
CC ?= gcc
CC_WASM ?= emcc
AR ?= ar
EMAR ?= emar
CFLAGS ?= -Wall -Wextra -fdiagnostics-color=always -O2
CFLAGS_WASM ?= -DPLATFORM_WEB -O2

OUT_DIR := $(LUA_ADDON_DIR)/lib
OBJ_DIR := $(LUA_ADDON_DIR)/obj
OBJ_DESKTOP_DIR := $(OBJ_DIR)/desktop
OBJ_WASM_DIR := $(OBJ_DIR)/wasm
ADDON_IMPL_SRC := $(LUA_ADDON_DIR)/src/rl_lua_addon.c
ADDON_DESKTOP_OBJ := $(OBJ_DESKTOP_DIR)/rl_lua_addon.o
ADDON_WASM_OBJ := $(OBJ_WASM_DIR)/rl_lua_addon.o
ADDON_DESKTOP_LIB := $(OUT_DIR)/librl_lua.a
ADDON_WASM_LIB := $(OUT_DIR)/librl_lua.wasm.a
CORE_LIBRL_DESKTOP := $(ROOT_DIR)/lib/librl.a

ADDON_TEST_SRC := $(LUA_ADDON_DIR)/tests/lua_addon_test.c
ADDON_TEST_BIN := /tmp/rl_lua_addon_test

.PHONY: deps ensure_deps ensure_wasm_archive ensure_desktop_archive \
	print_liblua_root print_liblua_include print_liblua_wasm_archive print_liblua_desktop_archive \
	desktop wasm clean addon_test_desktop

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
		echo "Missing Lua dependency at $(LIBLUA_ROOT). Run 'make -C $(LUA_ADDON_DIR) deps' first."; \
		exit 1; \
	fi

ensure_wasm_archive: ensure_deps
	@if [ -f "$(LIBLUA_WASM_ARCHIVE)" ]; then \
		echo "Using existing lua wasm archive: $(LIBLUA_WASM_ARCHIVE)"; \
	else \
		echo "Missing lua wasm archive: $(LIBLUA_WASM_ARCHIVE)"; \
		$(MAKE) -C "$(LIBLUA_ROOT)" wasm; \
	fi

ensure_desktop_archive: ensure_deps
	@if [ -f "$(LIBLUA_DESKTOP_ARCHIVE)" ]; then \
		echo "Using existing lua desktop archive: $(LIBLUA_DESKTOP_ARCHIVE)"; \
	else \
		echo "Missing lua desktop archive: $(LIBLUA_DESKTOP_ARCHIVE)"; \
		$(MAKE) -C "$(LIBLUA_ROOT)" desktop; \
	fi

print_liblua_root:
	@echo "$(LIBLUA_ROOT)"

print_liblua_include:
	@echo "$(LIBLUA_INC)"

print_liblua_wasm_archive:
	@echo "$(LIBLUA_WASM_ARCHIVE)"

print_liblua_desktop_archive:
	@echo "$(LIBLUA_DESKTOP_ARCHIVE)"

$(OUT_DIR):
	@mkdir -p $(OUT_DIR)

$(OBJ_DESKTOP_DIR):
	@mkdir -p $(OBJ_DESKTOP_DIR)

$(OBJ_WASM_DIR):
	@mkdir -p $(OBJ_WASM_DIR)

$(ADDON_DESKTOP_OBJ): $(ADDON_IMPL_SRC) | $(OBJ_DESKTOP_DIR)
	$(CC) $(CFLAGS) -I$(ROOT_DIR)/include -I$(LUA_ADDON_DIR)/include -I$(LIBLUA_INC) -c $< -o $@

$(ADDON_WASM_OBJ): $(ADDON_IMPL_SRC) | $(OBJ_WASM_DIR)
	$(CC_WASM) $(CFLAGS_WASM) -I$(ROOT_DIR)/include -I$(LUA_ADDON_DIR)/include -I$(LIBLUA_INC) -c $< -o $@

desktop: ensure_desktop_archive $(ADDON_DESKTOP_OBJ) | $(OUT_DIR)
	$(AR) rcs $(ADDON_DESKTOP_LIB) $(ADDON_DESKTOP_OBJ)
	@echo "Built Lua addon desktop archive: $(ADDON_DESKTOP_LIB)"

wasm: ensure_wasm_archive $(ADDON_WASM_OBJ) | $(OUT_DIR)
	$(EMAR) rcs $(ADDON_WASM_LIB) $(ADDON_WASM_OBJ)
	@echo "Built Lua addon wasm archive: $(ADDON_WASM_LIB)"

addon_test_desktop: desktop
	@$(MAKE) -C $(ROOT_DIR) desktop
	$(CC) $(CFLAGS) -I$(ROOT_DIR)/include -I$(LUA_ADDON_DIR)/include -I$(LIBLUA_INC) \
		$(ADDON_TEST_SRC) $(CORE_LIBRL_DESKTOP) $(ADDON_DESKTOP_LIB) $(LIBLUA_DESKTOP_ARCHIVE) \
		-lm -ldl -o $(ADDON_TEST_BIN)
	@$(ADDON_TEST_BIN)

clean:
	rm -rf $(OUT_DIR) $(OBJ_DIR)
