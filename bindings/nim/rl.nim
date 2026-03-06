type
  RLHandle* = uint32

const
  RL_GRAY* = RLHandle(2)
  RL_BLUE* = RLHandle(14)
  RL_BLACK* = RLHandle(23)
  RL_RAYWHITE* = RLHandle(26)
  RL_MODEL_DEFAULT* = RLHandle(0)
  RL_CAMERA_PERSPECTIVE* = 0.cint
  RL_CAMERA_ORTHOGRAPHIC* = 1.cint

proc rl_init*() {.importc, cdecl, header: "rl.h".}
proc rl_deinit*() {.importc, cdecl, header: "rl.h".}
proc rl_update*() {.importc, cdecl, header: "rl.h".}
proc rl_get_time*(): cdouble {.importc, cdecl, header: "rl.h".}
proc rl_init_window*(width: cint, height: cint, title: cstring) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_count*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_current_monitor*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_set_window_monitor*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position_x*(monitor: cint): cfloat {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position_y*(monitor: cint): cfloat {.importc, cdecl, header: "rl.h".}
proc rl_close_window*() {.importc, cdecl, header: "rl.h".}
proc rl_begin_drawing*() {.importc, cdecl, header: "rl.h".}
proc rl_end_drawing*() {.importc, cdecl, header: "rl.h".}
proc rl_begin_mode_3d*(
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  targetX: cfloat, targetY: cfloat, targetZ: cfloat,
  upX: cfloat, upY: cfloat, upZ: cfloat,
  fovy: cfloat, projection: cint
) {.importc, cdecl, header: "rl.h".}
proc rl_end_mode_3d*() {.importc, cdecl, header: "rl.h".}
proc rl_enable_lighting*() {.importc, cdecl, header: "rl.h".}
proc rl_disable_lighting*() {.importc, cdecl, header: "rl.h".}
proc rl_is_lighting_enabled*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_set_light_direction*(x: cfloat, y: cfloat, z: cfloat) {.importc, cdecl, header: "rl.h".}
proc rl_set_light_ambient*(ambient: cfloat) {.importc, cdecl, header: "rl.h".}
proc rl_draw_cube*(
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  width: cfloat, height: cfloat, length: cfloat,
  color: RLHandle
) {.importc, cdecl, header: "rl.h".}
proc rl_clear_background*(color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_set_target_fps*(fps: cint) {.importc, cdecl, header: "rl.h".}
proc rl_draw_text*(text: cstring, x: cint, y: cint, fontSize: cint, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_draw_text_ex*(font: RLHandle, text: cstring, x: cint, y: cint, fontSize: cfloat, spacing: cfloat, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_draw_fps_ex*(font: RLHandle, x: cint, y: cint, fontSize: cint, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_font_create*(filename: cstring, fontSize: cfloat): RLHandle {.importc, cdecl, header: "rl_font.h".}
proc rl_model_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_model.h".}
proc rl_model_get_default*(): RLHandle {.importc, cdecl, header: "rl_model.h".}
proc rl_model_draw*(model: RLHandle, x: cfloat, y: cfloat, z: cfloat, scale: cfloat, tint: RLHandle) {.importc, cdecl, header: "rl_model.h".}
proc rl_model_is_valid*(model: RLHandle): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_is_valid_strict*(model: RLHandle): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animation_count*(model: RLHandle): cint {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animation_frame_count*(model: RLHandle, animationIndex: cint): cint {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animation_update*(model: RLHandle, animationIndex: cint, frame: cint) {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation*(model: RLHandle, animationIndex: cint): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation_speed*(model: RLHandle, speed: cfloat): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_set_animation_loop*(model: RLHandle, shouldLoop: bool): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_animate*(model: RLHandle, deltaSeconds: cfloat): bool {.importc, cdecl, header: "rl_model.h".}
proc rl_model_destroy*(model: RLHandle) {.importc, cdecl, header: "rl_model.h".}
