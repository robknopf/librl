/** Public façade: Debug subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Debug {


	public static function enableFps(x:Int, y:Int, fontSize:Int, font:RLHandle):Void {
		rl.impl.RLImpl.debugEnableFps(x, y, fontSize, font);
	}

	public static function disableFps():Void {
		rl.impl.RLImpl.debugDisableFps();
	}
}
