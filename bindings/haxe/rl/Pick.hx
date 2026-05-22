/** Public façade: Pick subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Pick {

	public static function model(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult {
		return rl.impl.RLImpl.pickModel(camera, model, mouseX, mouseY);
	}

	public static function sprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult {
		return rl.impl.RLImpl.pickSprite3d(camera, sprite3d, mouseX, mouseY);
	}

	public static function resetStats():Void {
		rl.impl.RLImpl.pickResetStats();
	}

	public static function getBroadphaseTests():Int {
		return rl.impl.RLImpl.pickGetBroadphaseTests();
	}

	public static function getBroadphaseRejects():Int {
		return rl.impl.RLImpl.pickGetBroadphaseRejects();
	}

	public static function getNarrowphaseTests():Int {
		return rl.impl.RLImpl.pickGetNarrowphaseTests();
	}

	public static function getNarrowphaseHits():Int {
		return rl.impl.RLImpl.pickGetNarrowphaseHits();
	}
}
