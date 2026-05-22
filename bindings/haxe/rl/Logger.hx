/** Public façade: Logger subsystem. */
package rl;

@:keep
class Logger {

	public static inline var LEVEL_TRACE:Int = rl.impl.RLImpl.LOGGER_LEVEL_TRACE;
	public static inline var LEVEL_DEBUG:Int = rl.impl.RLImpl.LOGGER_LEVEL_DEBUG;
	public static inline var LEVEL_INFO:Int = rl.impl.RLImpl.LOGGER_LEVEL_INFO;
	public static inline var LEVEL_WARN:Int = rl.impl.RLImpl.LOGGER_LEVEL_WARN;
	public static inline var LEVEL_ERROR:Int = rl.impl.RLImpl.LOGGER_LEVEL_ERROR;
	public static inline var LEVEL_FATAL:Int = rl.impl.RLImpl.LOGGER_LEVEL_FATAL;

	public static function message(level:Int, message:String):Void {
		rl.impl.RLImpl.loggerMessage(level, message);
	}

	public static function messageSource(level:Int, sourceFile:String, sourceLine:Int, message:String):Void {
		rl.impl.RLImpl.loggerMessageSource(level, sourceFile, sourceLine, message);
	}

	public static function setLevel(level:Int):Void {
		rl.impl.RLImpl.loggerSetLevel(level);
	}
}
