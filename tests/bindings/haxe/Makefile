ROOT_DIR ?= $(abspath ../../..)
HAXE ?= haxe

.PHONY: test build clean

test: build
	@./out/Main
	@echo "Haxe binding tests passed."

build:
	@$(MAKE) -C $(ROOT_DIR) desktop
	@$(HAXE) compile.hxml -D LIBRL_ROOT=$(ROOT_DIR)
	@test -f out/Main || test -f out/Main-debug || (echo "Build failed: executable not found" && exit 1)

clean:
	rm -rf out
