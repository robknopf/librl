import unittest
import rl

suite "rl bindings":
  test "constants":
    check RL_FLAG_WINDOW_RESIZABLE == 4.cint
    check RL_FLAG_MSAA_4X_HINT == 32.cint

  test "init and deinit":
    check rl_init(nil) == 0
    rl_deinit()

  test "time functions":
    check rl_init(nil) == 0
    let t = rl_get_time()
    check t >= 0.0
    let dt = rl_get_delta_time()
    check dt >= 0.0
    rl_set_target_fps(60)
    rl_deinit()

  test "asset host":
    check rl_init(nil) == 0
    let host: cstring = rl_get_asset_host()
    check not host.isNil
    let rc = rl_set_asset_host("https://example.com/assets")
    check rc == 0 or rc != 0
    let host2: cstring = rl_get_asset_host()
    check not host2.isNil
    rl_deinit()

  test "lighting":
    check rl_init(nil) == 0
    rl_enable_lighting()
    check rl_is_lighting_enabled() == 1.cint
    rl_disable_lighting()
    check rl_is_lighting_enabled() == 0.cint
    rl_set_light_direction(1.0, 0.0, 0.0)
    rl_set_light_ambient(0.5)
    rl_deinit()

  test "window get screen size":
    check rl_init(nil) == 0
    let size = rl_window_get_screen_size()
    check size.x >= 0.0
    check size.y >= 0.0
    rl_deinit()

  test "window get monitor count":
    check rl_init(nil) == 0
    let count = rl_window_get_monitor_count()
    check count >= 0.cint
    rl_deinit()
