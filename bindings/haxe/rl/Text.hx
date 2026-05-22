/** Public façade: Text subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Text {

	public static function draw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void {
		rl.impl.RLImpl.textDraw(text, x, y, fontSize, color);
	}

	public static function measure(text:String, fontSize:Int):Int {
		return rl.impl.RLImpl.textMeasure(text, fontSize);
	}

	public static function drawFps(x:Int, y:Int):Void {
		rl.impl.RLImpl.textDrawFps(x, y);
	}

	public static function drawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void {
		rl.impl.RLImpl.textDrawEx(font, text, x, y, fontSize, spacing, color);
	}

	public static function measureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2 {
		return rl.impl.RLImpl.textMeasureEx(font, text, fontSize, spacing);
	}

	public static function drawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void {
		rl.impl.RLImpl.textDrawFpsEx(font, x, y, fontSize, color);
	}
}
