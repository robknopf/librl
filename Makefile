# Helper function for recursive wildcard
rwildcard = $(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

# Compiler and flags
CC_WASM ?= emcc
CC_DESKTOP ?= gcc

# destination directories and names
LIBRL_ROOT ?= .
LIBRL_BASENAME = librl

# Raylib paths and names
LIBRAYLIB_REPO ?= git@github.com:robknopf/raylib-builder.git
LIBRAYLIB_ROOT ?= $(LIBRL_ROOT)/deps/libraylib
LIBRAYLIB_INC = $(LIBRAYLIB_ROOT)/include
LIBRAYLIB_LIB = $(LIBRAYLIB_ROOT)/lib
LIBRAYLIB_BASENAME = raylib
LIBRAYLIB_CUSTOM_CFLAGS = -Wno-unused-result
ifdef DEV
LIBRAYLIB_WASM_ARCHIVE = $(LIBRAYLIB_LIB)/libraylib_d.wasm.a
LIBRAYLIB_DESKTOP_ARCHIVE = $(LIBRAYLIB_ROOT)/obj/desktop/debug/libraylib.a
else
LIBRAYLIB_WASM_ARCHIVE = $(LIBRAYLIB_LIB)/libraylib.wasm.a
LIBRAYLIB_DESKTOP_ARCHIVE = $(LIBRAYLIB_ROOT)/obj/desktop/release/libraylib.a
endif

CFLAGS = -Wall -Wextra -fdiagnostics-color=always -Isrc

CFLAGS_WASM = \
	-DPLATFORM_WEB

LDFLAGS_WASM = \
	--post-js bindings/js/rl_scratch_area.js \
	--extern-post-js bindings/js/rl.js \
	--extern-post-js bindings/js/rl_module_export.js \
	-s WASM=1 \
	-lidbfs.js \
	-s USE_GLFW=3 \
	-s EXPORT_ES6=1 \
	-s FETCH \
	-s ASYNCIFY=1 \
	-s MODULARIZE=1 \
	-s INITIAL_MEMORY=67108864 \
	-s EXPORTED_RUNTIME_METHODS='["ccall", "cwrap"]' \
	-s ALLOW_MEMORY_GROWTH=1 \
	-s EXPORTED_FUNCTIONS='[ \
	"_rl_init", \
	"_rl_deinit", \
	"_rl_update", \
	"_rl_get_time", \
	"_rl_init_window", \
	"_rl_set_window_title", \
	"_rl_set_window_size", \
	"_rl_close_window", \
	"_rl_scratch_area_get", \
	"_rl_scratch_area_update", \
	"_rl_scratch_area_get_offsets", \
	"_rl_set_window_position", \
	"_rl_get_window_position", \
	"_rl_get_window_position_x", \
	"_rl_get_window_position_y", \
	"_rl_get_mouse", \
	"_rl_get_mouse_x", \
	"_rl_get_mouse_y", \
	"_rl_get_mouse_wheel", \
	"_rl_get_mouse_button", \
	"_rl_get_screen_width", \
	"_rl_get_screen_height", \
	"_rl_set_target_fps", \
	"_rl_begin_drawing", \
	"_rl_end_drawing", \
	"_rl_clear_background", \
	"_rl_begin_mode_2d", \
	"_rl_end_mode_2d", \
	"_rl_begin_mode_3d", \
	"_rl_end_mode_3d", \
	"_rl_camera3d_create", \
	"_rl_camera3d_get_default", \
	"_rl_camera3d_set", \
	"_rl_camera3d_set_active", \
	"_rl_camera3d_get_active", \
	"_rl_camera3d_destroy", \
	"_rl_enable_lighting", \
	"_rl_disable_lighting", \
	"_rl_is_lighting_enabled", \
	"_rl_set_light_direction", \
	"_rl_set_light_ambient", \
	"_rl_draw_cube", \
	"_rl_color_create", \
	"_rl_color_destroy", \
	"_rl_draw_text", \
	"_rl_draw_text_ex", \
	"_rl_draw_fps", \
	"_rl_draw_fps_ex", \
	"_RL_FONT_DEFAULT", \
	"_rl_font_get_default", \
	"_rl_font_create", \
	"_rl_font_destroy", \
	"_rl_model_create", \
	"_rl_model_draw", \
	"_rl_model_is_valid", \
	"_rl_model_is_valid_strict", \
	"_rl_model_animation_count", \
	"_rl_model_animation_frame_count", \
	"_rl_model_animation_update", \
	"_rl_model_set_animation", \
	"_rl_model_set_animation_speed", \
	"_rl_model_set_animation_loop", \
	"_rl_model_animate", \
	"_rl_model_destroy", \
	"_rl_texture_create", \
	"_rl_texture_destroy", \
	"_rl_sprite3d_create", \
	"_rl_sprite3d_create_from_texture", \
	"_rl_sprite3d_draw", \
	"_rl_sprite3d_destroy", \
	"_rl_measure_text", \
	"_rl_measure_text_ex" \
]'

CFLAGS_DESKTOP = -DPLATFORM_DESKTOP


# Development mode (can be overridden via command line)
ifdef DEV
CFLAGS += -DDEV -g -O0
LDFLAGS_WASM += -gsource-map -s ASSERTIONS=1
DEV_SUFFIX = _d
else
CFLAGS += -O2
LDFLAGS_WASM += -O3
DEV_SUFFIX =
endif



# included libraries
LIBRAYLIB_WASM_BASENAME = $(LIBRAYLIB_BASENAME)$(DEV_SUFFIX).wasm
LIBS_WASM = -L$(LIBRAYLIB_LIB) \
	-l$(LIBRAYLIB_WASM_BASENAME) -lm

# Source files
SRC_DIR = src
ALL_SRCS = $(call rwildcard,$(SRC_DIR)/,*.c)
TEST_SRCS = $(call rwildcard,$(SRC_DIR)/,*_test.c)
LIB_SRCS = $(filter-out $(TEST_SRCS), $(ALL_SRCS))

# Include and library paths
INCLUDES = -I. -I$(OUT_INC_DIR) -I$(LIBRAYLIB_INC) -I$(LIBRL_ROOT)/$(SRC_DIR)

# Object files
OBJ_BASE_DIR = obj
OBJ_WASM_DIR = $(OBJ_BASE_DIR)/wasm
OBJ_DESKTOP_DIR = $(OBJ_BASE_DIR)/desktop

# Find override files and base files
WASM_OVERRIDES = $(call rwildcard,$(SRC_DIR)/,*.wasm.c)
WASM_BASES = $(WASM_OVERRIDES:.wasm.c=.c)

# Filter sources
COMMON_SRCS = $(filter-out $(WASM_BASES), $(LIB_SRCS))  # Remove base files if overrides exist
WASM_SRCS = $(sort $(COMMON_SRCS) $(WASM_OVERRIDES))    # Deduplicate combined sources
DESKTOP_SRCS = $(sort $(filter-out $(WASM_OVERRIDES), $(LIB_SRCS))) # Deduplicate desktop sources
DESKTOP_OBJS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_DESKTOP_DIR)/%.o,$(DESKTOP_SRCS))
WASM_OBJS = $(patsubst $(SRC_DIR)/%.c,$(OBJ_WASM_DIR)/%.o,$(WASM_SRCS))

# Output directories
OUT_LIB_DIR = lib
OUT_INC_DIR = include
OUT_WASM ?= $(OUT_LIB_DIR)/$(LIBRL_BASENAME).js
OUT_WASM_ARCHIVE ?= $(OUT_LIB_DIR)/$(LIBRL_BASENAME)$(DEV_SUFFIX).wasm.a
OUT_DESKTOP ?= $(OUT_LIB_DIR)/$(LIBRL_BASENAME)$(DEV_SUFFIX).a

# Default target
all: ensure_deps wasm wasm_archive desktop

deps:
	@if [ ! -d "$(LIBRAYLIB_ROOT)" ]; then \
		echo "Cloning libraylib from $(LIBRAYLIB_REPO) into $(LIBRAYLIB_ROOT)"; \
		mkdir -p "$$(dirname "$(LIBRAYLIB_ROOT)")"; \
		git clone $(LIBRAYLIB_REPO) $(LIBRAYLIB_ROOT); \
	else \
		echo "Updating existing libraylib directory: $(LIBRAYLIB_ROOT)"; \
		git -C "$(LIBRAYLIB_ROOT)" pull --ff-only; \
	fi
	@if [ ! -f "$(LIBRAYLIB_ROOT)/Makefile" ]; then \
		echo "Error: $(LIBRAYLIB_ROOT) exists but does not look like raylib-builder output."; \
		exit 1; \
	fi
	@echo "Running make in $(LIBRAYLIB_ROOT)"
	@$(MAKE) -C "$(LIBRAYLIB_ROOT)" DEV=$(DEV) CUSTOM_CFLAGS="$(LIBRAYLIB_CUSTOM_CFLAGS)"

ensure_deps:
	@if [ ! -f "$(LIBRAYLIB_ROOT)/Makefile" ]; then \
		echo "Missing dependencies at $(LIBRAYLIB_ROOT). Run 'make deps' first."; \
		exit 1; \
	fi

libraylib_wasm: ensure_deps
	@if [ -f "$(LIBRAYLIB_WASM_ARCHIVE)" ]; then \
		echo "Using existing raylib wasm archive: $(LIBRAYLIB_WASM_ARCHIVE)"; \
	else \
		echo "Missing raylib wasm archive: $(LIBRAYLIB_WASM_ARCHIVE)"; \
		$(MAKE) -C $(LIBRAYLIB_ROOT) DEV=$(DEV) CUSTOM_CFLAGS="$(LIBRAYLIB_CUSTOM_CFLAGS)" wasm; \
	fi

libraylib_desktop: ensure_deps
	@if [ -f "$(LIBRAYLIB_DESKTOP_ARCHIVE)" ]; then \
		echo "Using existing raylib desktop archive: $(LIBRAYLIB_DESKTOP_ARCHIVE)"; \
	else \
		echo "Missing raylib desktop archive: $(LIBRAYLIB_DESKTOP_ARCHIVE)"; \
		$(MAKE) -C $(LIBRAYLIB_ROOT) DEV=$(DEV) CUSTOM_CFLAGS="$(LIBRAYLIB_CUSTOM_CFLAGS)" desktop; \
	fi

# WebAssembly static build
wasm: libraylib_wasm ensure_out_dir
	$(info Building WASM with sources: $(WASM_SRCS))
	$(info LDFLAGS_WASM: $(LDFLAGS_WASM))
	$(info CFLAGS: $(CFLAGS))
	$(CC_WASM) -o $(OUT_WASM) $(WASM_SRCS) $(LDFLAGS_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) $(LIBS_WASM)

# WebAssembly static library build
wasm_archive: libraylib_wasm ensure_out_dir ensure_obj_dir $(WASM_OBJS)
	$(info Building WASM archive with objects: $(WASM_OBJS))
	$(info Adding raylib wasm archive: $(LIBRAYLIB_WASM_ARCHIVE))
	@test -f "$(LIBRAYLIB_WASM_ARCHIVE)" || (echo "Missing raylib wasm archive: $(LIBRAYLIB_WASM_ARCHIVE)" && exit 1)
	rm -rf $(OBJ_WASM_DIR)/.raylib_unpack
	mkdir -p $(OBJ_WASM_DIR)/.raylib_unpack
	cd $(OBJ_WASM_DIR)/.raylib_unpack && emar x $(abspath $(LIBRAYLIB_WASM_ARCHIVE))
	emar rcs $(OUT_WASM_ARCHIVE) $(WASM_OBJS) $(OBJ_WASM_DIR)/.raylib_unpack/*.o

# Desktop static library build
desktop: libraylib_desktop ensure_out_dir ensure_obj_dir $(DESKTOP_OBJS)
	$(info Building Desktop (static) with sources: $(DESKTOP_SRCS))
	$(info Adding raylib archive: $(LIBRAYLIB_DESKTOP_ARCHIVE))
	@test -f "$(LIBRAYLIB_DESKTOP_ARCHIVE)" || (echo "Missing raylib archive: $(LIBRAYLIB_DESKTOP_ARCHIVE)" && exit 1)
	rm -rf $(OBJ_DESKTOP_DIR)/.raylib_unpack
	mkdir -p $(OBJ_DESKTOP_DIR)/.raylib_unpack
	cd $(OBJ_DESKTOP_DIR)/.raylib_unpack && ar x $(abspath $(LIBRAYLIB_DESKTOP_ARCHIVE))
	ar rcs $(OUT_DESKTOP) $(DESKTOP_OBJS) $(OBJ_DESKTOP_DIR)/.raylib_unpack/*.o

uri_test:
	$(CC_DESKTOP) $(CFLAGS) $(INCLUDES) src/uri/uri_test.c src/uri/uri.c src/vendor/cwalk/cwalk.c -o /tmp/uri_test
	/tmp/uri_test

# Compile Desktop source files to object files
$(OBJ_DESKTOP_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC_DESKTOP) $(CFLAGS_DESKTOP) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Compile WASM source files to object files
$(OBJ_WASM_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC_WASM) $(CFLAGS_WASM) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Ensure the output directory exists
ensure_out_dir:
	mkdir -p $(OUT_LIB_DIR)
	mkdir -p $(OUT_INC_DIR)

# Ensure the object directory exists
ensure_obj_dir:
	mkdir -p $(OBJ_DESKTOP_DIR)
	mkdir -p $(OBJ_WASM_DIR)

# Clean up
clean:
	rm -rf $(OUT_LIB_DIR)
	rm -rf $(OBJ_BASE_DIR)
#	@$(MAKE) -C $(LIBRAYLIB_ROOT) clean


.PHONY: all deps ensure_deps clean ensure_out_dir ensure_obj_dir libraylib_wasm libraylib_desktop wasm wasm_archive desktop
# 	"_RL_COLOR_BLACK", \
# 	"_RL_COLOR_BLANK", \
# 	"_RL_COLOR_MAGENTA", \
# 	"_RL_COLOR_RAYWHITE", \
