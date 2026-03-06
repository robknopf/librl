package;


// import thenshim.Promise;

@:structAccess
@:native("vec2_t")
extern class Vec2 {
	public var x(default, never):Float;
	public var y(default, never):Float;
}

typedef RLHandle = UInt;

@:buildXml('
<files id="haxe">
  <error value="Missing LIBRL_ROOT (-D LIBRL_ROOT=/path/to/librl_root_directory)" unless="LIBRL_ROOT" />
  <echo value="LIBRL_ROOT: ${LIBRL_ROOT}" />
  <echo value="Compiling Raylib (haxe)..." />
  <compilerflag value="-I${LIBRL_ROOT}/include"/>
</files>
<target id="haxe" tool="linker">
  <section id="haxe" unless="static_link">
    <echo value="Linking Raylib (haxe)..." />
    <lib name="-L${LIBRL_ROOT}/lib"/>
    <lib name="-lrl"/>
    <lib name="-lcurl"/> 
    <lib name="--verbose"/>
  </section>
</target>
')
@:headerInclude("rl.h")
@:headerInclude("rl_scratch.h")
@:headerInclude("rl_font.h")
@:headerInclude("rl_color.h")
@:keep
@:expose
#if js
@:native("RL")
#end
class RL {
	// Predefined Colors
	public static final DEFAULT:Int = 0;
	public static final LIGHTGRAY:Int = 1;
	public static final GRAY:Int = 2;
	public static final DARKGRAY:Int = 3;
	public static final YELLOW:Int = 4;
	public static final GOLD:Int = 5;
	public static final ORANGE:Int = 6;
	public static final PINK:Int = 7;
	public static final RED:Int = 8;
	public static final MAROON:Int = 9;
	public static final GREEN:Int = 10;
	public static final LIME:Int = 11;
	public static final DARKGREEN:Int = 12;
	public static final SKYBLUE:Int = 13;
	public static final BLUE:Int = 14;
	public static final DARKBLUE:Int = 15;
	public static final PURPLE:Int = 16;
	public static final VIOLET:Int = 17;
	public static final DARKPURPLE:Int = 18;
	public static final BEIGE:Int = 19;
	public static final BROWN:Int = 20;
	public static final DARKBROWN:Int = 21;
	public static final WHITE:Int = 22;
	public static final BLACK:Int = 23;
	public static final BLANK:Int = 24;
	public static final MAGENTA:Int = 25;
	public static final RAYWHITE:Int = 26;
	public static final CAMERA_PERSPECTIVE:Int = 0;
	public static final CAMERA_ORTHOGRAPHIC:Int = 1;

 
	@:native("rl_scratch_area_get_vector2")
	extern public static function getVector2():Vec2;

	@:native("rl_scratch_area_set_vector2")
	extern public static function setVector2(x:Float, y:Float):Void;

	@:native("rl_init")
	extern public static function init():Void;

	@:native("rl_update")
	extern public static function update():Void;

	@:native("rl_deinit")
	extern public static function deinit():Void;

	@:native("rl_init_window")
	extern public static function initWindow(width:Int, height:Int, title:String):Void;

	@:native("rl_get_monitor_count")
	extern public static function getMonitorCount():Int;

	@:native("rl_get_current_monitor")
	extern public static function getCurrentMonitor():Int;

	@:native("rl_set_window_monitor")
	extern public static function setWindowMonitor(monitor:Int):Void;

	@:native("rl_get_monitor_position")
	extern public static function getMonitorPositionRaw(monitor:Int):Void;

	@:native("rl_get_monitor_position_x")
	extern public static function getMonitorPositionX(monitor:Int):Float;

	@:native("rl_get_monitor_position_y")
	extern public static function getMonitorPositionY(monitor:Int):Float;

	public static function getMonitorPosition(monitor:Int):Vec2 {
		getMonitorPositionRaw(monitor);
		return getVector2();
	}

	@:native("rl_close_window")
	extern public static function closeWindow():Void;

	@:native("rl_begin_drawing")
	extern public static function beginDrawing():Void;

	@:native("rl_end_drawing")
	extern public static function endDrawing():Void;

	@:native("rl_clear_background")
	extern public static function clearBackground(color:RLHandle):Void;

	@:native("rl_begin_mode_3d")
	extern public static function beginMode3D(positionX:Float, positionY:Float, positionZ:Float,
		targetX:Float, targetY:Float, targetZ:Float,
		upX:Float, upY:Float, upZ:Float,
		fovy:Float, projection:Int):Void;

	@:native("rl_end_mode_3d")
	extern public static function endMode3D():Void;

	@:native("rl_enable_lighting")
	extern public static function enableLighting():Void;

	@:native("rl_disable_lighting")
	extern public static function disableLighting():Void;

	@:native("rl_is_lighting_enabled")
	extern public static function isLightingEnabled():Int;

	@:native("rl_set_light_direction")
	extern public static function setLightDirection(x:Float, y:Float, z:Float):Void;

	@:native("rl_set_light_ambient")
	extern public static function setLightAmbient(ambient:Float):Void;

	@:native("rl_draw_cube")
	extern public static function drawCube(positionX:Float, positionY:Float, positionZ:Float,
		width:Float, height:Float, length:Float, color:RLHandle):Void;

	@:native("rl_draw_rectangle")
	extern public static function drawRectangle(x:Int, y:Int, width:Int, height:Int, color:RLHandle):Void;

	@:native("rl_draw_text")
	extern public static function drawText(text:String, x:Int, y:Int, font:RLHandle, color:RLHandle):Void;

	@:native("rl_set_target_fps")
	extern public static function setTargetFPS(fps:Int):Void;

	@:native("rl_draw_fps")
	extern public static function drawFPS(x:Int, y:Int):Void;

	@:native("rl_draw_fps_ex")
	extern public static function drawFPSEx(font:RLHandle, x:Int, y:Int, fontSize:Int, color:RLHandle):Void;

	@:native("rl_draw_text_ex")
	extern public static function drawTextEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void;

	@:native("rl_measure_text_ex")
	extern public static function rl_measure_text_ex(font:RLHandle, text:String, fontSize:Float, spacing:Float):Void;

	public static function measureTextEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):Vec2 {
		rl_measure_text_ex(font, text, fontSize, spacing);
		return getVector2();
	}

	@:native("rl_measure_text")
	extern public static function measureText(text:String, fontSize:Int):Int;

	@:native("rl_font_get_default")
	extern public static function getDefaultFont():RLHandle;

	@:native("rl_font_create")
	extern public static function createFont(file:String, fontSize:Int):RLHandle;

	@:native("rl_font_destroy")
	extern public static function destroyFont(font:RLHandle):Void;

	@:native("rl_color_create")
	extern public static function createColor(r:Int, g:Int, b:Int, a:Int):RLHandle;

	@:native("rl_color_destroy")
	extern public static function destroyColor(color:RLHandle):Void;
}
