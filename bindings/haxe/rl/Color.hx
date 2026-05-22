/**
 * Color handles and named palette constants.
 */

package rl;

import rl.Types.RLHandle;

@:keep
class Color {
	public static var DEFAULT(get, never):RLHandle;
	static inline function get_DEFAULT():RLHandle return rl.impl.RLImpl.COLOR_DEFAULT;
	public static var LIGHTGRAY(get, never):RLHandle;
	static inline function get_LIGHTGRAY():RLHandle return rl.impl.RLImpl.COLOR_LIGHTGRAY;
	public static var GRAY(get, never):RLHandle;
	static inline function get_GRAY():RLHandle return rl.impl.RLImpl.COLOR_GRAY;
	public static var DARKGRAY(get, never):RLHandle;
	static inline function get_DARKGRAY():RLHandle return rl.impl.RLImpl.COLOR_DARKGRAY;
	public static var YELLOW(get, never):RLHandle;
	static inline function get_YELLOW():RLHandle return rl.impl.RLImpl.COLOR_YELLOW;
	public static var GOLD(get, never):RLHandle;
	static inline function get_GOLD():RLHandle return rl.impl.RLImpl.COLOR_GOLD;
	public static var ORANGE(get, never):RLHandle;
	static inline function get_ORANGE():RLHandle return rl.impl.RLImpl.COLOR_ORANGE;
	public static var PINK(get, never):RLHandle;
	static inline function get_PINK():RLHandle return rl.impl.RLImpl.COLOR_PINK;
	public static var RED(get, never):RLHandle;
	static inline function get_RED():RLHandle return rl.impl.RLImpl.COLOR_RED;
	public static var MAROON(get, never):RLHandle;
	static inline function get_MAROON():RLHandle return rl.impl.RLImpl.COLOR_MAROON;
	public static var GREEN(get, never):RLHandle;
	static inline function get_GREEN():RLHandle return rl.impl.RLImpl.COLOR_GREEN;
	public static var LIME(get, never):RLHandle;
	static inline function get_LIME():RLHandle return rl.impl.RLImpl.COLOR_LIME;
	public static var DARKGREEN(get, never):RLHandle;
	static inline function get_DARKGREEN():RLHandle return rl.impl.RLImpl.COLOR_DARKGREEN;
	public static var SKYBLUE(get, never):RLHandle;
	static inline function get_SKYBLUE():RLHandle return rl.impl.RLImpl.COLOR_SKYBLUE;
	public static var BLUE(get, never):RLHandle;
	static inline function get_BLUE():RLHandle return rl.impl.RLImpl.COLOR_BLUE;
	public static var DARKBLUE(get, never):RLHandle;
	static inline function get_DARKBLUE():RLHandle return rl.impl.RLImpl.COLOR_DARKBLUE;
	public static var PURPLE(get, never):RLHandle;
	static inline function get_PURPLE():RLHandle return rl.impl.RLImpl.COLOR_PURPLE;
	public static var VIOLET(get, never):RLHandle;
	static inline function get_VIOLET():RLHandle return rl.impl.RLImpl.COLOR_VIOLET;
	public static var DARKPURPLE(get, never):RLHandle;
	static inline function get_DARKPURPLE():RLHandle return rl.impl.RLImpl.COLOR_DARKPURPLE;
	public static var BEIGE(get, never):RLHandle;
	static inline function get_BEIGE():RLHandle return rl.impl.RLImpl.COLOR_BEIGE;
	public static var BROWN(get, never):RLHandle;
	static inline function get_BROWN():RLHandle return rl.impl.RLImpl.COLOR_BROWN;
	public static var DARKBROWN(get, never):RLHandle;
	static inline function get_DARKBROWN():RLHandle return rl.impl.RLImpl.COLOR_DARKBROWN;
	public static var WHITE(get, never):RLHandle;
	static inline function get_WHITE():RLHandle return rl.impl.RLImpl.COLOR_WHITE;
	public static var BLACK(get, never):RLHandle;
	static inline function get_BLACK():RLHandle return rl.impl.RLImpl.COLOR_BLACK;
	public static var BLANK(get, never):RLHandle;
	static inline function get_BLANK():RLHandle return rl.impl.RLImpl.COLOR_BLANK;
	public static var MAGENTA(get, never):RLHandle;
	static inline function get_MAGENTA():RLHandle return rl.impl.RLImpl.COLOR_MAGENTA;
	public static var RAYWHITE(get, never):RLHandle;
	static inline function get_RAYWHITE():RLHandle return rl.impl.RLImpl.COLOR_RAYWHITE;

	public static function create(r:Int, g:Int, b:Int, a:Int):RLHandle {
		return rl.impl.RLImpl.colorCreate(r, g, b, a);
	}

	public static function destroy(handle:RLHandle):Void {
		rl.impl.RLImpl.colorDestroy(handle);
	}
}
