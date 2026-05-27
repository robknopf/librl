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

	public static function setVisible(sprite:RLHandle, visible:Bool):Bool {
		return rl.impl.RLImpl.sprite2dSetVisible(sprite, visible);
	}

	public static function setPickable(sprite:RLHandle, pickable:Bool):Bool {
		return rl.impl.RLImpl.sprite2dSetPickable(sprite, pickable);
	}

	public static function isVisible(sprite:RLHandle):Bool {
		return rl.impl.RLImpl.sprite2dIsVisible(sprite);
	}

	public static function isPickable(sprite:RLHandle):Bool {
		return rl.impl.RLImpl.sprite2dIsPickable(sprite);
	}

	public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool {
		return rl.impl.RLImpl.sprite2dSetTint(sprite, color);
	}

	public static function draw(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite2dDraw(sprite);
	}

	public static function destroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite2dDestroy(sprite);
	}

	public static function getDefaultTexture():RLHandle {
		return rl.impl.RLImpl.sprite2dGetDefaultTexture();
	}
}
