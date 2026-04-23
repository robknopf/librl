package;

import rl.RL;
import rl.RLHandle;
import rl.Log;

typedef AppContext = {
	var ?monoFontSize:Int;
	var ?monoFont:RLHandle;
	var ?smallFont:RLHandle;
	var ?smallFontSize:Int;
	var ?model:RLHandle;
	var ?sprite:RLHandle;
	var ?bgm:RLHandle;
	var ?camera:RLHandle;
	var ?bgColor:RLHandle;
	var ?fpsColor:RLHandle;
	var ?message:String;
}

class Main {
	#if PLATFORM_WEB
	static final ASSET_HOST:String = "./";
	#else
	static final ASSET_HOST:String = "https://localhost:4444";
	#end

	static var countdownTimer:Float = 5.0;
	static var totalTime:Float = 0.0;
	static var lastTime:Float = 0.0;

	static function onInit(ctx:AppContext):Void {
		RL.windowOpen(1024, 1280, "Hello, World! (Haxe)", RL.FLAG_MSAA_4X_HINT);
		RL.setTargetFps(60);

		var musicTask = RL.loaderImportAssetAsync("assets/music/ethernight_club.mp3");
		if (RL.loaderTaskIsValid(musicTask)) {
			RL.loaderQueueTask(musicTask, (path, ctx) -> {
				ctx.bgm = RL.musicCreate(path);
				RL.musicSetLoop(ctx.bgm, true);
				RL.musicPlay(ctx.bgm);
			}, null, ctx);
		} else {
			Log.warn("Failed to create music import task");
		}

		Log.info("here");

		var tasks = [
			RL.loaderImportAssetAsync("assets/models/gumshoe/gumshoe.glb"),
			RL.loaderImportAssetAsync("assets/sprites/logo/wg-logo-bw-alpha.png"),
			RL.loaderImportAssetAsync("assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"),
			RL.loaderImportAssetAsync("assets/fonts/Komika/KOMIKAH_.ttf"),
		];
		Log.info("here 2");
		var result = RL.loaderWaitTasks(tasks);
		Log.info("past loaderWaitTasks");
		//Log.info(result);

		ctx.model = RL.modelCreate("assets/models/gumshoe/gumshoe.glb");
		ctx.sprite = RL.sprite3dCreate("assets/sprites/logo/wg-logo-bw-alpha.png");
		ctx.monoFont = RL.fontCreate("assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf", ctx.monoFontSize);
		ctx.smallFont = RL.fontCreate("assets/fonts/Komika/KOMIKAH_.ttf", ctx.smallFontSize);
		ctx.bgColor = RL.colorCreate(245, 245, 245, 255);
		ctx.fpsColor = RL.colorCreate(0, 121, 241, 255);
		ctx.message = "Hello, World!";


		ctx.camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		RL.camera3dSetActive(ctx.camera);

		if (ctx.model != null) {
			RL.modelSetAnimation(ctx.model, 1);
			RL.modelSetAnimationSpeed(ctx.model, 1.0);
			RL.modelSetAnimationLoop(ctx.model, true);
		}
		lastTime = RL.getTime();
		countdownTimer = 5.0;
	}

	static function onTick(ctx:AppContext):Void {
		var currentTime = RL.getTime();
		var deltaTime = currentTime - lastTime;
		totalTime += deltaTime;
		lastTime = currentTime;
		countdownTimer -= deltaTime;
		if (countdownTimer <= 0) {
			RL.stop();
			return;
		}

		RL.musicUpdateAll();

		RL.renderBegin();
		RL.renderClearBackground(ctx.bgColor);
		RL.renderBeginMode3D();
		if (ctx.model != null) {
			RL.modelAnimate(ctx.model, deltaTime);
			RL.modelSetTransform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
			RL.modelDraw(ctx.model, RL.COLOR_WHITE);
		}
		if (ctx.sprite != null) {
			RL.sprite3dSetTransform(ctx.sprite, 0.0, 0.0, 0.0, 1.0);
			RL.sprite3dDraw(ctx.sprite, RL.COLOR_WHITE);
		}
		RL.renderEndMode3D();

		var screen = RL.windowGetScreenSize();
		var w = Std.int(screen.x);
		var h = Std.int(screen.y);
		if (ctx.monoFont != null) {
			var textSize = RL.textMeasureEx(ctx.monoFont, ctx.message, ctx.monoFontSize, 0);
			var textX = Std.int((w - textSize.x) / 2);
			var textY = Std.int((h - textSize.y) / 2);
			RL.textDrawEx(ctx.monoFont, ctx.message, textX, textY, ctx.monoFontSize, 1.0, RL.COLOR_BLUE);
		} else {
			var fallbackWidth = RL.textMeasure(ctx.message, 16);
			var fallbackX = Std.int((w - fallbackWidth) / 2);
			var fallbackY = Std.int(h / 2);
			RL.textDraw(ctx.message, fallbackX, fallbackY, ctx.smallFontSize, RL.COLOR_BLUE);
		}

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

		if (ctx.monoFont != null) {
			RL.textDrawEx(ctx.monoFont, remaining, 10, 36, 16, 1.0, RL.COLOR_BLACK);
		} else {
			RL.textDraw(remaining, 10, 36, 16, RL.COLOR_BLACK);
		}
		if (ctx.smallFont != null) {
			RL.textDrawEx(ctx.smallFont, elapsed, 10, 56, ctx.smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(ctx.smallFont, mouseText, 10, 76, ctx.smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawFpsEx(ctx.smallFont, 10, 10, ctx.smallFontSize, ctx.bgColor);
		} else {
			RL.textDraw(elapsed, 10, 56, ctx.smallFontSize, RL.COLOR_BLACK);
			RL.textDraw(mouseText, 10, 76, ctx.smallFontSize, RL.COLOR_BLACK);
			RL.textDrawFps(10, 10);
		}

		RL.renderEnd();
	}

	static function onShutdown(ctx:AppContext):Void {
		RL.disableLighting();

		RL.deinit();
		// for now, we have to close the window after deinit().
		// RayLib's CloseWindow will destroy the GPU backed elements (like Texture, etc) and then their
		// cleanup will segfault.
		// TODO:  Consider moving windowCreate into rl_init() so rl owns window lifecycle?
		RL.windowClose();
	}

	static function main():Void {
		trace("MAIN START");
		RL.loggerSetLevel(RL.LOGGER_LEVEL_WARN);

		trace("About to RL.init");
		try {
			RL.init();
			trace("RL.init done");
		} catch(e) {
			trace("RL.init error: " + e);
		}
		trace("About to setAssetHost");
		RL.setAssetHost(ASSET_HOST);
		trace("About to loaderClearCache");
		RL.loaderClearCache();
		trace("About to create ctx");

		var ctx:AppContext = {
			monoFontSize: 24,
			smallFontSize: 16,
			message: ""
		};
		trace("About to RL.run");
		RL.run(onInit, onTick, onShutdown, ctx);
		trace("RL.run returned");
	}
}
