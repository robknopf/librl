/** Public façade: Debug subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Debug {

	public static function enableFps(x:Int, y:Int, fontSize:Int, font:RLHandle):Void {
		rl.impl.RLImpl.debugEnableFps(x, y, fontSize, font);
	}

	public static function disable():Void {
		rl.impl.RLImpl.debugDisable();
	}
}
