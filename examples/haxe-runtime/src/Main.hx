package;

import rl.Log;
import rl.RL;
import rl.RLHandle;

typedef AppContext = {
	var ?loadingGroup:rl.RLTaskGroup;
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
	var countdownTimer:Float;
	var totalTime:Float;
	var lastTime:Float;
}

enum abstract RTResult(Int) from Int to Int {
	var RT_SUCCESS = 0;
	var RT_FAILED = -1;
	var RT_STOPPED = 1;
}

interface IRuntime {
	function onInit():RTResult;
	function onTick(deltaTime:Float):RTResult;
	function onShutdown():Void;
}

class MyRuntime implements IRuntime {
	static inline final SCREEN_WIDTH:Int = 1024;
	static inline final SCREEN_HEIGHT:Int = 1280;
	static inline final SCREEN_TITLE:String = "Hello, World! (Haxe)";
	static inline final SCREEN_FLAGS:Int = RL.FLAG_MSAA_4X_HINT;
	static inline final MONO_FONT_SIZE:Int = 24;
	static inline final SMALL_FONT_SIZE:Int = 16;
	static inline final MONO_FONT_PATH:String = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
	static inline final SMALL_FONT_PATH:String = "assets/fonts/Komika/KOMIKAH_.ttf";
	static inline final MODEL_PATH:String = "assets/models/gumshoe/gumshoe.glb";
	static inline final SPRITE_PATH:String = "assets/sprites/logo/wg-logo-bw-alpha.png";
	static inline final BGM_PATH:String = "assets/music/ethernight_club.mp3";

	#if (emscripten || PLATFORM_WEB)
	static final ASSET_HOST:String = "./";
	#else
	static final ASSET_HOST:String = "https://localhost:4444";
	#end

	var ctx:AppContext;
	var runtimeResult:RTResult = RT_SUCCESS;

	public function new() {
		ctx = createContext();
	}

	static function createContext():AppContext {
		return {
			monoFontSize: MONO_FONT_SIZE,
			smallFontSize: SMALL_FONT_SIZE,
			message: "Hello, World!",
			countdownTimer: 5.0,
			totalTime: 0.0,
			lastTime: 0.0
		};
	}

	function setupScene():Void {
		var musicTask = RL.loaderImportAssetAsync(BGM_PATH);
		if (RL.loaderTaskIsValid(musicTask)) {
			RL.loaderAddTask(musicTask, (path, loadedCtx) -> {
				loadedCtx.bgm = RL.musicCreate(path);
				RL.musicSetLoop(loadedCtx.bgm, true);
				RL.musicPlay(loadedCtx.bgm);
			}, null, ctx);
		} else {
			Log.warn("Failed to create music import task");
		}

		ctx.bgColor = RL.colorCreate(245, 245, 245, 255);
		ctx.fpsColor = RL.colorCreate(0, 121, 241, 255);
		ctx.camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);

		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		RL.camera3dSetActive(ctx.camera);

		ctx.lastTime = RL.getTime();
		ctx.countdownTimer = 5.0;
		ctx.totalTime = 0.0;

		RL.renderBegin();
		RL.renderClearBackground(ctx.bgColor);
		RL.renderEnd();
	}

	function createLoadingGroup():Void {
		ctx.loadingGroup = RL.loaderCreateTaskGroup(
			(group, loadedCtx) -> {
				loadedCtx.loadingGroup = null;
			},
			(group, loadedCtx) -> {
				Log.error("asset import failed: " + group.failedPaths().join(", "));
				loadedCtx.loadingGroup = null;
				runtimeResult = RT_FAILED;
			},
			ctx
		);
		ctx.loadingGroup.addImportTask(MODEL_PATH, (path, loadedCtx) -> {
			loadedCtx.model = RL.modelCreate(path);
			RL.modelSetAnimation(loadedCtx.model, 1);
			RL.modelSetAnimationSpeed(loadedCtx.model, 1.0);
			RL.modelSetAnimationLoop(loadedCtx.model, true);
		});
		ctx.loadingGroup.addImportTask(SPRITE_PATH, (path, loadedCtx) -> {
			loadedCtx.sprite = RL.sprite3dCreate(path);
		});
		ctx.loadingGroup.addImportTask(MONO_FONT_PATH, (path, loadedCtx) -> {
			loadedCtx.monoFont = RL.fontCreate(path, loadedCtx.monoFontSize);
		});
		ctx.loadingGroup.addImportTask(SMALL_FONT_PATH, (path, loadedCtx) -> {
			loadedCtx.smallFont = RL.fontCreate(path, loadedCtx.smallFontSize);
		});
	}

	public function onInit():RTResult {
		ctx = createContext();
		runtimeResult = RT_SUCCESS;

		var errCode = RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
			assetHost: ASSET_HOST,
		});
		if (errCode != 0) {
			Log.error("RL.init failed: " + errCode);
			return RT_FAILED;
		}

		RL.loaderClearCache();
		RL.setTargetFps(60);
		setupScene();
		createLoadingGroup();
		return RT_SUCCESS;
	}

	public function onTick(deltaTime:Float):RTResult {
		if (runtimeResult != RT_SUCCESS) {
			return runtimeResult;
		}

		if (ctx.loadingGroup != null && ctx.loadingGroup.process() > 0) {
			return RT_SUCCESS;
		}

		if (deltaTime <= 0) {
			var currentTime = RL.getTime();
			deltaTime = currentTime - ctx.lastTime;
			ctx.lastTime = currentTime;
		} else {
			ctx.lastTime = RL.getTime();
		}

		ctx.totalTime += deltaTime;
		ctx.countdownTimer -= deltaTime;
		if (ctx.countdownTimer <= 0) {
			return RT_STOPPED;
		}

		RL.musicUpdateAll();

		RL.renderBegin();
		RL.renderClearBackground(ctx.bgColor);
		RL.renderBeginMode3D();
		if (ctx.model != 0) {
			RL.modelAnimate(ctx.model, deltaTime);
			RL.modelSetTransform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
			RL.modelDraw(ctx.model, RL.COLOR_WHITE);
		}
		if (ctx.sprite != 0) {
			RL.sprite3dSetTransform(ctx.sprite, 0.0, 0.0, 0.0, 1.0);
			RL.sprite3dDraw(ctx.sprite, RL.COLOR_WHITE);
		}
		RL.renderEndMode3D();

		drawOverlay();
		RL.renderEnd();

		return RT_SUCCESS;
	}

	function drawOverlay():Void {
		var screen = RL.windowGetScreenSize();
		var w = Std.int(screen.x);
		var h = Std.int(screen.y);

		if (ctx.monoFont != 0) {
			var textSize = RL.textMeasureEx(ctx.monoFont, ctx.message, ctx.monoFontSize, 0);
			var textX = Std.int((w - textSize.x) / 2);
			var textY = Std.int((h - textSize.y) / 2);
			RL.textDrawEx(ctx.monoFont, ctx.message, textX, textY, ctx.monoFontSize, 1.0, RL.COLOR_BLUE);
		} else {
			var fallbackWidth = RL.textMeasure(ctx.message, 16);
			var fallbackX = Std.int((w - fallbackWidth) / 2);
			RL.textDraw(ctx.message, fallbackX, Std.int(h / 2), ctx.smallFontSize, RL.COLOR_BLUE);
		}

		var remaining = "Remaining: " + (Math.floor(ctx.countdownTimer * 100.0) / 100.0);
		var elapsed = "Elapsed: " + (Math.floor(ctx.totalTime * 100.0) / 100.0);
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

		if (ctx.monoFont != 0) {
			RL.textDrawEx(ctx.monoFont, remaining, 10, 36, 16, 1.0, RL.COLOR_BLACK);
		} else {
			RL.textDraw(remaining, 10, 36, 16, RL.COLOR_BLACK);
		}

		if (ctx.smallFont != 0) {
			RL.textDrawEx(ctx.smallFont, elapsed, 10, 56, ctx.smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(ctx.smallFont, mouseText, 10, 76, ctx.smallFontSize, 1.0, RL.COLOR_BLACK);
			RL.textDrawFpsEx(ctx.smallFont, 10, 10, ctx.smallFontSize, ctx.fpsColor);
		} else {
			RL.textDraw(elapsed, 10, 56, ctx.smallFontSize, RL.COLOR_BLACK);
			RL.textDraw(mouseText, 10, 76, ctx.smallFontSize, RL.COLOR_BLACK);
			RL.textDrawFps(10, 10);
		}
	}

	public function onShutdown():Void {
		RL.disableLighting();
		RL.deinit();
		ctx = createContext();
	}
}

typedef Runtime = MyRuntime;

class Main {
	#if emscripten
	@:keep static final wasmExportsClass = RuntimeWasmExports;
	#end

	static var instance:IRuntime = null;

	@:exportc.init("rt_boot")
	static function rt_boot():Int {
		if (instance == null) {
			instance = new Runtime();
		}
		return RT_SUCCESS;
	}

	@:exportc("rt_init")
	static function rt_init(_hostData:cpp.RawPointer<cpp.Void>):Int {
		if (instance == null) {
			return RT_FAILED;
		}
		return instance.onInit();
	}

	@:exportc("rt_tick")
	static function rt_tick(deltaTime:Float):Int {
		var rc = RL.tick();
		if (rc == RL.TICK_FAILED) {
			return RT_FAILED;
		}
		if (rc == RL.TICK_WAITING) {
			return RT_SUCCESS;
		}
		if (RL.windowCloseRequested()) {
			return RT_STOPPED;
		}
		if (instance == null) {
			return RT_FAILED;
		}
		return instance.onTick(deltaTime);
	}

	@:exportc.deinit("rt_shutdown")
	static function rt_shutdown():Void {
		if (instance != null) {
			instance.onShutdown();
			instance = null;
		}
	}

	static function main():Void {
		RL.loggerSetLevel(RL.LOGGER_LEVEL_DEBUG);

		#if (emscripten || PLATFORM_WEB)
		return;
		#else
		if (rt_boot() != RT_SUCCESS) {
			Sys.exit(1);
		}
		if (rt_init(null) != RT_SUCCESS) {
			rt_shutdown();
			Sys.exit(1);
		}

		var lastFrameTime = haxe.Timer.stamp();
		while (true) {
			var currentTime = haxe.Timer.stamp();
			var deltaTime = currentTime - lastFrameTime;
			lastFrameTime = currentTime;
			var tickRc = rt_tick(deltaTime);
			if (tickRc > 0) {
				break;
			}
			if (tickRc < 0) {
				rt_shutdown();
				Sys.exit(1);
			}
			Sys.sleep(0.001);
		}
		rt_shutdown();
		#end
	}
}
