ROOT_DIR ?= $(abspath ../..)
LUA ?= $(shell command -v luajit 2>/dev/null || command -v lua5.1 2>/dev/null || command -v lua 2>/dev/null)

EXAMPLE_SCRIPT := boot.lua
LIBS_DIR := libs
RL_MODULE_SO := $(ROOT_DIR)/lib/rl.so
LIBRL_SHARED_SO := $(ROOT_DIR)/lib/librl.so

.PHONY: deps run clean

deps:
	@$(MAKE) -C $(ROOT_DIR) rl_lua
	@mkdir -p $(LIBS_DIR)
	@cp $(RL_MODULE_SO) $(LIBS_DIR)/rl.so
	@cp $(LIBRL_SHARED_SO) $(LIBS_DIR)/librl.so
	@echo "Staged Lua libs into $(LIBS_DIR)/"

run: deps
	@if [ -z "$(LUA)" ]; then \
		echo "Error: no Lua interpreter found (tried luajit, lua5.1, lua)"; \
		exit 1; \
	fi
	@"$(LUA)" "$(EXAMPLE_SCRIPT)"

clean:
	rm -rf $(LIBS_DIR)

