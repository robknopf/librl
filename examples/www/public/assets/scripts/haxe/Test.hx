package;

import CppiaBridge;

@:keepSub
class Test {
  static var elapsed: Float = 0.0;

  public static function main(): Void {
    // Register callbacks with the native host via CppiaBridge.
    CppiaBridge.onInit = init;
    CppiaBridge.onTick = tick;
    CppiaBridge.onShutdown = shutdown;
  }

  static function init(): Void {
    trace("cppia Test.init()");
  }

  static function tick(dt: Float): Void {
    elapsed += dt;
    if (Std.int(elapsed) % 1 == 0) {
      trace('cppia tick, elapsed=${elapsed}');
    }
  }

  static function shutdown(): Void {
    trace("cppia Test.shutdown()");
  }
}

