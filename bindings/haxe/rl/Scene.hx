/** Public façade: Scene subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLScenePickResult;

@:keep
class Scene {

	public static function create():RLHandle {
		return rl.impl.RLImpl.sceneCreate();
	}

	public static function destroy(scene:RLHandle):Void {
		rl.impl.RLImpl.sceneDestroy(scene);
	}

	public static function add(scene:RLHandle, drawable:RLHandle, layer:Int = 0):Bool {
		return rl.impl.RLImpl.sceneAdd(scene, drawable, layer);
	}

	public static function setLayer(scene:RLHandle, drawable:RLHandle, layer:Int):Bool {
		return rl.impl.RLImpl.sceneSetLayer(scene, drawable, layer);
	}

	public static function remove(scene:RLHandle, drawable:RLHandle):Bool {
		return rl.impl.RLImpl.sceneRemove(scene, drawable);
	}

	public static function clear(scene:RLHandle):Void {
		rl.impl.RLImpl.sceneClear(scene);
	}

	public static function setActiveCamera(scene:RLHandle, camera:RLHandle):Void {
		rl.impl.RLImpl.sceneSetActiveCamera(scene, camera);
	}

	public static function draw(scene:RLHandle):Void {
		rl.impl.RLImpl.sceneDraw(scene);
	}

	public static function pick(scene:RLHandle, camera:RLHandle, mouseX:Float, mouseY:Float):RLScenePickResult {
		return rl.impl.RLImpl.scenePick(scene, camera, mouseX, mouseY);
	}
}
