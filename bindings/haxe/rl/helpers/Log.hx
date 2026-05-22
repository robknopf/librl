/**
 * Ergonomic logging helpers (not part of the C API).
 *
 * Usage: `Log.info("hello")` instead of `Logger.message(Logger.LEVEL_INFO, "hello")`.
 */

package rl.helpers;

import rl.Logger;

@:keep
class Log {
	public static inline function log(message:String):Void {
		Logger.message(Logger.LEVEL_INFO, message);
	}

	public static inline function debug(message:String):Void {
		Logger.message(Logger.LEVEL_DEBUG, message);
	}

	public static inline function info(message:String):Void {
		Logger.message(Logger.LEVEL_INFO, message);
	}

	public static inline function warn(message:String):Void {
		Logger.message(Logger.LEVEL_WARN, message);
	}

	public static inline function error(message:String):Void {
		Logger.message(Logger.LEVEL_ERROR, message);
	}
}
