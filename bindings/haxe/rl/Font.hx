/** Public façade: Font subsystem. */
package rl;

import rl.Types.RLHandle;

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
