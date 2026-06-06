/** Byte offsets into the WASM scratch arena (from rl_scratch_get_offsets). */
export interface ScratchAreaOffsets {
  vector2: number;
  vector3: number;
  vector4: number;
  matrix: number;
  quaternion: number;
  color: number;
  rectangle: number;
  pickResult: {
    hit: number;
    handle: number;
    distance: number;
    point: number;
    normal: number;
  };
  mouse: {
    x: number;
    y: number;
    wheel: number;
    buttons: number;
    dx: number;
    dy: number;
  };
  keyboard: {
    max_num_keys: number;
    keys: number;
    pressed_key: number;
    pressed_char: number;
    num_pressed_keys: number;
    pressed_keys: number;
    num_pressed_chars: number;
    pressed_chars: number;
  };
  gamepads: {
    max_num_gamepads: number;
    gamepad: number;
    id: number;
    axis: number;
    buttons: number;
    stride: number;
  };
  touchpoints: {
    count: number;
    touchpoint: number;
    id: number;
    x: number;
    y: number;
    stride: number;
  };
  stringTable: {
    offsets: number;
    bytes: number;
    maxEntries: number;
    maxBytes: number;
  };
}
