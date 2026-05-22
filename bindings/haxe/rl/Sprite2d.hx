/** Public façade: Sprite2d subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Sprite2d {


	public static function create(texture:RLHandle):RLHandle {
		return rl.impl.RLImpl.sprite2dCreate(texture);
	}

	public static function createFromFile(filename:String):RLHandle {
		return rl.impl.RLImpl.sprite2dCreateFromFile(filename);
	}

	public static function setTexture(sprite:RLHandle, texture:RLHandle):Bool {
		return rl.impl.RLImpl.sprite2dSetTexture(sprite, texture);
	}

	public static function setTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool {
		return rl.impl.RLImpl.sprite2dSetTransform(sprite, x, y, scale, rotation);
	}

	public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool {
		return rl.impl.RLImpl.sprite2dSetTint(sprite, color);
	}

	public static function draw(sprite:RLHandle, tint:RLHandle = 0):Void {
		rl.impl.RLImpl.sprite2dDraw(sprite, tint);
	}

	public static function destroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite2dDestroy(sprite);
	}

	public static function getDefaultTexture():RLHandle {
		return rl.impl.RLImpl.sprite2dGetDefaultTexture();
	}
}
