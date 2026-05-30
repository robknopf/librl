/** Public façade: Sprite3d subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLSprite3dFacing;
import rl.Types.RLSprite3dTransform;

@:keep
class Sprite3d {
	public static inline var FACING_CAMERA:RLSprite3dFacing = RLSprite3dFacing.CAMERA;
	public static inline var FACING_CAMERA_FIXED_Y:RLSprite3dFacing = RLSprite3dFacing.CAMERA_FIXED_Y;
	public static inline var FACING_Y_UP:RLSprite3dFacing = RLSprite3dFacing.Y_UP;
	public static inline var FACING_FREE:RLSprite3dFacing = RLSprite3dFacing.FREE;



	public static function create(texture:RLHandle):RLHandle {
		return rl.impl.RLImpl.sprite3dCreate(texture);
	}

	public static function createFromFile(filename:String):RLHandle {
		return rl.impl.RLImpl.sprite3dCreateFromFile(filename);
	}

	public static function setTexture(sprite:RLHandle, texture:RLHandle):Bool {
		return rl.impl.RLImpl.sprite3dSetTexture(sprite, texture);
	}

	public static function setTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool {
		return rl.impl.RLImpl.sprite3dSetTransform(sprite, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);
	}

	public static function setVisible(sprite:RLHandle, visible:Bool):Bool {
		return rl.impl.RLImpl.sprite3dSetVisible(sprite, visible);
	}

	public static function setPickable(sprite:RLHandle, pickable:Bool):Bool {
		return rl.impl.RLImpl.sprite3dSetPickable(sprite, pickable);
	}

	public static function isVisible(sprite:RLHandle):Bool {
		return rl.impl.RLImpl.sprite3dIsVisible(sprite);
	}

	public static function isPickable(sprite:RLHandle):Bool {
		return rl.impl.RLImpl.sprite3dIsPickable(sprite);
	}

	public static function getTransform(sprite:RLHandle):RLSprite3dTransform {
		return rl.impl.RLImpl.sprite3dGetTransform(sprite);
	}

	public static function setSize(sprite:RLHandle, size:Float):Bool {
		return rl.impl.RLImpl.sprite3dSetSize(sprite, size);
	}

	public static function setFacing(sprite:RLHandle, facing:RLSprite3dFacing):Bool {
		return rl.impl.RLImpl.sprite3dSetFacing(sprite, facing);
	}

	public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool {
		return rl.impl.RLImpl.sprite3dSetTint(sprite, color);
	}

	public static function draw(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite3dDraw(sprite);
	}

	public static function destroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite3dDestroy(sprite);
	}

	public static function getDefaultTexture():RLHandle {
		return rl.impl.RLImpl.sprite3dGetDefaultTexture();
	}
}
