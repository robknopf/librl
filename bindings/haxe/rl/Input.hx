/** Public façade: Input subsystem. */
package rl;

import rl.Types.RLVec2;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLGamepad;
import rl.Types.RLTouchpoint;

@:keep
class Input {

	public static inline var BUTTON_UP:Int = rl.impl.RLImpl.BUTTON_UP;
	public static inline var BUTTON_PRESSED:Int = rl.impl.RLImpl.BUTTON_PRESSED;
	public static inline var BUTTON_DOWN:Int = rl.impl.RLImpl.BUTTON_DOWN;
	public static inline var BUTTON_RELEASED:Int = rl.impl.RLImpl.BUTTON_RELEASED;


	public static function pollEvents():Void {
		rl.impl.RLImpl.inputPollEvents();
	}

	public static function captureCursor():Void {
		rl.impl.RLImpl.inputCaptureCursor();
	}

	public static function releaseCursor():Void {
		rl.impl.RLImpl.inputReleaseCursor();
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

	public static function getGamepads():Array<RLGamepad> {
		return rl.impl.RLImpl.inputGetGamepads();
	}

	public static function getGamepad(id:Int):Null<RLGamepad> {
		return rl.impl.RLImpl.inputGetGamepad(id);
	}

	public static function getTouchpoints():Array<RLTouchpoint> {
		return rl.impl.RLImpl.inputGetTouchpoints();
	}

	public static function getTouchpoint(id:Int):Null<RLTouchpoint> {
		return rl.impl.RLImpl.inputGetTouchpoint(id);
	}
}
