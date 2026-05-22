/** Public façade: Music subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;
import rl.Types.RLPickResult;
import rl.Types.RLMouseState;
import rl.Types.RLKeyboardState;
import rl.Types.RLAsyncVoid;

@:keep
class Music {

	public static function create(filename:String):RLHandle {
		return rl.impl.RLImpl.musicCreate(filename);
	}

	public static function destroy(music:RLHandle):Void {
		rl.impl.RLImpl.musicDestroy(music);
	}

	public static function play(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicPlay(music);
	}

	public static function pause(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicPause(music);
	}

	public static function stop(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicStop(music);
	}

	public static function setLoop(music:RLHandle, shouldLoop:Bool):Bool {
		return rl.impl.RLImpl.musicSetLoop(music, shouldLoop);
	}

	public static function setVolume(music:RLHandle, volume:Float):Bool {
		return rl.impl.RLImpl.musicSetVolume(music, volume);
	}

	public static function isPlaying(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicIsPlaying(music);
	}

	public static function update(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicUpdate(music);
	}

	public static function updateAll():Void {
		rl.impl.RLImpl.musicUpdateAll();
	}
}
