package;

import InjectLibRL;
import rl.RL;
import rl.Log;
import AssetHelper;
import Context;

class Main {
	#if PLATFORM_WEB
	static final ASSET_HOST:String = "./";
	#else
	static final ASSET_HOST:String = "https://localhost:4444";
	#end

	/*
		static inline var fontSize:Int = 24;
		static inline var smallFontSize:Int = 16;
		static inline var modelPath = "assets/models/gumshoe/gumshoe.glb";
		static inline var spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
		static inline var monoFontPath = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
		static inline var fontPath = "assets/fonts/Komika/KOMIKAH_.ttf";
		static inline var bgmPath = "assets/music/ethernight_club.mp3";
	 */
	static inline var message = "Hello World!";

	/*
		static var komika:Int = 0;
		static var komikaSmall:Int = 0;
		static var gumshoe:Int = 0;
		static var sprite:Int = 0;
		static var camera:Int = 0;
		static var bgm:Int = 0;
		static var greyAlphaColor:Int = 0;
		static var blue = RL.colorCreate(0, 121, 241, 255);
		static var bgColor = RL.colorCreate(245, 245, 245, 255);
	 */
	static var countdownTimer:Float = 5.0;
	static var totalTime:Float = 0.0;
	static var lastTime:Float = 0.0;

	static function onInit(ctx:AppContext):Void {
		RL.windowOpen(1024, 1280, "Hello, World! (Haxe)", RL.FLAG_MSAA_4X_HINT);
		RL.setTargetFps(60);


		var fontSize:Int = 24;
		var smallFontSize:Int = 16;
		ctx.assets.models["gumshoe"] = {path:"assets/models/gumshoe/gumshoe.glb"};
		ctx.assets.sprites["logo"] = {path:"assets/sprites/logo/wg-logo-bw-alpha.png"};
		ctx.assets.fonts["mono"] = {path:"assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf", size: smallFontSize};
		ctx.assets.fonts["komika"] = {path:"assets/fonts/Komika/KOMIKAH_.ttf", size: fontSize};
		ctx.assets.fonts["komikaSmall"] = {path:"assets/fonts/Komika/KOMIKAH_.ttf", size: smallFontSize};
		ctx.assets.music["bgm"] = {path:"assets/music/ethernight_club.mp3"};
		ctx.assets.colors["bgColor"] = {r:245, g:245, b:245, a:255};
		ctx.assets.colors["greyAlpha"] = {r:0, g:0, b:0, a:128};

		// preload all assets
		AssetHelper.queueContextAssets(ctx);
		AssetHelper.awaitQueuedAssets();

		//AssetHelper.queueAsset(fontPath, ctx);
		//AssetHelper.queueAsset(monoFontPath, ctx);
		//AssetHelper.queueAsset(modelPath, ctx);
		//AssetHelper.queueAsset(spritePath, ctx);
		//AssetHelper.queueAsset(bgmPath, ctx, (assetPath, ctx) -> {
			//Log.info("loaded " + assetPath);
			var bgm = ctx.assets.music["bgm"]?.id;
			if (bgm != null) {
			//bgm = RL.musicCreate(assetPath);
				RL.musicSetLoop(bgm, true);
				RL.musicPlay(bgm);
			}
		//}, (assetPath, ctx) -> {
		//	Log.warn("Failed to load asset: " + assetPath);
		//});

		ctx.camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
		//greyAlphaColor = RL.colorCreate(0, 0, 0, 128);
		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		RL.camera3dSetActive(ctx.camera);

		// spin until assets are ready
		AssetHelper.awaitQueuedAssets();

		//komika = RL.fontCreate(fontPath, fontSize);
		//komikaSmall = RL.fontCreate(fontPath, smallFontSize);
		//monoFontSmall = RL.fontCreate(monoFontPath, smallFontSize);
		//gumshoe = RL.modelCreate(modelPath);
		//sprite = RL.sprite3dCreate(spritePath);
		var gumshoe = ctx.assets.models["gumshoe"]?.id;
		if (gumshoe != null) {
			RL.modelSetAnimation(gumshoe, 1);
			RL.modelSetAnimationSpeed(gumshoe, 1.0);
			RL.modelSetAnimationLoop(gumshoe, true);
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
			RL.requestStop();
			return;
		}

		RL.musicUpdateAll();

		var bgColor = ctx.assets.colors["bgColor"]?.id ?? RL.COLOR_RAYWHITE;  
		var gumshoe = ctx.assets.models["gumshoe"]?.id;
		var logo = ctx.assets.sprites["logo"]?.id;
		var komika = ctx.assets.fonts["komika"]?.id;
		var komikaSmall = ctx.assets.fonts["komikaSmall"]?.id;
		var mono = ctx.assets.fonts["mono"]?.id;
		var smallFontSize = 16;
		
		RL.renderBegin();
		RL.renderClearBackground(bgColor);
		RL.renderBeginMode3D();
		if (gumshoe != null) {
			RL.modelAnimate(gumshoe, deltaTime);
			RL.modelSetTransform(gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
			RL.modelDraw(gumshoe, RL.COLOR_WHITE);
		}
		if (logo != null) {
			RL.sprite3dSetTransform(logo, 0.0, 0.0, 0.0, 1.0);
			RL.sprite3dDraw(logo, RL.COLOR_WHITE);
		}
		RL.renderEndMode3D();

		var screen = RL.windowGetScreenSize();
		var w = Std.int(screen.x);
		var h = Std.int(screen.y);
		if (komika != null) {
			var textSize = RL.textMeasureEx(komika, message, 16, 0);
			var textX = Std.int((w - textSize.x) / 2);
			var textY = Std.int((h - textSize.y) / 2);
			RL.textDrawEx(komika, message, textX, textY, smallFontSize, 1.0, RL.COLOR_BLUE);
		} else {
			var fallbackWidth = RL.textMeasure(message, smallFontSize);
			var fallbackX = Std.int((w - fallbackWidth) / 2);
			var fallbackY = Std.int(h / 2);
			RL.textDraw(message, fallbackX, fallbackY, smallFontSize, RL.COLOR_BLUE);
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

		if (mono != null) {
			RL.textDrawEx(mono, remaining, 10, 36, smallFontSize, 1.0, RL.COLOR_BLACK);
		} else {
			RL.textDraw(remaining, 10, 36, smallFontSize, RL.COLOR_BLACK);
		}
		if (komikaSmall != null) {
			RL.textDrawEx(komikaSmall, elapsed, 10, 56, smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(komikaSmall, mouseText, 10, 76, smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawFpsEx(komikaSmall, 10, 10, smallFontSize, ctx.assets.colors["greyAlpha"]?.id ?? RL.COLOR_LIME);
		} else {
			RL.textDraw(elapsed, 10, 56, smallFontSize, RL.COLOR_BLACK);
			RL.textDraw(mouseText, 10, 76, smallFontSize, RL.COLOR_BLACK);
			RL.textDrawFps(10, 10);
		}

		RL.renderEnd();
		
	}

	static function onShutdown(ctx:AppContext):Void {
		RL.disableLighting();
		Context.destroy(ctx);
		RL.deinit();

		// for now, we have to close the window after deinit().
		// RayLib's CloseWindow will destroy the GPU backed elements (like Texture, etc) and then their
		// cleanup will segfault.
		// TODO:  Consider moving windowCreate into rl_init() so rl owns window lifecycle?
		RL.windowClose();
	}

	static function main():Void {
		RL.loggerSetLevel(RL.LOGGER_LEVEL_WARN);

		RL.init();
		RL.setAssetHost(ASSET_HOST);
		RL.loaderClearCache();

		var ctx:AppContext = Context.create();


		RL.run(onInit, onTick, onShutdown, ctx);
	}
}
