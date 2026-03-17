# Build the cppia host from this directory.
# Run: make (or make all) from examples/cppia.

.PHONY: all build clean test_script

all: test_script build

build:
	haxe compile.hxml

test_script:
	cd ../www/public/assets/scripts/haxe && haxe compile.hxml

clean:
	rm -rf out
	rm -rf cache
