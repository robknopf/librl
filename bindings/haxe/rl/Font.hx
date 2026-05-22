/** Public façade: Font subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Font {

	public static function create(filename:String, fontSize:Int):RLHandle {
		return rl.impl.RLImpl.fontCreate(filename, fontSize);
	}

	public static function destroy(font:RLHandle):Void {
		rl.impl.RLImpl.fontDestroy(font);
	}

	public static function getDefault():RLHandle {
		return rl.impl.RLImpl.fontGetDefault();
	}
}
