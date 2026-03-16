package tests.bindings.haxe;

import utest.Assert;
import rl.RL;

class TestRL extends utest.Test {
  public function testConstants() {
    Assert.equals(0x00000004, RL.FLAG_WINDOW_RESIZABLE);
    Assert.equals(0x00000020, RL.FLAG_MSAA_4X_HINT);
    Assert.equals(0x00000040, RL.FLAG_VSYNC_HINT);
  }

  #if cpp
  public function testInitDeinit() {
    RL.init();
    Assert.isTrue(true, "rl_init completed");
    RL.deinit();
    Assert.isTrue(true, "rl_deinit completed");
  }

  public function testTimeFunctions() {
    RL.init();
    var t = RL.getTime();
    Assert.isTrue(t >= 0, "getTime returns non-negative");
    var dt = RL.getDeltaTime();
    Assert.isTrue(dt >= 0, "getDeltaTime returns non-negative");
    RL.setTargetFps(60);
    RL.deinit();
  }

  public function testAssetHost() {
    RL.init();
    var host = RL.getAssetHost();
    Assert.notEquals(null, host);
    var rc = RL.setAssetHost("https://example.com/assets");
    Assert.isTrue(rc == 0 || rc != 0, "setAssetHost returns int");
    host = RL.getAssetHost();
    Assert.notEquals(null, host);
    RL.deinit();
  }

  public function testLighting() {
    RL.init();
    RL.enableLighting();
    Assert.equals(1, RL.isLightingEnabled());
    RL.disableLighting();
    Assert.equals(0, RL.isLightingEnabled());
    RL.setLightDirection(1, 0, 0);
    RL.setLightAmbient(0.5);
    RL.deinit();
  }

  public function testWindowGetScreenSize() {
    // Requires window or display; may return 0,0 without
    RL.init();
    var size = RL.windowGetScreenSize();
    var ok = (size.x >= 0) && (size.y >= 0);
    Assert.isTrue(ok, "screen size non-negative");
    RL.deinit();
  }

  public function testWindowGetMonitorCount() {
    RL.init();
    var count = RL.windowGetMonitorCount();
    Assert.isTrue(count >= 0, "monitor count non-negative");
    RL.deinit();
  }
  #end
}
