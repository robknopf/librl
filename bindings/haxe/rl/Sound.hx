/** Public façade: Sound subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Sound {


	public static function create(filename:String):RLHandle {
		return rl.impl.RLImpl.soundCreate(filename);
	}

	public static function destroy(sound:RLHandle):Void {
		rl.impl.RLImpl.soundDestroy(sound);
	}

	public static function play(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundPlay(sound);
	}

	public static function pause(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundPause(sound);
	}

	public static function resume(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundResume(sound);
	}

	public static function stop(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundStop(sound);
	}

	public static function setVolume(sound:RLHandle, volume:Float):Bool {
		return rl.impl.RLImpl.soundSetVolume(sound, volume);
	}

	public static function setPitch(sound:RLHandle, pitch:Float):Bool {
		return rl.impl.RLImpl.soundSetPitch(sound, pitch);
	}

	public static function setPan(sound:RLHandle, pan:Float):Bool {
		return rl.impl.RLImpl.soundSetPan(sound, pan);
	}

	public static function isPlaying(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundIsPlaying(sound);
	}
}
