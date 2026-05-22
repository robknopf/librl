/** Public façade: Render subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Render {


	public static function enableLighting():Void {
		rl.impl.RLImpl.enableLighting();
	}

	public static function disableLighting():Void {
		rl.impl.RLImpl.disableLighting();
	}

	public static function isLightingEnabled():Int {
		return rl.impl.RLImpl.isLightingEnabled();
	}

	public static function setLightDirection(x:Float, y:Float, z:Float):Void {
		rl.impl.RLImpl.setLightDirection(x, y, z);
	}

	public static function setLightAmbient(ambient:Float):Void {
		rl.impl.RLImpl.setLightAmbient(ambient);
	}

	public static function begin():Void {
		rl.impl.RLImpl.renderBegin();
	}

	public static function end():Void {
		rl.impl.RLImpl.renderEnd();
	}

	public static function clearBackground(color:RLHandle):Void {
		rl.impl.RLImpl.renderClearBackground(color);
	}

	public static function beginMode2D(camera:RLHandle):Void {
		rl.impl.RLImpl.renderBeginMode2D(camera);
	}

	public static function endMode2D():Void {
		rl.impl.RLImpl.renderEndMode2D();
	}

	public static function beginMode3d():Void {
		rl.impl.RLImpl.renderBeginMode3d();
	}

	public static function endMode3d():Void {
		rl.impl.RLImpl.renderEndMode3d();
	}
}
