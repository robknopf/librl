ROOT_DIR ?= $(abspath ../../..)
CC ?= gcc
LUA ?= $(shell command -v lua5.1 2>/dev/null || command -v lua 2>/dev/null)

LIBLUA_ROOT ?= $(ROOT_DIR)/deps/liblua
LIBLUA_INC ?= $(LIBLUA_ROOT)/include
LIBLUA_ARCHIVE ?= $(LIBLUA_ROOT)/lib/liblua.a

CFLAGS ?= -Wall -Wextra -O2 -DRL_FRAME_BUFFER_INCLUDE_TYPE_TAG=1
TEST_BIN := test_rl_lua
TEST_SRC := test_lua_bindings.c
LUA_BINDINGS_SRC := $(wildcard $(ROOT_DIR)/bindings/lua/*.c)
SHARED_LIB := $(ROOT_DIR)/lib/librl.so
LUA_MODULE_SO := $(ROOT_DIR)/lib/rl.so

.PHONY: test build clean

test: build
	@./$(TEST_BIN)
	@$(MAKE) test_require
	@echo "Lua binding tests passed."

build:
	@if [ ! -f "$(LIBLUA_ARCHIVE)" ]; then \
		echo "Error: liblua not found at $(LIBLUA_ARCHIVE)"; \
		echo "Run 'make -C $(ROOT_DIR)/modules/lua deps' first."; \
		exit 1; \
	fi
	@$(MAKE) -C $(ROOT_DIR) desktop
	$(CC) $(CFLAGS) -o $(TEST_BIN) \
		$(TEST_SRC) $(LUA_BINDINGS_SRC) \
		-I$(ROOT_DIR)/include \
		-I$(ROOT_DIR)/deps/wgutils/include \
		-I$(LIBLUA_INC) \
		$(ROOT_DIR)/lib/librl.a $(LIBLUA_ARCHIVE) \
		-lm -ldl -lpthread -lX11 -lcurl -lssl -lcrypto -lz

test_require:
	@if [ -z "$(LUA)" ]; then \
		echo "Error: no Lua interpreter found (tried lua5.1, lua)"; \
		exit 1; \
	fi
	@$(MAKE) -C $(ROOT_DIR) rl_lua LIBLUA_INC="$(LIBLUA_INC)"
	@LD_LIBRARY_PATH="$(ROOT_DIR)/lib:$$LD_LIBRARY_PATH" "$(LUA)" "$(ROOT_DIR)/tests/bindings/lua/test_bindings.lua" "$(LUA_MODULE_SO)"

clean:
	rm -rf $(TEST_BIN)
