package;

import rl.RL;
import rl.RLHandle;
import rl.Log;
import haxe.io.Path;
import Types.RTResult;
import rl.RLTypes.RLPickResult;
import Script;

/*
	enum abstract RTResult(Int) from Int to Int {
	var RT_SUCCESS = 0;
	var RT_FAILED = -1;
	var RT_STOPPED = 1;
	}
 */
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

@:keep
class MainScript extends Script {
	final SCREEN_WIDTH:Int = 1024;
	final SCREEN_HEIGHT:Int = 1280;
	final SCREEN_TITLE:String = "cppia-simple (Haxe runtime)";
	final SCREEN_FLAGS:Int = RL.FLAG_MSAA_4X_HINT;

	// this doesn't work since we are a script.  emscripten/platform web isn't defined
	// TODO: figure out how to detect if we are running in a browser or not (ask the host?)
	#if (emscripten || PLATFORM_WEB)
	final ASSET_HOST:String = "./";
	#else
	final ASSET_HOST:String = "https://192.168.1.100:4444";
	#end

	// final LOADER_CACHE_DIR:String = "/haxetest";
	final DEBUG_FONT_SIZE:Int = 18;
	final DEBUG_FONT_PATH:String = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
	final KOMIKA_FONT_SIZE:Int = 24;
	final KOMIKA_FONT_PATH:String = "assets/fonts/Komika/KOMIKAH_.ttf";

	final MODEL_PATH:String = "assets/models/gumshoe/gumshoe.glb";
	final SPRITE_PATH:String = "assets/sprites/logo/wg-logo-bw-alpha.png";
	final BGM_PATH:String = "assets/music/ethernight_club.mp3";

	var ctx:AppContext = null;

	var msg:String = "Hello from Haxe Simple Main !";
	var platformText:String = "Platform: <unknown>";

	public static function joinPath(pathComponents:haxe.Rest<String>):String {
		return Path.normalize(Path.join(pathComponents.toArray()));
	}

	override public function onInit():RTResult {
		trace("Main: onInit");
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
			greyAlphaColor: 0,
			gumshoe: 0,
			reloadCount: 0,
			spriteYOffset: 3.0,
			backgroundColor: 0
		};
		RL.loggerSetLevel(RL.LOGGER_LEVEL_WARN);
		var err = RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
			assetHost: ASSET_HOST,
			// fileioBaseDir: LOADER_CACHE_DIR
		});
		if (err != 0) {
			trace("Main: onInit failed with error: " + err);
			return RT_FAILED;
		}

		RL.fileioClear();

		// Setup lighting and camera
		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		ctx.camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
		RL.camera3dSetActive(ctx.camera);
		ctx.greyAlphaColor = RL.colorCreate(0, 0, 0, 128);
		ctx.backgroundColor = RL.colorCreate(245, 245, 245, 255);

		ctx.labelText2d = RL.text2dCreate(0, KOMIKA_FONT_SIZE);
		RL.text2dSetContent(ctx.labelText2d, "rl_text2d: retained label");
		RL.text2dSetPosition(ctx.labelText2d, 10, 136);
		RL.text2dSetColor(ctx.labelText2d, RL.COLOR_GREEN);

		loadAssets();

		platformText = getPlatformText();

		RL.renderBegin();
		RL.renderClearBackground(ctx.backgroundColor);
		RL.renderEnd();

		return RT_SUCCESS;
	}

	function loadAssets():Void {
		RL.fileioAddTask(RL.fileioEnsureAsync(DEBUG_FONT_PATH), (path, _) -> {
			ctx.debugFont = RL.fontCreate(path, DEBUG_FONT_SIZE);
		}, null, ctx);
		RL.fileioAddTask(RL.fileioEnsureAsync(KOMIKA_FONT_PATH), (path, _) -> {
			ctx.komikaFont = RL.fontCreate(path, KOMIKA_FONT_SIZE);
			if (ctx.labelText2d != 0) {
				RL.text2dSetFont(ctx.labelText2d, ctx.komikaFont);
			}
		}, null, ctx);
		RL.fileioAddTask(RL.fileioEnsureAsync(MODEL_PATH), (path, _) -> {
			ctx.gumshoe = RL.modelCreate(path);
			RL.modelSetTransform(ctx.gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
			RL.modelSetAnimation(ctx.gumshoe, 1);
			RL.modelSetAnimationSpeed(ctx.gumshoe, 1.0);
			RL.modelSetAnimationLoop(ctx.gumshoe, true);
		}, null, ctx);
		RL.fileioAddTask(RL.fileioEnsureAsync(SPRITE_PATH), (path, _) -> {
			ctx.sprite = RL.sprite3dCreate(path);
			RL.sprite3dSetTransform(ctx.sprite, 0.0, 0.0, ctx.spriteYOffset, 1.0);
		}, null, ctx);
		RL.fileioAddTask(RL.fileioEnsureAsync(BGM_PATH), (path, _) -> {
			ctx.bgm = RL.musicCreate(path);
			RL.musicSetLoop(ctx.bgm, true);
			RL.musicPlay(ctx.bgm);
		}, null, ctx);
	}

	public function animateFrame(deltaTimeSec:Float):Void {
		if (ctx.gumshoe != 0) {
			RL.modelAnimate(ctx.gumshoe, deltaTimeSec);
		}

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

	override public function onTick(deltaTimeSec:Float):RTResult {
		// trace("Main: onTick called with deltaTimeMS: " + deltaTimeMS);
		ctx.elapsed = ctx.elapsed + deltaTimeSec;
		ctx.totalTime += deltaTimeSec;
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

		msg = "Nothing picked!";

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

		// 3d render
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

		if (ctx.labelText2d != 0) {
			RL.text2dDraw(ctx.labelText2d);
		}

		RL.renderEnd();

		return RT_SUCCESS;
	}

	override public function onUnload():Dynamic {
		trace("Main: onUnload");
		return ctx;
	}

	public function getPlatformText():String {
		#if sys
		return "Platform: " + Sys.systemName();
		#else
		return "Platform: " + RL.getPlatform();
		#end
	}

	override public function onLoad(stashedData:Dynamic):RTResult {
		trace("Main: onLoad");
		ctx = stashedData;
		ctx.reloadCount++;

		platformText = getPlatformText();
		return RT_SUCCESS;
	}

	override public function onShutdown():Void {
		trace("Main: onShutdown");

		RL.deinit();
	}

	static function formatFixed(value:Float, digits:Int):String {
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
}
