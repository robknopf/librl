package;

import InjectLibRL;
import rl.RL;

class Log {
	public static inline function log(message:String) {
		RL.loggerMessage(RL.LOGGER_LEVEL_INFO, message);
	}

	public static inline function debug(message:String) {
		RL.loggerMessage(RL.LOGGER_LEVEL_DEBUG, message);
	}

	public static inline function info(message:String) {
		RL.loggerMessage(RL.LOGGER_LEVEL_INFO, message);
	}

	public static inline function warn(message:String) {
		RL.loggerMessage(RL.LOGGER_LEVEL_WARN, message);
	}

	public static inline function error(message:String) {
		RL.loggerMessage(RL.LOGGER_LEVEL_ERROR, message);
	}
}

typedef AppContext = {
	var assetsRemainingToLoad:Int;
}

typedef EnsureAssetSyncCallback = String->Void;
typedef QueueAssetCallback = String->AppContext->Void;

class Main {
	#if PLATFORM_WEB
	static final ASSET_HOST:String = "./";
	#else
	static final ASSET_HOST:String = "https://localhost:4444";
	#end

	static inline var fontSize:Int = 24;
	static inline var smallFontSize:Int = 16;
	static inline var modelPath = "assets/models/gumshoe/gumshoe.glb";
	static inline var spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
	static inline var fontPath = "assets/fonts/Komika/KOMIKAH_.ttf";
	static inline var bgmPath = "assets/music/ethernight_club.mp3";
	static inline var message = "Hello World!";

	static var komika:Int = 0;
	static var komikaSmall:Int = 0;
	static var gumshoe:Int = 0;
	static var sprite:Int = 0;
	static var camera:Int = 0;
	static var bgm:Int = 0;
	static var greyAlphaColor:Int = 0;
	static var countdownTimer:Float = 5.0;
	static var totalTime:Float = 0.0;
	static var lastTime:Float = 0.0;

	static function ensureAssetSync(assetPath:String, ?successCallback:EnsureAssetSyncCallback, ?failCallback:EnsureAssetSyncCallback, ?timeoutSec:Float):Void {
		var task = RL.loaderImportAssetAsync(assetPath);
		if (task == null) {
			if (failCallback != null)
				failCallback(assetPath);
			return;
		}

		var timeout = haxe.Timer.stamp() + (timeoutSec != null ? timeoutSec : 5.0);
		var ready = RL.loaderPollTask(task);
		while (!ready && haxe.Timer.stamp() < timeout) {
			Sys.sleep(0.001);
			ready = RL.loaderPollTask(task);
		}

		var rc = ready ? RL.loaderFinishTask(task) : 1;
		RL.loaderFreeTask(task);

		if (rc == 0) {
			if (successCallback != null)
				successCallback(assetPath);
		} else if (failCallback != null) {
			failCallback(assetPath);
		}
	}

	static function queueAsset(path:String, ctx:AppContext, ?successCallback:QueueAssetCallback, ?failCallback:QueueAssetCallback):Void {
		var task = RL.loaderImportAssetAsync(path);
		RL.loaderAddTask(task, path, (assetPath:String, ctx:AppContext) -> {
			ctx.assetsRemainingToLoad--;
			if (successCallback != null) {
				successCallback(assetPath, ctx);
			} else {
        Log.info("Loaded asset: " + assetPath );
      }
		}, (assetPath:String, ctx:AppContext) -> {
			ctx.assetsRemainingToLoad--;
			if (failCallback != null) {
				failCallback(assetPath, ctx);
			} else {
        Log.warn("Failed to load asset: " + assetPath );
      }
		}, ctx);
 		ctx.assetsRemainingToLoad++;
	}

	static function onInit(ctx:AppContext):Void {
		RL.windowOpen(1024, 1280, "Hello, World! (Haxe)", RL.FLAG_MSAA_4X_HINT);
		RL.setTargetFps(60);

		queueAsset(fontPath, ctx);
		queueAsset(modelPath, ctx);
		queueAsset(spritePath, ctx);
		queueAsset(bgmPath, ctx, (assetPath:String, _:AppContext) -> {
			Log.info("loaded " + assetPath);
			bgm = RL.musicCreate(assetPath);
			RL.musicSetLoop(bgm, true);
			RL.musicPlay(bgm);
		}, (assetPath:String, _:AppContext) -> {
			Log.warn("Failed to load asset: " + assetPath);
		});
	}

	static function onTick(ctx:AppContext):Void {
		if (ctx.assetsRemainingToLoad > 0)
			return;

		if (komika == 0) {
			greyAlphaColor = RL.colorCreate(0, 0, 0, 128);
			RL.enableLighting();
			RL.setLightDirection(-0.6, -1.0, -0.5);
			RL.setLightAmbient(0.25);

			komika = RL.fontCreate(fontPath, fontSize);
			komikaSmall = RL.fontCreate(fontPath, smallFontSize);
			gumshoe = RL.modelCreate(modelPath);
			sprite = RL.sprite3dCreate(spritePath);
			camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
			RL.camera3dSetActive(camera);
			RL.modelSetAnimation(gumshoe, 1);
			RL.modelSetAnimationSpeed(gumshoe, 1.0);
			RL.modelSetAnimationLoop(gumshoe, true);
			lastTime = RL.getTime();
			countdownTimer = 5.0;
		}

		var currentTime = RL.getTime();
		var deltaTime = currentTime - lastTime;
		totalTime += deltaTime;
		lastTime = currentTime;
		countdownTimer -= deltaTime;
		if (countdownTimer <= 0) {
			RL.requestStop();
			return;
		}

		RL.musicUpdateAll();

		RL.renderBegin();
		var bgColor = RL.colorCreate(245, 245, 245, 255);
		RL.renderClearBackground(bgColor);
		RL.renderBeginMode3D();
		RL.modelAnimate(gumshoe, deltaTime);
		RL.modelSetTransform(gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		RL.modelDraw(gumshoe, bgColor);
		RL.sprite3dSetTransform(sprite, 0.0, 0.0, 0.0, 1.0);
		RL.sprite3dDraw(sprite, bgColor);
		RL.renderEndMode3D();

		var screen = RL.windowGetScreenSize();
		var w = Std.int(screen.x);
		var h = Std.int(screen.y);
		var textSize = RL.textMeasureEx(komika, message, fontSize, 0);
		var textX = Std.int((w - textSize.x) / 2);
		var textY = Std.int((h - textSize.y) / 2);

		var blue = RL.colorCreate(0, 121, 241, 255);
		RL.textDrawEx(komika, message, textX, textY, fontSize, 1.0, blue);

		var remaining = "Remaining: " + (Math.floor(countdownTimer * 100.0) / 100.0);
		var elapsed = "Elapsed: " + (Math.floor(totalTime * 100.0) / 100.0);
		var mouse = RL.inputGetMouseState();
		var mouseText = "Mouse: ("
			+ mouse.x
			+ ", "
			+ mouse.y
			+ ") w:"
			+ mouse.wheel
			+ " b:["
			+ mouse.left
			+ ", "
			+ mouse.right
			+ ", "
			+ mouse.middle
			+ "]";

		var black = RL.colorCreate(0, 0, 0, 255);
		RL.textDrawEx(komikaSmall, remaining, 10, 36, smallFontSize, 1.0, black);
		RL.textDrawEx(komikaSmall, elapsed, 10, 56, smallFontSize, 1.0, black);
		RL.textDrawEx(komikaSmall, mouseText, 10, 76, smallFontSize, 1.0, black);
		RL.textDrawFpsEx(komikaSmall, 10, 10, smallFontSize, greyAlphaColor);

		RL.renderEnd();

		RL.colorDestroy(bgColor);
		RL.colorDestroy(blue);
		RL.colorDestroy(black);
	}

	static function onShutdown(ctx:AppContext):Void {
		RL.disableLighting();
		if (bgm != 0)
			RL.musicDestroy(bgm);
		if (sprite != 0)
			RL.sprite3dDestroy(sprite);
		if (gumshoe != 0)
			RL.modelDestroy(gumshoe);
		if (komika != 0)
			RL.fontDestroy(komika);
		if (komikaSmall != 0)
			RL.fontDestroy(komikaSmall);
		if (greyAlphaColor != 0)
			RL.colorDestroy(greyAlphaColor);
		if (camera != 0)
			RL.camera3dDestroy(camera);
		RL.deinit();

    // for now, we have to close the window after deinit().
    // RayLib's CloseWindow will destroy the GPU backed elements (like Texture, etc) and then their
    // cleanup will segfault.
    // TODO:  Consider moving windowCreate into rl_init() so rl owns window lifecycle?
		RL.windowClose();
	}

	static function main():Void {
 		RL.loggerSetLevel(RL.LOGGER_LEVEL_WARN);

    var ctx:AppContext = {
			assetsRemainingToLoad: 0
		};

    RL.init();
		RL.setAssetHost(ASSET_HOST);
		RL.loaderClearCache();
		RL.run(onInit, onTick, onShutdown, ctx);
	}
}
