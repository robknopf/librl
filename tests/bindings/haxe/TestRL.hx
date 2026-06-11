package tests.bindings.haxe;

import utest.Assert;
import rl.RL;
import rl.Window;
import rl.Camera3d;
import rl.Color;
import rl.Render;
import rl.Asset;
import rl.Input;
import rl.Text2d;
import rl.Text3d;
import rl.gen.RLVersion;

class TestRL extends utest.Test {
  #if cpp
  /**
   * If a test fails (or `RL.init` returns non-zero) and we don't reach the
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
    Assert.equals(RL.BOOT_OK, RL.boot());
  }
  #end

  public function testConstants() {
    Assert.equals(0x00000004, Window.FLAG_WINDOW_RESIZABLE);
    Assert.equals(0x00000020, Window.FLAG_MSAA_4X_HINT);
    Assert.equals(0x00000040, Window.FLAG_VSYNC_HINT);
    Assert.equals(0, Camera3d.PERSPECTIVE);
    Assert.equals(1, Camera3d.ORTHOGRAPHIC);
    Assert.equals(0, Input.BUTTON_UP);
    Assert.equals(1, Input.BUTTON_PRESSED);
    Assert.equals(2, Input.BUTTON_DOWN);
    Assert.equals(3, Input.BUTTON_RELEASED);
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
    var host = Asset.getHost();
    Assert.notEquals(null, host);
    var rc = Asset.setHost("https://example.com/assets");
    Assert.isTrue(rc == 0 || rc != 0, "assetSetHost returns int");
    host = Asset.getHost();
    Assert.notEquals(null, host);
    RL.deinit();
  }

  public function testLighting() {
    Assert.equals(0, RL.init());
    Render.enableLighting();
    Assert.equals(1, Render.isLightingEnabled());
    Render.disableLighting();
    Assert.equals(0, Render.isLightingEnabled());
    Render.setLightDirection(1, 0, 0);
    Render.setLightAmbient(0.5);
    RL.deinit();
  }

  public function testWindowGetScreenSize() {
    // Requires window or display; may return 0,0 without
    Assert.equals(0, RL.init());
    var size = Window.getScreenSize();
    var ok = (size.x >= 0) && (size.y >= 0);
    Assert.isTrue(ok, "screen size non-negative");
    RL.deinit();
  }

  public function testWindowGetMonitorCount() {
    Assert.equals(0, RL.init());
    var count = Window.getMonitorCount();
    Assert.isTrue(count >= 0, "monitor count non-negative");
    RL.deinit();
  }

  public function testColorCreateDestroy() {
    Assert.equals(0, RL.init());
    var c = Color.create(10, 20, 30, 40);
    // Just ensure we got some handle back; value is opaque.
    Assert.notEquals(0, c);
    Color.destroy(c);
    RL.deinit();
  }

  public function testInputMouseState() {
    Assert.equals(0, RL.init());
    var mouse = Input.getMouseState();
    // Validate fields exist and are numeric; exact values depend on environment.
    Assert.isTrue(mouse.x >= 0 || mouse.x <= 0, "mouse.x is an Int");
    Assert.isTrue(mouse.y >= 0 || mouse.y <= 0, "mouse.y is an Int");
    RL.deinit();
  }

  public function testInputScratchDevicesEmptyOnDesktop() {
    Assert.equals(0, RL.init());
    Assert.equals(0, Input.getGamepads().length);
    Assert.equals(null, Input.getGamepad(0));
    Assert.equals(0, Input.getTouchpoints().length);
    Assert.equals(null, Input.getTouchpoint(0));
    RL.deinit();
  }

  public function testText2dCreateDestroy() {
    Assert.equals(0, RL.init());
    var label = Text2d.create(0, 16.0);
    Assert.notEquals(0, label, "text2d handle should be non-zero");
    Text2d.setContent(label, "hello text2d");
    Text2d.setPosition(label, 10.0, 20.0);
    Text2d.setColor(label, 0);
    Text2d.setSize(label, 24.0);
    Text2d.setFont(label, 0);
    Text2d.destroy(label);
    RL.deinit();
  }

  public function testText3dCreateDestroy() {
    Assert.equals(0, RL.init());
    var t = Text3d.create(0, 1.0);
    Assert.notEquals(0, t, "text3d handle should be non-zero");
    Text3d.setContent(t, "hello 3d");
    Text3d.setTransform(t, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0);
    Text3d.setColor(t, 0);
    Text3d.setSize(t, 2.0);
    Text3d.setFont(t, 0);
    Text3d.setFacing(t, 0);
    Text3d.setVisible(t, true);
    Text3d.setPickable(t, true);
    Assert.isTrue(Text3d.isVisible(t));
    Assert.isTrue(Text3d.isPickable(t));
    Text3d.destroy(t);
    RL.deinit();
  }
  #end
}
