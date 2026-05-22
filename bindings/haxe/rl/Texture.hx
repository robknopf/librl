/** Public façade: Texture subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Texture {


	public static function create(filename:String):RLHandle {
		return rl.impl.RLImpl.textureCreate(filename);
	}

	public static function destroy(texture:RLHandle):Void {
		rl.impl.RLImpl.textureDestroy(texture);
	}

	public static function getDefault():RLHandle {
		return rl.impl.RLImpl.textureGetDefault();
	}

	public static function drawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void {
		rl.impl.RLImpl.textureDrawEx(texture, x, y, scale, rotation, tint);
	}

	public static function drawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float, tint:RLHandle):Void {
		rl.impl.RLImpl.textureDrawGround(texture, positionX, positionY, positionZ, width, length, tint);
	}
}
