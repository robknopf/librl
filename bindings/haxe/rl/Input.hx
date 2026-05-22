/** Public façade: Input subsystem. */
package rl;

import rl.Types.RLGamepad;
import rl.Types.RLKeyboardState;
import rl.Types.RLMouseState;
import rl.Types.RLTouchpoint;
import rl.Types.RLVec2;

@:keep
class Input {

	public static inline var BUTTON_UP:Int = rl.impl.RLImpl.BUTTON_UP;
	public static inline var BUTTON_PRESSED:Int = rl.impl.RLImpl.BUTTON_PRESSED;
	public static inline var BUTTON_DOWN:Int = rl.impl.RLImpl.BUTTON_DOWN;
	public static inline var BUTTON_RELEASED:Int = rl.impl.RLImpl.BUTTON_RELEASED;

	public static function pollEvents():Void {
		rl.impl.RLImpl.inputPollEvents();
	}

	public static function getMousePosition():RLVec2 {
		return rl.impl.RLImpl.inputGetMousePosition();
	}

	public static function getMouseWheel():Int {
		return rl.impl.RLImpl.inputGetMouseWheel();
	}

	public static function getMouseButton(button:Int):Int {
		return rl.impl.RLImpl.inputGetMouseButton(button);
	}

	public static function getMouseState():RLMouseState {
		return rl.impl.RLImpl.inputGetMouseState();
	}

	public static function getKeyboardState():RLKeyboardState {
		return rl.impl.RLImpl.inputGetKeyboardState();
	}

	/**
	 * Scratch-backed gamepad snapshot (wasm/js). Returns an empty array on desktop/cpp.
	 * Call `RL.tick()` first so scratch input is refreshed.
	 */
	public static function getGamepads():Array<RLGamepad> {
		return rl.impl.RLImpl.inputGetGamepads();
	}

	/**
	 * Scratch-backed gamepad lookup by id (wasm/js). Returns null when unavailable.
	 * Call `RL.tick()` first so scratch input is refreshed.
	 */
	public static function getGamepad(id:Int):Null<RLGamepad> {
		return rl.impl.RLImpl.inputGetGamepad(id);
	}

	/**
	 * Scratch-backed touch snapshot (wasm/js). Returns an empty array on desktop/cpp.
	 * Call `RL.tick()` first so scratch input is refreshed.
	 */
	public static function getTouchpoints():Array<RLTouchpoint> {
		return rl.impl.RLImpl.inputGetTouchpoints();
	}

	/**
	 * Scratch-backed touch lookup by id (wasm/js). Returns null when unavailable.
	 * Call `RL.tick()` first so scratch input is refreshed.
	 */
	public static function getTouchpoint(id:Int):Null<RLTouchpoint> {
		return rl.impl.RLImpl.inputGetTouchpoint(id);
	}
}
