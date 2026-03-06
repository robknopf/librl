ROOT := ../../..
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

OUT_DIR := out
BIN := $(OUT_DIR)/main
SRC := main.c

INCLUDES := -I$(ROOT)/include -I$(ROOT)/deps/libraylib/include
LIBS := -L$(ROOT)/lib -lrl -lcurl -lm -lpthread -ldl -lX11

.PHONY: all build run clean

all: build

build: $(BIN)

$(BIN): $(SRC) | $(OUT_DIR)
	@$(MAKE) -C $(ROOT) desktop
	$(CC) $(CFLAGS) $(INCLUDES) $(SRC) $(LIBS) -o $(BIN)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

run: $(BIN)
	./$(BIN)

clean:
	rm -rf $(OUT_DIR)
