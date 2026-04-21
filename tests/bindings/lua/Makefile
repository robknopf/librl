ROOT_DIR ?= $(abspath ../../..)
CC ?= gcc

LIBLUA_ROOT ?= $(ROOT_DIR)/modules/lua/deps/liblua
LIBLUA_INC ?= $(LIBLUA_ROOT)/include
LIBLUA_ARCHIVE ?= $(LIBLUA_ROOT)/lib/liblua.a

CFLAGS ?= -Wall -Wextra -O2
TEST_BIN := test_rl_lua
TEST_SRC := test_lua_bindings.c
LUA_BINDINGS_SRC := $(ROOT_DIR)/bindings/lua/lua_rl.c

.PHONY: test build clean

test: build
	@./$(TEST_BIN)
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

clean:
	rm -rf $(TEST_BIN)
