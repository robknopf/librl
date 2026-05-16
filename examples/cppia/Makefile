# Build the cppia host from this directory.
# Run: make (or make all) from examples/cppia.

.PHONY: all build clean main_script

all: main_script build

build:
	haxe build.hxml

main_script:
	haxe compile.script.hxml MainScript

clean:
	rm -rf out
	rm -rf cache
