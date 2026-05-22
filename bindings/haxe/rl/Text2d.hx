/** Public façade: Text2d subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Text2d {


	public static function create(font:RLHandle, size:Float):RLHandle {
		return rl.impl.RLImpl.text2dCreate(font, size);
	}

	public static function setFont(handle:RLHandle, font:RLHandle):Void {
		rl.impl.RLImpl.text2dSetFont(handle, font);
	}

	public static function setSize(handle:RLHandle, size:Float):Void {
		rl.impl.RLImpl.text2dSetSize(handle, size);
	}

	public static function setContent(handle:RLHandle, content:String):Void {
		rl.impl.RLImpl.text2dSetContent(handle, content);
	}

	public static function setPosition(handle:RLHandle, x:Float, y:Float):Void {
		rl.impl.RLImpl.text2dSetPosition(handle, x, y);
	}

	public static function setColor(handle:RLHandle, color:RLHandle):Void {
		rl.impl.RLImpl.text2dSetColor(handle, color);
	}

	public static function draw(handle:RLHandle):Void {
		rl.impl.RLImpl.text2dDraw(handle);
	}

	public static function destroy(handle:RLHandle):Void {
		rl.impl.RLImpl.text2dDestroy(handle);
	}
}
