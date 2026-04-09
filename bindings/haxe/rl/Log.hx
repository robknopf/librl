package rl;

class Log {
	public static inline function log(message:String):Void {
		RL.loggerMessage(RL.LOGGER_LEVEL_INFO, message);
	}

	public static inline function debug(message:String):Void {
		RL.loggerMessage(RL.LOGGER_LEVEL_DEBUG, message);
	}

	public static inline function info(message:String):Void {
		RL.loggerMessage(RL.LOGGER_LEVEL_INFO, message);
	}

	public static inline function warn(message:String):Void {
		RL.loggerMessage(RL.LOGGER_LEVEL_WARN, message);
	}

	public static inline function error(message:String):Void {
		RL.loggerMessage(RL.LOGGER_LEVEL_ERROR, message);
	}
}
