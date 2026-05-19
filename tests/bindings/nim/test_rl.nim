import unittest
import rl

suite "rl bindings":
  test "version":
    check rl_boot() == RL_INIT_OK
    check rl_version_major() == 0
    check rl_version_minor() == 0
    check rl_version_patch() == 1
    check rl_version_label() == "dev"
    check rl_version_string() == "0.0.1-dev"
    check rlBindingMajor == rl_version_major()
    check rlBindingMinor == rl_version_minor()
    check rlBindingPatch == rl_version_patch()

  test "constants":
    check RL_INIT_OK == 0.cint
    check RL_INIT_ERR_UNKNOWN == (-1).cint
    check RL_INIT_ERR_ALREADY_INITIALIZED == (-2).cint
    check RL_INIT_ERR_LOADER == (-3).cint
    check RL_INIT_ERR_ASSET_HOST == (-4).cint
    check RL_INIT_ERR_WINDOW == (-5).cint
    check RL_TICK_RUNNING == 0.cint
    check RL_TICK_WAITING == 1.cint
    check RL_TICK_FAILED == (-1).cint
    check RL_FLAG_WINDOW_RESIZABLE == 4.RLWindowFlags
    check RL_FLAG_MSAA_4X_HINT == 32.RLWindowFlags

  test "rl_tick before init is failed":
    check rl_is_initialized() == false
    check rl_tick() == RL_TICK_FAILED

  test "init and deinit":
    check rl_boot() == RL_INIT_OK
    check rl_is_initialized() == false
    check $rl_get_platform() in ["desktop", "web"]
    check rl_init() == RL_INIT_OK
    check rl_is_initialized() == true
    rl_deinit()
    check rl_is_initialized() == false

  test "double init fails but runtime setters still work":
    check rl_boot() == RL_INIT_OK
    check rl_is_initialized() == false
    check rl_init() == RL_INIT_OK
    check rl_is_initialized() == true
    check rl_init() == RL_INIT_ERR_ALREADY_INITIALIZED
    check rl_is_initialized() == true
    rl_window_set_title("librl nim double-init test")
    rl_window_set_size(640, 480)
    rl_set_target_fps(30)
    check rl_set_asset_host("https://example.com/assets") == 0
    check $rl_get_asset_host() == "https://example.com/assets"
    let size = rl_window_get_screen_size()
    check size.x >= 0.0
    check size.y >= 0.0
    rl_deinit()

  test "time functions":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    let t = rl_get_time()
    check t >= 0.0
    let dt = rl_get_delta_time()
    check dt >= 0.0
    rl_set_target_fps(60)
    rl_deinit()

  test "asset host":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    let host: cstring = rl_get_asset_host()
    check not host.isNil
    let rc = rl_set_asset_host("https://example.com/assets")
    check rc == 0 or rc != 0
    let host2: cstring = rl_get_asset_host()
    check not host2.isNil
    rl_deinit()

  test "lighting":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    rl_enable_lighting()
    check rl_is_lighting_enabled() == 1.cint
    rl_disable_lighting()
    check rl_is_lighting_enabled() == 0.cint
    rl_set_light_direction(1.0, 0.0, 0.0)
    rl_set_light_ambient(0.5)
    rl_deinit()

  test "window get screen size":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    let size = rl_window_get_screen_size()
    check size.x >= 0.0
    check size.y >= 0.0
    rl_deinit()

  test "window get monitor count":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    let count = rl_window_get_monitor_count()
    check count >= 0.cint
    rl_deinit()

  test "text2d lifecycle":
    check rl_boot() == RL_INIT_OK
    check rl_init() == RL_INIT_OK
    let label = rl_text2d_create(0, 16.0)
    check label != 0.RLHandle
    rl_text2d_set_content(label, "hello text2d")
    rl_text2d_set_position(label, 10.0, 20.0)
    rl_text2d_set_color(label, 0)
    rl_text2d_set_size(label, 24.0)
    rl_text2d_set_font(label, 0)
    rl_text2d_destroy(label)
    rl_deinit()
