/** Public façade: Model subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Model {

	public static function loadAsset(filename:String):RLHandle {
		return rl.impl.RLImpl.modelLoadAsset(filename);
	}

	public static function destroyAsset(asset:RLHandle):Void {
		rl.impl.RLImpl.modelDestroyAsset(asset);
	}

	public static function getDefaultAsset():RLHandle {
		return rl.impl.RLImpl.modelGetDefaultAsset();
	}

	public static function create(asset:RLHandle):RLHandle {
		return rl.impl.RLImpl.modelCreate(asset);
	}

	public static function createFromFile(filename:String):RLHandle {
		return rl.impl.RLImpl.modelCreateFromFile(filename);
	}

	public static function setAsset(model:RLHandle, asset:RLHandle):Bool {
		return rl.impl.RLImpl.modelSetAsset(model, asset);
	}

	public static function setTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool {
		return rl.impl.RLImpl.modelSetTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);
	}

	public static function draw(model:RLHandle, tint:RLHandle = 0):Void {
		rl.impl.RLImpl.modelDraw(model, tint);
	}

	public static function setAnimation(model:RLHandle, animationIndex:Int):Bool {
		return rl.impl.RLImpl.modelSetAnimation(model, animationIndex);
	}

	public static function setAnimationSpeed(model:RLHandle, speed:Float):Bool {
		return rl.impl.RLImpl.modelSetAnimationSpeed(model, speed);
	}

	public static function setAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool {
		return rl.impl.RLImpl.modelSetAnimationLoop(model, shouldLoop);
	}

	public static function setTint(model:RLHandle, color:RLHandle = 0):Bool {
		return rl.impl.RLImpl.modelSetTint(model, color);
	}

	public static function animate(model:RLHandle, deltaSeconds:Float):Bool {
		return rl.impl.RLImpl.modelAnimate(model, deltaSeconds);
	}

	public static function destroy(model:RLHandle):Void {
		rl.impl.RLImpl.modelDestroy(model);
	}

	public static function isValid(model:RLHandle):Bool {
		return rl.impl.RLImpl.modelIsValid(model);
	}

	public static function isValidStrict(model:RLHandle):Bool {
		return rl.impl.RLImpl.modelIsValidStrict(model);
	}

	public static function getAnimationCount(model:RLHandle):Int {
		return rl.impl.RLImpl.modelGetAnimationCount(model);
	}

	public static function getAnimationFrameCount(model:RLHandle, animationIndex:Int):Int {
		return rl.impl.RLImpl.modelGetAnimationFrameCount(model, animationIndex);
	}

	public static function updateAnimation(model:RLHandle, animationIndex:Int, frame:Int):Void {
		rl.impl.RLImpl.modelUpdateAnimation(model, animationIndex, frame);
	}
}
