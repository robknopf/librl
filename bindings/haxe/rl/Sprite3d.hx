/** Public façade: Sprite3d subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

import rl.Types.RLSprite3dTransform;

@:keep
class Sprite3d {

	public static function create(texture:RLHandle):RLHandle {
		return rl.impl.RLImpl.sprite3dCreate(texture);
	}

	public static function createFromFile(filename:String):RLHandle {
		return rl.impl.RLImpl.sprite3dCreateFromFile(filename);
	}

	public static function setTexture(sprite:RLHandle, texture:RLHandle):Bool {
		return rl.impl.RLImpl.sprite3dSetTexture(sprite, texture);
	}

	public static function setTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, size:Float):Bool {
		return rl.impl.RLImpl.sprite3dSetTransform(sprite, positionX, positionY, positionZ, size);
	}

	public static function getTransform(sprite:RLHandle):RLSprite3dTransform {
		return cast rl.impl.RLImpl.sprite3dGetTransform(sprite);
	}

	public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool {
		return rl.impl.RLImpl.sprite3dSetTint(sprite, color);
	}

	public static function draw(sprite:RLHandle, tint:RLHandle = 0):Void {
		rl.impl.RLImpl.sprite3dDraw(sprite, tint);
	}

	public static function destroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite3dDestroy(sprite);
	}

	public static function getDefaultTexture():RLHandle {
		return rl.impl.RLImpl.sprite3dGetDefaultTexture();
	}
}
