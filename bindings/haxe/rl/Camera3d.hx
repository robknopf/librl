/** Public façade: Camera3d subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Camera3d {

	public static inline var PERSPECTIVE:Int = rl.impl.RLImpl.CAMERA_PERSPECTIVE;
	public static inline var ORTHOGRAPHIC:Int = rl.impl.RLImpl.CAMERA_ORTHOGRAPHIC;

	public static function create(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle {
		return rl.impl.RLImpl.camera3dCreate(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);
	}

	public static function set(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool {
		return rl.impl.RLImpl.camera3dSet(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);
	}

	public static function setActive(camera:RLHandle):Bool {
		return rl.impl.RLImpl.camera3dSetActive(camera);
	}

	public static function destroy(camera:RLHandle):Void {
		rl.impl.RLImpl.camera3dDestroy(camera);
	}

	public static function getDefault():RLHandle {
		return rl.impl.RLImpl.camera3dGetDefault();
	}

	public static function getActive():RLHandle {
		return rl.impl.RLImpl.camera3dGetActive();
	}
}
