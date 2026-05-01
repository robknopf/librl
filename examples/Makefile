ROOT := ..
HAXE ?= haxe
NIM ?= nim

.PHONY: all desktop wasm clean \
	c-simple c-simple-desktop c-simple-wasm \
	c-lua c-lua-desktop c-lua-wasm \
	remote remote-desktop remote-wasm \
	haxe haxe-desktop haxe-wasm \
	nim nim-desktop nim-wasm \
	cppia cppia-desktop cppia-script \
	lua

all: desktop wasm

desktop: c-simple-desktop c-lua-desktop remote-desktop haxe-desktop nim-desktop cppia-desktop lua

wasm: c-simple-wasm c-lua-wasm remote-wasm haxe-wasm nim-wasm

c-simple: c-simple-desktop c-simple-wasm
c-simple-desktop:
	$(MAKE) -C c-simple desktop
c-simple-wasm:
	$(MAKE) -C c-simple wasm

c-lua: c-lua-desktop c-lua-wasm
c-lua-desktop:
	$(MAKE) -C c-lua desktop
c-lua-wasm:
	$(MAKE) -C c-lua wasm

remote: remote-desktop remote-wasm
remote-desktop:
	$(MAKE) -C remote desktop
remote-wasm:
	$(MAKE) -C remote wasm

haxe: haxe-desktop haxe-wasm
haxe-desktop:
	cd haxe && $(HAXE) build.desktop.hxml
haxe-wasm:
	cd haxe && $(HAXE) build.wasm.hxml

nim: nim-desktop nim-wasm
nim-desktop:
	cd nim && $(NIM) build desktop
nim-wasm:
	cd nim && $(NIM) build wasm

cppia: cppia-script cppia-desktop
cppia-desktop:
	$(MAKE) -C cppia build
cppia-script:
	$(MAKE) -C cppia test_script

lua:
	$(MAKE) -C lua deps

clean:
	$(MAKE) -C c-simple clean
	$(MAKE) -C c-lua clean
	$(MAKE) -C remote clean
	$(MAKE) -C cppia clean
	$(MAKE) -C lua clean
	cd haxe && rm -rf out cache
	cd nim && $(NIM) clean
