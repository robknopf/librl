/** Minimal Emscripten module surface used by the RL binding wrapper. */
import type { RLGamepadState, RLKeyboardState, RLPickResult, RLTouchpoint } from "./types.js";

export interface EmscriptenModule {
  HEAP32: Int32Array;
  HEAPU32: Uint32Array;
  HEAPU8: Uint8Array;
  HEAPF32: Float32Array;
  ccall: (
    name: string,
    returnType: string | null,
    argTypes: string[],
    args: unknown[],
    opts?: { async?: boolean },
  ) => unknown;
  addFunction: (fn: (...args: unknown[]) => unknown, sig: string) => number;
  stackSave: () => number;
  stackRestore: (ptr: number) => void;
  stackAlloc: (size: number) => number;
  UTF8ToString: (ptr: number) => string;
  lengthBytesUTF8?: (str: string) => number;
  stringToUTF8?: (str: string, outPtr: number, maxBytes: number) => void;
  stringToNewUTF8?: (str: string) => number;
  malloc?: (size: number) => number;
  free?: (ptr: number) => void;
  removeFunction?: (ptr: number) => void;
  _malloc: (size: number) => number;
  _free: (ptr: number) => void;
  writeScratchStringTable: (values: string[]) => number;
  initScratchArea: () => void;
  getVector2: () => { x: number; y: number };
  getVector3: () => { x: number; y: number; z: number };
  getVector4: () => { x: number; y: number; z: number; w: number };
  getMatrix: () => Float32Array;
  getQuaternion: () => { x: number; y: number; z: number; w: number };
  getColor: () => { r: number; g: number; b: number; a: number };
  getRectangle: () => { x: number; y: number; width: number; height: number };
  getMouseState: () => {
    x: number;
    y: number;
    wheel: number;
    buttons: Int32Array;
  };
  getKeyboard: () => RLKeyboardState;
  getGamepads?: () => RLGamepadState[];
  getGamepad: (index: number) => RLGamepadState | null;
  getTouchpoints?: () => RLTouchpoint[];
  getTouchpoint: (index: number) => RLTouchpoint | null;
  getPickResult: () => RLPickResult;
  getSprite3dTransform: () => Record<string, unknown> | null;
  [key: string]: unknown;
}

export type EmscriptenFactory = (
  env?: Record<string, unknown>,
) => Promise<EmscriptenModule>;
