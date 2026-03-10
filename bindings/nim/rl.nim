type
  RLHandle* = uint32
  Vec2* {.importc: "vec2_t", header: "rl.h", bycopy.} = object
    x*: cfloat
    y*: cfloat
  Vec3* {.importc: "vec3_t", header: "rl.h", bycopy.} = object
    x*: cfloat
    y*: cfloat
    z*: cfloat
  RLPickResult* {.importc: "rl_pick_result_t", header: "rl_pick.h", bycopy.} = object
    hit*: bool
    distance*: cfloat
    point*: Vec3
    normal*: Vec3
  RLMouseState* {.importc: "rl_mouse_state_t", header: "rl.h", bycopy.} = object
    x*: cint
    y*: cint
    wheel*: cint
    left*: cint
    right*: cint
    middle*: cint
  RLKeyboardState* {.importc: "rl_keyboard_state_t", header: "rl.h", bycopy.} = object
    max_num_keys*: cint
    keys*: array[512, cint]
    last_key*: cint
    last_char*: cint

const
  RL_GRAY* = RLHandle(2)
  RL_BLUE* = RLHandle(14)
  RL_BLACK* = RLHandle(23)
  RL_RAYWHITE* = RLHandle(26)
  RL_CAMERA_PERSPECTIVE* = 0.cint
  RL_CAMERA_ORTHOGRAPHIC* = 1.cint
  RL_FLAG_MSAA_4X_HINT* = 32.cint
  RL_BUTTON_UP* = 0.cint
  RL_BUTTON_PRESSED* = 1.cint
  RL_BUTTON_DOWN* = 2.cint
  RL_BUTTON_RELEASED* = 3.cint

proc rl_init*() {.importc, cdecl, header: "rl.h".}
proc rl_deinit*() {.importc, cdecl, header: "rl.h".}
proc rl_set_asset_host*(assetHost: cstring): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_asset_host*(): cstring {.importc, cdecl, header: "rl.h".}
proc rl_update*() {.importc, cdecl, header: "rl.h".}
proc rl_get_time*(): cdouble {.importc, cdecl, header: "rl.h".}
proc rl_init_window*(width: cint, height: cint, title: cstring, flags: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_count*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_current_monitor*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_set_window_monitor*(monitor: cint) {.importc, cdecl, header: "rl.h".}
proc rl_get_screen_size*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_get_monitor_position*(monitor: cint): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_get_window_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_position*(): Vec2 {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_wheel*(): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_button*(button: cint): cint {.importc, cdecl, header: "rl.h".}
proc rl_get_mouse_state*(): RLMouseState {.importc, cdecl, header: "rl.h".}
proc rl_get_keyboard_state*(): RLKeyboardState {.importc, cdecl, header: "rl.h".}
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
proc rl_measure_text_ex*(font: RLHandle, text: cstring, fontSize: cfloat, spacing: cfloat): Vec2 {.importc, cdecl, header: "rl.h".}
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
proc rl_pick_model*(
  camera: RLHandle,
  model: RLHandle,
  mouseX: cfloat,
  mouseY: cfloat,
  positionX: cfloat,
  positionY: cfloat,
  positionZ: cfloat,
  scale: cfloat
): RLPickResult {.importc, cdecl, header: "rl_pick.h".}
proc rl_pick_sprite3d*(
  camera: RLHandle,
  sprite3d: RLHandle,
  mouseX: cfloat,
  mouseY: cfloat,
  positionX: cfloat,
  positionY: cfloat,
  positionZ: cfloat,
  size: cfloat
): RLPickResult {.importc, cdecl, header: "rl_pick.h".}
proc rl_music_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_music.h".}
proc rl_music_destroy*(music: RLHandle) {.importc, cdecl, header: "rl_music.h".}
proc rl_music_play*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_pause*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_stop*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_set_loop*(music: RLHandle, shouldLoop: bool): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_set_volume*(music: RLHandle, volume: cfloat): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_is_playing*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_update*(music: RLHandle): bool {.importc, cdecl, header: "rl_music.h".}
proc rl_music_update_all*() {.importc, cdecl, header: "rl_music.h".}
proc rl_sound_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_destroy*(sound: RLHandle) {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_play*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_pause*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_resume*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_stop*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_volume*(sound: RLHandle, volume: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_pitch*(sound: RLHandle, pitch: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_set_pan*(sound: RLHandle, pan: cfloat): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_sound_is_playing*(sound: RLHandle): bool {.importc, cdecl, header: "rl_sound.h".}
proc rl_texture_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_texture.h".}
proc rl_texture_destroy*(texture: RLHandle) {.importc, cdecl, header: "rl_texture.h".}
proc rl_sprite3d_create*(filename: cstring): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_create_from_texture*(texture: RLHandle): RLHandle {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_draw*(sprite: RLHandle, x: cfloat, y: cfloat, z: cfloat, size: cfloat, tint: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
proc rl_sprite3d_destroy*(sprite: RLHandle) {.importc, cdecl, header: "rl_sprite3d.h".}
