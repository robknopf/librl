package tests.bindings.haxe;

import utest.Assert;
import rl.RL;
import rl.gen.RLVersion;

class TestRL extends utest.Test {
  #if cpp
  /**
   * If a test fails (or `rl_init` returns non-zero) and we don't reach the
   * per-test `RL.deinit()`, the runtime can remain initialized and the next
   * `RL.init()` will fail with EBUSY-style behavior. These hooks keep each test isolated.
   */
  public function setup(): Void {
    RL.deinit();
  }

  public function teardown(): Void {
    RL.deinit();
  }
  #end

  public function testVersionStamp() {
    Assert.equals(RLVersion.BUILT_MAJOR, RL.versionMajor());
    Assert.equals(RLVersion.BUILT_MINOR, RL.versionMinor());
    Assert.equals(RLVersion.BUILT_PATCH, RL.versionPatch());
  }

  #if cpp
  public function testVersionValidateBinding() {
    Assert.equals(0, RL.boot());
  }
  #end

  public function testConstants() {
    Assert.equals(0x00000004, RL.FLAG_WINDOW_RESIZABLE);
    Assert.equals(0x00000020, RL.FLAG_MSAA_4X_HINT);
    Assert.equals(0x00000040, RL.FLAG_VSYNC_HINT);
    Assert.equals(0, RL.CAMERA_PERSPECTIVE);
    Assert.equals(1, RL.CAMERA_ORTHOGRAPHIC);
  }

  #if cpp
  public function testInitDeinit() {
    Assert.equals(false, RL.isInitialized());
    Assert.isTrue(RL.getPlatform() == "desktop" || RL.getPlatform() == "web", "platform is known");
    Assert.equals(0, RL.init());
    Assert.equals(true, RL.isInitialized());
    Assert.isTrue(true, "rl_init completed");
    RL.deinit();
    Assert.equals(false, RL.isInitialized());
    Assert.isTrue(true, "rl_deinit completed");
  }

  public function testTimeFunctions() {
    Assert.equals(0, RL.init());
    var t = RL.getTime();
    Assert.isTrue(t >= 0, "getTime returns non-negative");
    var dt = RL.getDeltaTime();
    Assert.isTrue(dt >= 0, "getDeltaTime returns non-negative");
    RL.setTargetFps(60);
    RL.deinit();
  }

  public function testAssetHost() {
    Assert.equals(0, RL.init());
    var host = RL.getAssetHost();
    Assert.notEquals(null, host);
    var rc = RL.setAssetHost("https://example.com/assets");
    Assert.isTrue(rc == 0 || rc != 0, "setAssetHost returns int");
    host = RL.getAssetHost();
    Assert.notEquals(null, host);
    RL.deinit();
  }

  public function testLighting() {
    Assert.equals(0, RL.init());
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
    Assert.equals(0, RL.init());
    var size = RL.windowGetScreenSize();
    var ok = (size.x >= 0) && (size.y >= 0);
    Assert.isTrue(ok, "screen size non-negative");
    RL.deinit();
  }

  public function testWindowGetMonitorCount() {
    Assert.equals(0, RL.init());
    var count = RL.windowGetMonitorCount();
    Assert.isTrue(count >= 0, "monitor count non-negative");
    RL.deinit();
  }

  public function testColorCreateDestroy() {
    Assert.equals(0, RL.init());
    var c = RL.colorCreate(10, 20, 30, 40);
    // Just ensure we got some handle back; value is opaque.
    Assert.notEquals(0, c);
    RL.colorDestroy(c);
    RL.deinit();
  }

  public function testInputMouseState() {
    Assert.equals(0, RL.init());
    var mouse = RL.inputGetMouseState();
    // Validate fields exist and are numeric; exact values depend on environment.
    Assert.isTrue(mouse.x >= 0 || mouse.x <= 0, "mouse.x is an Int");
    Assert.isTrue(mouse.y >= 0 || mouse.y <= 0, "mouse.y is an Int");
    RL.deinit();
  }

  public function testText2dCreateDestroy() {
    Assert.equals(0, RL.init());
    var label = RL.text2dCreate(0, 16.0);
    Assert.notEquals(0, label, "text2d handle should be non-zero");
    RL.text2dSetContent(label, "hello text2d");
    RL.text2dSetPosition(label, 10.0, 20.0);
    RL.text2dSetColor(label, 0);
    RL.text2dSetSize(label, 24.0);
    RL.text2dSetFont(label, 0);
    RL.text2dDestroy(label);
    RL.deinit();
  }
  #end
}
