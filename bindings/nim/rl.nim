type
  RLHandle* = uint32
  Vec2* {.importc: "vec2_t", header: "rl.h", bycopy.} = object
    x*: cfloat
    y*: cfloat
  RLMouse* = object
    x*: cint
    y*: cint
    wheel*: cint
    left*: cint
    right*: cint
    middle*: cint

const
  RL_GRAY* = RLHandle(2)
  RL_BLUE* = RLHandle(14)
  RL_BLACK* = RLHandle(23)
  RL_RAYWHITE* = RLHandle(26)
  RL_CAMERA_PERSPECTIVE* = 0.cint
  RL_CAMERA_ORTHOGRAPHIC* = 1.cint

proc rl_init*() {.importc, cdecl, header: "rl.h".}
proc rl_deinit*() {.importc, cdecl, header: "rl.h".}
proc rl_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_asset_host*(): cstring {.importc, cdecl, header: "rl.h".}
proc rl_update*() {.importc, cdecl, header: "rl.h".}
proc rl_get_time*(): cdouble {.importc, cdecl, header: "rl.h".}
proc rl_init_window*(width: cint, height: cint, title: cstring) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_count*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_current_monitor*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_set_window_monitor*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_screen_width*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_screen_height*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position_x*(monitor: cint): cfloat {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position_y*(monitor: cint): cfloat {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse*() {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_x_raw*(): cfloat {.importc: "rl_get_mouse_x", cdecl, header: "rl.h".}
proc rl_get_mouse_y_raw*(): cfloat {.importc: "rl_get_mouse_y", cdecl, header: "rl.h".}
proc rl_get_mouse_wheel*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_button*(button: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_x*(): cint = cint(rl_get_mouse_x_raw())
proc rl_get_mouse_y*(): cint = cint(rl_get_mouse_y_raw())
proc rl_get_mouse_state*(): RLMouse =
  RLMouse(
    x: rl_get_mouse_x(),
    y: rl_get_mouse_y(),
    wheel: rl_get_mouse_wheel(),
    left: rl_get_mouse_button(0),
    right: rl_get_mouse_button(1),
    middle: rl_get_mouse_button(2)
  )
proc rl_close_window*() {.importc, cdecl, header: "rl.h".}
proc rl_begin_drawing*() {.importc, cdecl, header: "rl.h".}
proc rl_end_drawing*() {.importc, cdecl, header: "rl.h".}
proc rl_begin_mode_3d*() {.importc, cdecl, header: "rl.h".}
proc rl_end_mode_3d*() {.importc, cdecl, header: "rl.h".}
proc rl_camera3d_create*(
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  targetX: cfloat, targetY: cfloat, targetZ: cfloat,
  upX: cfloat, upY: cfloat, upZ: cfloat,
  fovy: cfloat, projection: cint
): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_get_default*(): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_set*(
  camera: RLHandle,
  positionX: cfloat, positionY: cfloat, positionZ: cfloat,
  targetX: cfloat, targetY: cfloat, targetZ: cfloat,
  upX: cfloat, upY: cfloat, upZ: cfloat,
  fovy: cfloat, projection: cint
): bool {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_set_active*(camera: RLHandle): bool {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_get_active*(): RLHandle {.importc, cdecl, header: "rl_camera3d.h".}
proc rl_camera3d_destroy*(camera: RLHandle) {.importc, cdecl, header: "rl_camera3d.h".}
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
proc rl_measure_text_ex_raw*(font: RLHandle, text: cstring, fontSize: cfloat, spacing: cfloat) {.importc: "rl_measure_text_ex", cdecl, header: "rl.h".}
proc rl_scratch_area_get_vector2*(): Vec2 {.importc, cdecl, header: "rl_scratch.h".}
proc rl_measure_text_ex*(font: RLHandle, text: cstring, fontSize: cfloat, spacing: cfloat): Vec2 =
  rl_measure_text_ex_raw(font, text, fontSize, spacing)
  rl_scratch_area_get_vector2()
proc rl_draw_fps_ex*(font: RLHandle, x: cint, y: cint, fontSize: cint, color: RLHandle) {.importc, cdecl, header: "rl.h".}
proc rl_color_create*(r: cint, g: cint, b: cint, a: cint): RLHandle {.importc, cdecl, header: "rl_color.h".}
proc rl_color_destroy*(color: RLHandle) {.importc, cdecl, header: "rl_color.h".}
proc rl_font_create*(filename: cstring, fontSize: cfloat): RLHandle {.importc, cdecl, header: "rl_font.h".}
proc rl_font_destroy*(font: RLHandle) {.importc, cdecl, header: "rl_font.h".}
proc rl_model_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_model.h".}
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
proc rl_texture_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_texture.h".}
proc rl_texture_destroy*(texture: RLHandle) {.importc, cdecl, header: "rl_texture.h".}
proc rl_sprite3d_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_create_from_texture*(texture: RLHandle): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_draw*(sprite: RLHandle, x: cfloat, y: cfloat, z: cfloat, size: cfloat, tint: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_destroy*(sprite: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
