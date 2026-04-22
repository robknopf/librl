# Build the cppia host from this directory.
# Run: make (or make all) from examples/cppia.

.PHONY: all build clean test_script

all: test_script build

build:
	haxe build.hxml

test_script:
	cp export_classes.info ../www/public/assets/scripts/haxe
	cd ../www/public/assets/scripts/haxe && haxe compile.hxml

clean:
	rm -rf out
	rm -rf cache
