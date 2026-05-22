/** Public façade: Input subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Input {

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
}
