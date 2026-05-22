/** Public façade: Window subsystem. */
package rl;

import rl.Types.RLVec2;

@:keep
class Window {

	public static inline var FLAG_WINDOW_RESIZABLE:Int = rl.impl.RLImpl.FLAG_WINDOW_RESIZABLE;
	public static inline var FLAG_MSAA_4X_HINT:Int = rl.impl.RLImpl.FLAG_MSAA_4X_HINT;
	public static inline var FLAG_VSYNC_HINT:Int = rl.impl.RLImpl.FLAG_VSYNC_HINT;


	public static function closeRequested():Bool {
		return rl.impl.RLImpl.windowCloseRequested();
	}

	public static function getScreenSize():RLVec2 {
		return rl.impl.RLImpl.windowGetScreenSize();
	}

	public static function getMonitorCount():Int {
		return rl.impl.RLImpl.windowGetMonitorCount();
	}

	public static function setTitle(title:String):Void {
		rl.impl.RLImpl.windowSetTitle(title);
	}

	public static function setSize(width:Int, height:Int):Void {
		rl.impl.RLImpl.windowSetSize(width, height);
	}

	public static function getCurrentMonitor():Int {
		return rl.impl.RLImpl.windowGetCurrentMonitor();
	}

	public static function setMonitor(monitor:Int):Void {
		rl.impl.RLImpl.windowSetMonitor(monitor);
	}

	public static function getMonitorWidth(monitor:Int):Int {
		return rl.impl.RLImpl.windowGetMonitorWidth(monitor);
	}

	public static function getMonitorHeight(monitor:Int):Int {
		return rl.impl.RLImpl.windowGetMonitorHeight(monitor);
	}

	public static function getMonitorPosition(monitor:Int):RLVec2 {
		return rl.impl.RLImpl.windowGetMonitorPosition(monitor);
	}

	public static function getPosition():RLVec2 {
		return rl.impl.RLImpl.windowGetPosition();
	}

	public static function setPosition(x:Int, y:Int):Void {
		rl.impl.RLImpl.windowSetPosition(x, y);
	}
}
