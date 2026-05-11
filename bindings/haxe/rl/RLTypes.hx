package rl;

typedef RLInitConfig = {
  ?windowWidth: Int,
  ?windowHeight: Int,
  ?windowTitle: String,
  ?windowFlags: Int,
  ?assetHost: String,
  ?loaderCacheDir: String,
};

typedef RLVec2 = {
  var x: Float;
  var y: Float;
}

typedef RLMouseState = {
  var x: Int;
  var y: Int;
  var wheel: Int;
  var left: Int;
  var right: Int;
  var middle: Int;
}

class RLKeyboardState {
  public var max_num_keys: Int = 0;
  public var keys: Array<Int> = [];
  public var pressed_key: Int = 0;
  public var pressed_char: Int = 0;
  public var num_pressed_keys: Int = 0;
  public var pressed_keys: Array<Int> = [];
  public var num_pressed_chars: Int = 0;
  public var pressed_chars: Array<Int> = [];

  public function new() {}
}
