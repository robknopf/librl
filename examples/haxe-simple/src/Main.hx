import rl.RL;
import rl.Window;
import rl.Camera3d;
import rl.Color;
import rl.Render;
import rl.Asset;
import rl.Fs;
import rl.Logger;
import rl.Text2d;
import rl.Font;
import rl.Model;
import rl.Sprite3d;
import rl.Music;
import rl.Text;
import rl.Input;
import rl.Pick;

import rl.helpers.Log;
import rl.Types.RLHandle;
import rl.Types.RLPickResult;
import InjectWasmExports;
import haxe.io.Path;

#if (emscripten || PLATFORM_WEB || js)
final ASSET_HOST:String = "./";
#else
final ASSET_HOST:String = "https://localhost:4444";
#end

typedef AppContext = {
	var elapsed:Float;
	var countdownTimer:Float;
	var totalTime:Float;
	var debugFont:RLHandle;
	var komikaFont:RLHandle;
	var labelText2d:RLHandle;
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
	final SCREEN_FLAGS:Int = Window.FLAG_MSAA_4X_HINT;
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
			/*
			print: (msg) -> {
				trace(msg);
			},
			printErr: (msg) -> {
				trace(msg);
			},
			*/

			// site path to the js binding module, relative to this module
			// bindingsPath: "../../../../bindings/js/rl.js"

			// absolute path to the js binding module (served from site root).
			// Note that this is the default fallback.  See wRLImpl.js.hx::boot()
			bindingsPath: "/bindings/js/dist/rl.js",

			// optional override for the raw emscripten runtime module that the
			// js binding boots internally. Defaults to ../../lib/librl.js relative
			// to bindings/js/rl.js.
			// modulePath: "/lib/librl.js"
		});
		if (rc != RL.BOOT_OK) {
			Log.error("RL.boot failed: " + rc);
			return RT_FAILED;
		}

		// supress any boot messages unless they are warning+
		Logger.setLevel(Logger.LEVEL_WARN);

		/* 
			// if we need to get an initial boot file (like external boot script)
			// we can init the loader separate from the rest of librl. 
			// that will allow us to fetch files required before init
			// otherwise, use RL.init() for normal flow
			var rc = @await Fs.init();
			if (rc != 0) {
				Log.error("Fs.init failed: " + rc);
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
			labelText2d: 0,
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
			// fsRootDir: LOADER_CACHE_DIR
		});
		if (rc != RL.INIT_OK) {
			Log.error("Main: onInit failed with error: " + rc);
			return RT_FAILED;
		}

		Fs.clear();

		// Setup lighting and camera
		Render.enableLighting();
		Render.setLightDirection(-0.6, -1.0, -0.5);
		Render.setLightAmbient(0.25);
		ctx.camera = Camera3d.create(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, Camera3d.PERSPECTIVE);
		Camera3d.setActive(ctx.camera);
		ctx.greyAlphaColor = Color.create(0, 0, 0, 128);
		ctx.backgroundColor = Color.create(245, 245, 245, 255);

		// create a text2d.  Note that it we will update the font when it is available
		ctx.labelText2d = Text2d.create(0, KOMIKA_FONT_SIZE);
		Text2d.setContent(ctx.labelText2d, "rl_text2d: retained label");
		Text2d.setPosition(ctx.labelText2d, 10, 136);
		Text2d.setColor(ctx.labelText2d, Color.GREEN);

		// create a model3d.  Note that it we will update the model asset (mesh/skeleton/animation) when it is available
		// we could pass 0 for the assetHandleId, in which case it won't get rendered ( 0 = noop)
		ctx.gumshoe = Model.create(Model.getDefaultAsset());
		Model.setTint(ctx.gumshoe, Color.BLUE);
		Model.setAnimation(ctx.gumshoe, 1);
		Model.setAnimationSpeed(ctx.gumshoe, 1.0);
		Model.setAnimationLoop(ctx.gumshoe, true);
		Model.setTransform(ctx.gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		
		// set the fonts to the default font, they will be replaced when the real fonts come in
		//var defaultFont = Font.getDefault();

		queueAssets();

		platformText = getPlatformText();

		// clear the screen
		Render.begin();
		Render.clearBackground(ctx.backgroundColor);
		Render.end();

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

		Music.updateAll();

		var mouse = Input.getMouseState();
		var mouseText = 'Mouse: (${mouse.x}, ${mouse.y}) w:${mouse.wheel} b:[${mouse.left}, ${mouse.right}, ${mouse.middle}]';
		var remainingText = 'Remaining: ${formatFixed(ctx.countdownTimer, 2)}';
		var elapsedText = 'Elapsed: ${formatFixed(ctx.totalTime, 2)}';

		// var pickResult = Pick.sprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y);
		msg = "Nothing picked!";

		var pickResult:RLPickResult;

		if (ctx.gumshoe != 0) {
			pickResult = Pick.model(ctx.camera, ctx.gumshoe, mouse.x, mouse.y);
			if (pickResult.hit) {
				trace('Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
				msg = 'Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
			}
		}

		if (ctx.sprite != 0) {
			pickResult = Pick.sprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y);
			if (pickResult.hit) {
				trace('Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
				msg = 'Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
			}
		}

		Render.begin();
		Render.clearBackground(ctx.backgroundColor);

		// 3D render
		Render.beginMode3d();
		Model.draw(ctx.gumshoe);
		Sprite3d.draw(ctx.sprite);
		Render.endMode3d();

		// 2D UI overlay
		var screen = Window.getScreenSize();
		if (ctx.komikaFont != 0) {
			var textSize = Text.measureEx(ctx.komikaFont, msg, KOMIKA_FONT_SIZE, 1.0);
			var textX = Std.int((screen.x - textSize.x) / 2);
			var textY = Std.int((screen.y - textSize.y) / 2);
			Text.drawEx(ctx.komikaFont, msg, textX, textY, KOMIKA_FONT_SIZE, 1.0, Color.BLUE);
		} else {
			var textWidth = Text.measure(msg, KOMIKA_FONT_SIZE);
			var textX = Std.int((screen.x - textWidth) / 2);
			var textY = Std.int((screen.y - KOMIKA_FONT_SIZE) / 2);
			Text.draw(msg, textX, textY, KOMIKA_FONT_SIZE, Color.BLUE);
		}
		if (ctx.debugFont != 0) {
			Text.drawEx(ctx.debugFont, remainingText, 10, 36, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
			Text.drawEx(ctx.debugFont, elapsedText, 10, 56, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
			Text.drawEx(ctx.debugFont, mouseText, 10, 76, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
			Text.drawEx(ctx.debugFont, 'Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		} else {
			Text.draw(remainingText, 10, 36, DEBUG_FONT_SIZE, Color.BLACK);
			Text.draw(elapsedText, 10, 56, DEBUG_FONT_SIZE, Color.BLACK);
			Text.draw(mouseText, 10, 76, DEBUG_FONT_SIZE, Color.BLACK);
			Text.draw('Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, Color.BLACK);
		}

		if (ctx.debugFont != 0) {
			Text.drawEx(ctx.debugFont, platformText, 10, 116, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		} else {
			Text.draw(platformText, 10, 116, DEBUG_FONT_SIZE, Color.BLACK);
		}

		if (ctx.debugFont != 0) {
			Text.drawFpsEx(ctx.debugFont, 10, 10, DEBUG_FONT_SIZE, ctx.greyAlphaColor);
		} else {
			Text.drawFps(10, 10);
		}

		if (ctx.labelText2d != 0) {
			Text2d.draw(ctx.labelText2d);
		}

		Render.end();

		return RT_SUCCESS;
	}

	@async
	public function onShutdown():VoidResult {
		return @await RL.deinit();
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
		var task = Asset.ensureAsync(path);
		if (Asset.taskIsValid(task)) {
			Asset.addTask(task, (path, userData) -> {
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
			ctx.bgm = Music.create(path);
			Music.setLoop(ctx.bgm, true);
			Music.play(ctx.bgm);
		}, (path, userData) -> {
			Log.error("Failed to import BGM: " + path);
		});
		importAssetAsync(MODEL_PATH, (path, userData) -> {
			//ctx.gumshoe = RL.modelCreateFromFile(path);
			var gumshoeAsset = Model.loadAsset(path);
			if (ctx.gumshoe != 0) {
			//	Model.setAsset(ctx.gumshoe, gumshoeAsset);
			}
		}, (path, userData) -> {
			Log.error("Failed to import MODEL: " + path);
		});
		importAssetAsync(SPRITE_PATH, (path, userData) -> {
			ctx.sprite = Sprite3d.createFromFile(path);
			Sprite3d.setTransform(ctx.sprite, 0, 0, ctx.spriteYOffset, 1.0);
		}, (path, userData) -> {
			Log.error("Failed to import SPRITE: " + path);
		});
		importAssetAsync(DEBUG_FONT_PATH, (path, userData) -> {
			ctx.debugFont = Font.create(path, DEBUG_FONT_SIZE);
		}, (path, userData) -> {
			Log.error("Failed to import DEBUG FONT: " + path);
		});
		importAssetAsync(KOMIKA_FONT_PATH, (path, userData) -> {
			ctx.komikaFont = Font.create(path, KOMIKA_FONT_SIZE);
			if (ctx.labelText2d != 0) {
				Text2d.setFont(ctx.labelText2d, ctx.komikaFont);
			}
		}, (path, userData) -> {
			Log.error("Failed to import KOMIKA FONT: " + path);
		});
	}

	private function animateFrame(deltaTimeSec:Float):Void {
		if (ctx.gumshoe != 0) {
			Model.animate(ctx.gumshoe, deltaTimeSec);
		}

		//trace("335");

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
			Sprite3d.setTransform(ctx.sprite, spriteX, spriteY, spriteZ, 1.0);
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
	function onShutdown():VoidResult;  // hxasync doesn't play well with Void
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
			var rc = RL.tick();
			if (rc == RL.TICK_FAILED) {
				Log.error("Main: RL.tick failed with error: " + rc);
				return RT_FAILED;
			}
			if (rc == RL.TICK_WAITING) {
				return RT_SUCCESS;
			}
			if (Window.closeRequested()) {
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
			@await _instance.onShutdown();
			_instance = null;
		}

		return;
	}

	public static function main() {
		if (_instance == null) {
			_instance = new Runtime();
		}

		// fake a host for debugging locally
		#if !(emscripten || PLATFORM_WEB || js)
		@await startLocalHost();
		#end
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
