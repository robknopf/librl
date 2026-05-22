/** Public façade: Event subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Event {

	public static function on(eventName:String, callback:Dynamic->Void):Int {
		return rl.impl.RLImpl.eventOn(eventName, callback);
	}

	public static function once(eventName:String, callback:Dynamic->Void):Int {
		return rl.impl.RLImpl.eventOnce(eventName, callback);
	}

	public static function off(eventName:String, callback:Dynamic->Void):Int {
		return rl.impl.RLImpl.eventOff(eventName, callback);
	}

	public static function offAll(eventName:String):Int {
		return rl.impl.RLImpl.eventOffAll(eventName);
	}

	public static function emit(eventName:String, ?payload:Int):Int {
		return rl.impl.RLImpl.eventEmit(eventName, payload);
	}

	public static function listenerCount(eventName:String):Int {
		return rl.impl.RLImpl.eventListenerCount(eventName);
	}
}
