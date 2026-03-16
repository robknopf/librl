ROOT_DIR ?= $(abspath ../../..)
NIM ?= nim

.PHONY: test build clean

test: build
	@./test_rl
	@echo "Nim binding tests passed."

build:
	@$(MAKE) -C $(ROOT_DIR) desktop
	$(NIM) c \
		--passC:"-I$(ROOT_DIR)/include" \
		--passL:"$(ROOT_DIR)/lib/librl.a -lm -lpthread -ldl -lX11 -lcurl" \
		--path:"$(ROOT_DIR)/bindings/nim" \
		--out:test_rl \
		test_rl.nim

clean:
	rm -rf test_rl nimcache
