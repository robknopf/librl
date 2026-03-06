# API Reference (Draft)

This document summarizes the current public C API exposed by `include/*.h`.

## Conventions

- Most resource APIs use `rl_handle_t` (`unsigned int`) as an opaque handle.
- `0` is generally an invalid handle unless a subsystem documents otherwise.
- Call `rl_init()` before using subsystem APIs, and `rl_deinit()` at shutdown.

## Core (`include/rl.h`)

Main responsibilities:

- Runtime lifecycle (`rl_init`, `rl_deinit`)
- Window management (`rl_init_window`, size/position/title helpers)
- Frame lifecycle (`rl_begin_drawing`, `rl_end_drawing`, `rl_update`)
- Basic drawing (text, rectangles, cubes, fps helpers)
- 2D/3D mode switching
- Basic lighting toggles and parameters
- Timing helpers (`rl_get_time`)
- Text measurement helpers

Header note:

- `rl.h` is the primary/core header and defines shared base types (`rl_handle_t`, math/data structs) plus core runtime/window/draw APIs.
- For many integrations, including only `rl.h` is enough.
- If you need subsystem-specific APIs (model/font/color/loader/scratch), include their corresponding headers explicitly.

## Colors (`include/rl_color.h`)

Main responsibilities:

- Built-in color handles (e.g. `RL_COLOR_WHITE`, `RL_COLOR_BLACK`, etc.)
- Create/update/destroy runtime color handles
- Color subsystem lifecycle (`rl_color_init`, `rl_color_deinit`)

## Fonts (`include/rl_font.h`)

Main responsibilities:

- Font creation/destruction by filename + size
- Default font handle access
- Font subsystem lifecycle (`rl_font_init`, `rl_font_deinit`)

## Models (`include/rl_model.h`)

Main responsibilities:

- Model creation/destruction by filename
- Model draw
- Validity checks (`rl_model_is_valid`, `rl_model_is_valid_strict`)
- Animation clip/frame queries
- Animation control (`set_animation`, speed/loop, update/tick)
- Model subsystem lifecycle (`rl_model_init`, `rl_model_deinit`)

Notes:

- `rl_model_create()` requires a ready window/graphics context.
- On model load failure, the implementation substitutes a visible placeholder cube.

## Loader (`include/rl_loader.h`)

Main responsibilities:

- Loader subsystem init/deinit
- Shared backing for cross-platform asset loading and cache behavior

## Scratch Area (`include/rl_scratch.h`)

Main responsibilities:

- Shared memory struct for high-frequency data exchange with host runtimes:
  - vectors, matrices, quaternions, colors, rectangles
  - mouse/keyboard/gamepad/touch state
- Direct pointer access (`rl_scratch_area_get`)
- Layout metadata (`rl_scratch_area_get_offsets`) for JS/wasm interop
- Set/get helpers and update/clear functions

---


