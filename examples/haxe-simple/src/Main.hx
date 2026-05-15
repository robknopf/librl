import rl.RL;
import rl.Log;
import rl.RLHandle;
import rl.RLTypes.RLPickResult;
import InjectWasmExports;
import haxe.io.Path;

#if (emscripten || PLATFORM_WEB || js)
final ASSET_HOST:String = "./";
#else
final ASSET_HOST:String = "https://192.168.1.100:4444";
#end

typedef AppContext = {
	var elapsed:Float;
	var countdownTimer:Float;
	var totalTime:Float;
	var debugFont:RLHandle;
	var komikaFont:RLHandle;
	var sprite:RLHandle;
	var camera:RLHandle;
	var bgm:RLHandle;
	var greyAlphaColor:RLHandle;
	var gumshoe:RLHandle;
	var reloadCount:Int;
	var spriteYOffset:Float;
	var backgroundColor:RLHandle;
}

class SimpleRuntime implements IRuntime {
	final SCREEN_TITLE:String = "haxe-simple (Haxe runtime)";
	final SCREEN_FLAGS:Int = RL.FLAG_MSAA_4X_HINT;
	final SCREEN_WIDTH:Int = 1024;
	final SCREEN_HEIGHT:Int = 1280;
	final DEBUG_FONT_SIZE:Int = 18;
	final DEBUG_FONT_PATH:String = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
	final KOMIKA_FONT_SIZE:Int = 24;
	final KOMIKA_FONT_PATH:String = "assets/fonts/Komika/KOMIKAH_.ttf";
	final BGM_PATH:String = "assets/music/ethernight_club.mp3";
	final MODEL_PATH:String = "assets/models/gumshoe/gumshoe.glb";
	final SPRITE_PATH:String = "assets/sprites/logo/wg-logo-bw-alpha.png";

	var ctx:AppContext;
	var msg:String = "Hello from Haxe Simple Main !";
	var platformText:String = "Platform: <unknown>";

	public function new() {
		trace("SimpleRuntime::new()");
	}

	@async public function onBoot() {
		// trace("onBoot");
		var rc = @await RL.boot({
			canvasId: "renderCanvas",
			env: {
				print: (msg) -> {
					trace(msg);
				},
				printErr: (msg) -> {
					trace(msg);
				}
			},

			// site path to the js binding module, relative to this module
			// bindingsPath: "../../../../bindings/js/rl.js"

			// absolute path to the js binding module (served from site root).
			// Note that this is the default fallback.  See wRLImpl.js.hx::boot()
			bindingsPath: "/bindings/js/rl.js",

			// optional override for the raw emscripten runtime module that the
			// js binding boots internally. Defaults to ../../lib/librl.js relative
			// to bindings/js/rl.js.
			// modulePath: "/lib/librl.js"
		});
		if (rc != 0) {
			Log.error("RL.boot failed: " + rc);
			return RT_FAILED;
		}

		// supress any boot messages unless they are warning+
		RL.loggerSetLevel(RL.LOGGER_LEVEL_WARN);

		/* 
			// if we need to get an initial boot file (like external boot script)
			// we can init the loader separate from the rest of librl. 
			// that will allow us to fetch files required before init
			// otherwise, use RL.init() for normal flow
			var rc = @await RL.loaderInit();
			if (rc != 0) {
				Log.error("RL.loaderInit failed: " + rc);
				return RT_FAILED;
			}
		 */
		return RT_SUCCESS;
	}

	@async public function onInit():Int {
		// trace("onInit");
		ctx = {
			elapsed: 0.0,
			countdownTimer: 30.0,
			totalTime: 0.0,
			debugFont: 0,
			komikaFont: 0,
			sprite: 0,
			camera: 0,
			bgm: 0,
			gumshoe: 0,
			reloadCount: 0,
			spriteYOffset: 3.0,
			backgroundColor: 0,
			greyAlphaColor: 0,
		};

		var rc = @await RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
			assetHost: ASSET_HOST,
			// loaderCacheDir: LOADER_CACHE_DIR
		});
		if (rc != 0) {
			Log.error("Main: onInit failed with error: " + rc);
			return RT_FAILED;
		}

		RL.loaderClearCache();

		// Setup lighting and camera
		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		ctx.camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
		RL.camera3dSetActive(ctx.camera);
		ctx.greyAlphaColor = RL.colorCreate(0, 0, 0, 128);
		ctx.backgroundColor = RL.colorCreate(245, 245, 245, 255);

		queueAssets();

		platformText = getPlatformText();

		// clear the screen
		RL.renderBegin();
		RL.renderClearBackground(ctx.backgroundColor);
		RL.renderEnd();

		return RT_SUCCESS;
	}

	public function onTick(deltaTimeSec:Float):Int {
		// trace("Main: onTick called with deltaTimeMS: " + deltaTimeMS);
		ctx.elapsed = ctx.elapsed + deltaTimeSec;
		ctx.countdownTimer -= deltaTimeSec;
		if (ctx.countdownTimer <= 0) {
			// return RT_STOPPED;
		}

		animateFrame(deltaTimeSec);

		RL.musicUpdateAll();

		var mouse = RL.inputGetMouseState();
		var mouseText = 'Mouse: (${mouse.x}, ${mouse.y}) w:${mouse.wheel} b:[${mouse.left}, ${mouse.right}, ${mouse.middle}]';
		var remainingText = 'Remaining: ${formatFixed(ctx.countdownTimer, 2)}';
		var elapsedText = 'Elapsed: ${formatFixed(ctx.totalTime, 2)}';

		// var pickResult = RL.pickSprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y);
		msg = "Nothing picked";

		var pickResult:RLPickResult;

		if (ctx.gumshoe != 0) {
			pickResult = RL.pickModel(ctx.camera, ctx.gumshoe, mouse.x, mouse.y);
			if (pickResult.hit) {
				trace('Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
				msg = 'Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
			}
		}

		if (ctx.sprite != 0) {
			pickResult = RL.pickSprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y);
			if (pickResult.hit) {
				trace('Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
				msg = 'Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
			}
		}

		RL.renderBegin();
		RL.renderClearBackground(ctx.backgroundColor);

		// 3D render
		RL.renderBeginMode3d();
		if (ctx.gumshoe != 0) {
			RL.modelDraw(ctx.gumshoe, RL.COLOR_RAYWHITE);
		}
		if (ctx.sprite != 0) {
			RL.sprite3dDraw(ctx.sprite, RL.COLOR_RAYWHITE);
		}
		RL.renderEndMode3d();

		// 2D UI overlay
		var screen = RL.windowGetScreenSize();
		if (ctx.komikaFont != 0) {
			var textSize = RL.textMeasureEx(ctx.komikaFont, msg, KOMIKA_FONT_SIZE, 1.0);
			var textX = Std.int((screen.x - textSize.x) / 2);
			var textY = Std.int((screen.y - textSize.y) / 2);
			RL.textDrawEx(ctx.komikaFont, msg, textX, textY, KOMIKA_FONT_SIZE, 1.0, RL.COLOR_BLUE);
		} else {
			var textWidth = RL.textMeasure(msg, KOMIKA_FONT_SIZE);
			var textX = Std.int((screen.x - textWidth) / 2);
			var textY = Std.int((screen.y - KOMIKA_FONT_SIZE) / 2);
			RL.textDraw(msg, textX, textY, KOMIKA_FONT_SIZE, RL.COLOR_BLUE);
		}
		if (ctx.debugFont != 0) {
			RL.textDrawEx(ctx.debugFont, remainingText, 10, 36, DEBUG_FONT_SIZE, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(ctx.debugFont, elapsedText, 10, 56, DEBUG_FONT_SIZE, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(ctx.debugFont, mouseText, 10, 76, DEBUG_FONT_SIZE, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(ctx.debugFont, 'Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, 1.0, RL.COLOR_BLACK);
		} else {
			RL.textDraw(remainingText, 10, 36, DEBUG_FONT_SIZE, RL.COLOR_BLACK);
			RL.textDraw(elapsedText, 10, 56, DEBUG_FONT_SIZE, RL.COLOR_BLACK);
			RL.textDraw(mouseText, 10, 76, DEBUG_FONT_SIZE, RL.COLOR_BLACK);
			RL.textDraw('Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, RL.COLOR_BLACK);
		}

		if (ctx.debugFont != 0) {
			RL.textDrawEx(ctx.debugFont, platformText, 10, 116, DEBUG_FONT_SIZE, 1.0, RL.COLOR_BLACK);
		} else {
			RL.textDraw(platformText, 10, 116, DEBUG_FONT_SIZE, RL.COLOR_BLACK);
		}

		if (ctx.debugFont != 0) {
			RL.textDrawFpsEx(ctx.debugFont, 10, 10, DEBUG_FONT_SIZE, ctx.greyAlphaColor);
		} else {
			RL.textDrawFps(10, 10);
		}

		RL.renderEnd();

		return RT_SUCCESS;
	}

	@async
	public function onShutdown():Void {
		@await RL.deinit();
		return;
	}

	private function joinPath(pathComponents:haxe.Rest<String>):String {
		return Path.normalize(Path.join(pathComponents.toArray()));
	}

	private function getPlatformText():String {
		#if sys
		return "Platform: " + Sys.systemName();
		#else
		return "Platform: " + RL.getPlatform();
		#end
	}

	private function formatFixed(value:Float, digits:Int):String {
		var scale = Math.pow(10, digits);
		var rounded = Math.round(value * scale) / scale;
		var text = Std.string(rounded);
		var dot = text.indexOf(".");
		if (digits <= 0) {
			return dot >= 0 ? text.substr(0, dot) : text;
		}
		if (dot < 0) {
			return text + "." + StringTools.rpad("", "0", digits);
		}
		var decimals = text.length - dot - 1;
		if (decimals < digits) {
			return text + StringTools.rpad("", "0", digits - decimals);
		}
		return text;
	}

	// helper to combine creating an import task and adding it to the loader queue
	private function importAssetAsync(path:String, ?onSuccess:String->Dynamic->Void, ?onFailure:String->Dynamic->Void, ?userData:Dynamic):Int {
		var task = RL.loaderImportAssetAsync(path);
		if (RL.loaderTaskIsValid(task)) {
			RL.loaderAddTask(task, (path, userData) -> {
				if (onSuccess != null) {
					onSuccess(path, userData);
				}
			}, (path, userData) -> {
				if (onFailure != null) {
					onFailure(path, userData);
				}
			}, userData);
			return 0;
		} else {
			if (onFailure != null) {
				onFailure(path, userData);
			}
			return -1;
		}
	}

	private function queueAssets():Void {
		importAssetAsync(BGM_PATH, (path, userData) -> {
			ctx.bgm = RL.musicCreate(path);
			RL.musicSetLoop(ctx.bgm, true);
			RL.musicPlay(ctx.bgm);
		}, (path, userData) -> {
			Log.error("Failed to import BGM: " + path);
		});
		importAssetAsync(MODEL_PATH, (path, userData) -> {
			ctx.gumshoe = RL.modelCreate(path);
			RL.modelSetAnimation(ctx.gumshoe, 1);
			RL.modelSetAnimationSpeed(ctx.gumshoe, 1.0);
			RL.modelSetAnimationLoop(ctx.gumshoe, true);
			RL.modelSetTransform(ctx.gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		}, (path, userData) -> {
			Log.error("Failed to import MODEL: " + path);
		});
		importAssetAsync(SPRITE_PATH, (path, userData) -> {
			ctx.sprite = RL.sprite3dCreate(path);
			RL.sprite3dSetTransform(ctx.sprite, 0, 0, ctx.spriteYOffset, 1.0);
		}, (path, userData) -> {
			Log.error("Failed to import SPRITE: " + path);
		});
		importAssetAsync(DEBUG_FONT_PATH, (path, userData) -> {
			ctx.debugFont = RL.fontCreate(path, DEBUG_FONT_SIZE);
		}, (path, userData) -> {
			Log.error("Failed to import DEBUG FONT: " + path);
		});
		importAssetAsync(KOMIKA_FONT_PATH, (path, userData) -> {
			ctx.komikaFont = RL.fontCreate(path, KOMIKA_FONT_SIZE);
		}, (path, userData) -> {
			Log.error("Failed to import KOMIKA FONT: " + path);
		});
	}

	private function animateFrame(deltaTimeSec:Float):Void {
		if (ctx.gumshoe != 0) {
			RL.modelAnimate(ctx.gumshoe, deltaTimeSec);
		}

		// trace("335");

		var spriteX = 0.0;
		var spriteY = 0.0;
		var spriteZ = 0.0;

		// bob the sprite up and down
		var bobSpeed = 1.0;
		var bobHeight = 1.5;
		if (ctx.sprite != 0) {
			var y = Math.sin(ctx.elapsed * bobSpeed) * bobHeight;
			spriteY = y + ctx.spriteYOffset;
		}

		// move the sprite in a circle
		/*
			var rotationSpeed = 1.0;
			var rotationRadius = 2.0;
			if (ctx.sprite != 0) {
				spriteX = Math.cos(ctx.elapsed * rotationSpeed) * rotationRadius;
				spriteZ = Math.sin(ctx.elapsed * rotationSpeed) * rotationRadius;
			}
		 */

		if (ctx.sprite != 0) {
			RL.sprite3dSetTransform(ctx.sprite, spriteX, spriteY, spriteZ, 1.0);
		}
	}
}

///////////  Runtime ABI, called by host  ///////////

typedef Runtime = SimpleRuntime;
/*
	enum abstract RTResult(Int) from Int to Int {
	var RT_SUCCESS = 0;
	var RT_FAILED = -1;
	var RT_STOPPED = 1;
	}
 */
final RT_SUCCESS = 0;
final RT_FAILED = -1;
final RT_STOPPED = 1;

interface IRuntime {
	function onBoot():Int;
	function onInit():Int;
	function onTick(deltaTimeSec:Float):Int;
	function onShutdown():Void;
}

@:expose
@async
class Main {
	private static var _instance:IRuntime = null;

	@:expose("_rt_boot")
	@:exportc.entry
	@async static function rt_boot():Int {
		if (_instance == null) {
			_instance = new Runtime();
		}
		return @await _instance.onBoot();
	}

	@:expose("_rt_init")
	@:exportc
	@async static function rt_init(_hostData:Dynamic):Int {
		if (_instance != null) {
			return @await _instance.onInit();
		}
		return RT_FAILED;
	}

	@:expose("_rt_tick")
	@:exportc
	static function rt_tick(dt:Float):Int {
		try {
			RL.scratchRefresh();
			var rc = RL.tick();
			if (rc == RL.TICK_FAILED) {
				Log.error("Main: RL.tick failed with error: " + rc);
				return RT_FAILED;
			}
			if (rc == RL.TICK_WAITING) {
				return RT_SUCCESS;
			}
			if (RL.windowCloseRequested()) {
				return RT_STOPPED;
			}
			if (_instance != null) {
				return _instance.onTick(dt);
			}
			return RT_SUCCESS;
		} catch (e:Dynamic) {
			Log.error("Main: rt_tick failed with exception: " + e);
			return RT_FAILED;
		}
	}

	@:expose("_rt_shutdown")
	@:exportc.exit
	@async static function rt_shutdown():Void {
		if (_instance != null) {
			_instance.onShutdown();
			_instance = null;
		}

		return;
	}

	public static function main() {
		if (_instance == null) {
			_instance = new Runtime();
		}

		// fake a host
		// @await startLocalHost();
		return;
	}

	// local host for when we are debugging without an actual host
	@async static function startLocalHost() {
		// fake a local host
		var rc = @await rt_boot();
		if (rc != RT_SUCCESS) {
			trace("Main: rt_boot failed with error: " + rc);
			return rc;
		}

		rc = @await rt_init(null);
		if (rc != RT_SUCCESS) {
			trace("Main: rt_init failed with error: " + rc);
			return rc;
		}

		final targetFrameRate = 60;
		final frameDelayMs = Std.int(1000 / targetFrameRate);
		var frameTimer = new haxe.Timer(frameDelayMs);
		var lastFrameTime = haxe.Timer.stamp();
		frameTimer.run = () -> {
			var now = haxe.Timer.stamp();
			var dt = now - lastFrameTime;
			lastFrameTime = now;
			var rc = rt_tick(dt);
			if (rc > RT_SUCCESS) {
				trace("Main: rt_tick returned RT_STOPPED");
				frameTimer.stop();
				rt_shutdown();
			}
			if (rc < RT_SUCCESS) {
				trace("Main: rt_tick failed with error: " + rc);
				frameTimer.stop();
				rt_shutdown();
			}
		}
		return RT_SUCCESS;
	}
}
