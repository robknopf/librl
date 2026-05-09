package;

import rl.Log;
import rl.RL;
import rl.RLHandle;

#if cpp
@:cppFileCode('
#include "Main.h"

#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#define EXAMPLE_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define EXAMPLE_EXPORT extern "C" HXCPP_EXTERN_CLASS_ATTRIBUTES
#endif

extern "C" {
EXAMPLE_EXPORT int example_init(void) {
	return Main_obj::exampleInit();
}

EXAMPLE_EXPORT int example_frame(float dt) {
	return Main_obj::exampleFrame(dt);
}

EXAMPLE_EXPORT void example_shutdown(void) {
	Main_obj::exampleShutdown();
}
}
')
#end
class Main {
	#if emscripten
	// Pulls in example-local wasm export/linker flags without putting them in the librl binding.
	@:keep static final wasmExportsClass = ExampleWasmExports;
	#end

	static inline final RESULT_OK:Int = 0;
	static inline final RESULT_ERROR:Int = -1;
	static inline final RESULT_QUIT:Int = 1;

	static inline final SCREEN_WIDTH:Int = 1024;
	static inline final SCREEN_HEIGHT:Int = 1280;
	static inline final MONO_FONT_SIZE:Int = 24;
	static inline final SMALL_FONT_SIZE:Int = 16;
	static inline final MODEL_PATH:String = "assets/models/gumshoe/gumshoe.glb";
	static inline final SPRITE_PATH:String = "assets/sprites/logo/wg-logo-bw-alpha.png";
	static inline final MONO_FONT_PATH:String = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
	static inline final SMALL_FONT_PATH:String = "assets/fonts/Komika/KOMIKAH_.ttf";
	static inline final BGM_PATH:String = "assets/music/ethernight_club.mp3";

	#if (emscripten || PLATFORM_WEB)
	static final ASSET_HOST:String = "./";
	#else
	static final ASSET_HOST:String = "https://localhost:4444";
	#end

	static var initialized:Bool = false;
	static var loadingGroup:rl.RLTaskGroup = null;
	static var monoFont:RLHandle = 0;
	static var smallFont:RLHandle = 0;
	static var model:RLHandle = 0;
	static var sprite:RLHandle = 0;
	static var bgm:RLHandle = 0;
	static var camera:RLHandle = 0;
	static var bgColor:RLHandle = 0;
	static var fpsColor:RLHandle = 0;
	static var countdownTimer:Float = 5.0;
	static var totalTime:Float = 0.0;
	static var lastTime:Float = 0.0;
	static var loadFailed:Bool = false;
	static var loadingMessage:String = "Loading...";
	static var spriteAnchor = {x:0, y:4, z:0};

	@:keep public static function exampleInit():Int {
		if (initialized) {
			return RESULT_OK;
		}

		var rc = RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: "Hello, World! (Haxe simple)",
			windowFlags: RL.FLAG_MSAA_4X_HINT,
			assetHost: ASSET_HOST,
		});
		if (rc != 0) {
			Log.error("RL.init failed: " + rc);
			return RESULT_ERROR;
		}

		initialized = true;
		RL.loaderClearCache();
		RL.setTargetFps(60);

		setupScene();
		queueAssets();
		drawLoadingFrame();
		return RESULT_OK;
	}

	static function setupScene():Void {
		bgColor = RL.colorCreate(245, 245, 245, 255);
		fpsColor = RL.colorCreate(0, 121, 241, 255);
		camera = RL.camera3dCreate(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, RL.CAMERA_PERSPECTIVE);
		RL.enableLighting();
		RL.setLightDirection(-0.6, -1.0, -0.5);
		RL.setLightAmbient(0.25);
		RL.camera3dSetActive(camera);

		lastTime = RL.getTime();
		countdownTimer = 5.0;
		totalTime = 0.0;
		loadFailed = false;
	}

	static function queueAssets():Void {
		// Music is independent of the startup gate. It can begin playing as soon as it is cached.
		var musicTask = RL.loaderImportAssetAsync(BGM_PATH);
		if (RL.loaderTaskIsValid(musicTask)) {
			RL.loaderAddTask(musicTask, (path, _) -> {
				bgm = RL.musicCreate(path);
				RL.musicSetLoop(bgm, true);
				RL.musicPlay(bgm);
			}, null, null);
		}

		// These assets are required before the main scene is useful, so group them and wait
		// in exampleFrame(). The callbacks run when each import finishes and create handles
		// from the cached local paths.
		loadingGroup = RL.loaderCreateTaskGroup(
			(_, _) -> {
				loadingGroup = null;
			},
			(group, _) -> {
				var errorMessage = "asset import failed: " + group.failedPaths().join(", ");
				Log.error(errorMessage);
				loadingGroup = null;
				loadingMessage = errorMessage;
				loadFailed = true;

			}
		);
		loadingGroup.addImportTask(MODEL_PATH, (path, _) -> {
			model = RL.modelCreate(path);
			RL.modelSetAnimation(model, 1);
			RL.modelSetAnimationSpeed(model, 1.0);
			RL.modelSetAnimationLoop(model, true);
			RL.modelSetTransform(model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		});
		loadingGroup.addImportTask(SPRITE_PATH, (path, _) -> {
			sprite = RL.sprite3dCreate(path);
			RL.sprite3dSetTransform(sprite, spriteAnchor.x, spriteAnchor.y, spriteAnchor.z, 1.0);
		});
		loadingGroup.addImportTask(MONO_FONT_PATH, (path, _) -> {
			monoFont = RL.fontCreate(path, MONO_FONT_SIZE);
		});
		loadingGroup.addImportTask(SMALL_FONT_PATH, (path, _) -> {
			smallFont = RL.fontCreate(path, SMALL_FONT_SIZE);
		});
	}

	public static function animateFrame(dt:Float) {
		if (model != 0 ){
			RL.modelAnimate(model, dt);
		}

		if (sprite != 0) {
			RL.sprite3dSetTransform(sprite, spriteAnchor.x, spriteAnchor.y + Math.sin(totalTime * 2.0) * 0.25, spriteAnchor.z, 1.0);
		}

	}

	@:keep public static function exampleFrame(hostDt:Float):Int {
		if (!initialized) {
			return RESULT_ERROR;
		}

		// `RL.tick()` advances librl's internal loader/barrier work. While it reports WAITING,
		// the app should not run frame logic yet.
		var tickRc = RL.tick();
		if (tickRc == RL.TICK_FAILED) {
			return RESULT_ERROR;
		}
		if (tickRc == RL.TICK_WAITING) {
			return RESULT_OK;
		}
		if (RL.windowCloseRequested()) {
			return RESULT_QUIT;
		}

		// Keep drawing a minimal frame while the required scene assets are still importing.
		if (loadFailed || (loadingGroup != null && loadingGroup.process() > 0)) {
			drawLoadingFrame();
			return RESULT_OK;
		}

		var dt = hostDt;
		if (dt <= 0) {
			var now = RL.getTime();
			dt = now - lastTime;
			lastTime = now;
		} else {
			lastTime = RL.getTime();
		}

		totalTime += dt;
		countdownTimer -= dt;
		if (countdownTimer <= 0) {
			return RESULT_QUIT;
		}

		animateFrame(dt);

		RL.musicUpdateAll();
		RL.renderBegin();
		RL.renderClearBackground(bgColor);
		RL.renderBeginMode3D();
		//if (model != 0) {
			RL.modelDraw(model, RL.COLOR_WHITE);
		//}
		//if (sprite != 0) {
			RL.sprite3dDraw(sprite, RL.COLOR_WHITE);
		//}
		RL.renderEndMode3D();
		drawOverlay();
		RL.renderEnd();
		return RESULT_OK;
	}

	static function drawLoadingFrame():Void {
		// Music is loaded outside the startup group, so keep its stream pumped even
		// while the visual scene is still waiting on required assets.
		RL.musicUpdateAll();

		RL.renderBegin();
		RL.renderClearBackground(bgColor != 0 ? bgColor : RL.COLOR_RAYWHITE);
		RL.textDraw(loadingMessage, 20, 20, 24, RL.COLOR_DARKGRAY);
		RL.renderEnd();
	}

	static function drawOverlay():Void {
		var screen = RL.windowGetScreenSize();
		var message = "Hello, World!";
		if (monoFont != 0) {
			var size = RL.textMeasureEx(monoFont, message, MONO_FONT_SIZE, 0);
			RL.textDrawEx(monoFont, message, Std.int((screen.x - size.x) / 2), Std.int((screen.y - size.y) / 2), MONO_FONT_SIZE, 1.0, RL.COLOR_BLUE);
		} else {
			RL.textDraw(message, 20, 20, 24, RL.COLOR_BLUE);
		}

		var remaining = "Remaining: " + (Math.floor(countdownTimer * 100.0) / 100.0);
		var elapsed = "Elapsed: " + (Math.floor(totalTime * 100.0) / 100.0);
		if (smallFont != 0) {
			RL.textDrawEx(smallFont, remaining, 10, 36, SMALL_FONT_SIZE, 1.0, RL.COLOR_BLACK);
			RL.textDrawEx(smallFont, elapsed, 10, 56, SMALL_FONT_SIZE, 1.0, RL.COLOR_BLACK);
			RL.textDrawFpsEx(smallFont, 10, 10, SMALL_FONT_SIZE, fpsColor);
		} else {
			RL.textDraw(remaining, 10, 36, 16, RL.COLOR_BLACK);
			RL.textDraw(elapsed, 10, 56, 16, RL.COLOR_BLACK);
			RL.textDrawFps(10, 10);
		}
	}

	@:keep public static function exampleShutdown():Void {
		if (!initialized) {
			return;
		}
		RL.disableLighting();
		RL.deinit();
		initialized = false;
		loadingGroup = null;
		monoFont = 0;
		smallFont = 0;
		model = 0;
		sprite = 0;
		bgm = 0;
		camera = 0;
		bgColor = 0;
		fpsColor = 0;
	}

	static function main():Void {
		RL.loggerSetLevel(RL.LOGGER_LEVEL_DEBUG);

		#if (emscripten || PLATFORM_WEB)
		return;
		#else
		if (exampleInit() != RESULT_OK) {
			Sys.exit(1);
		}

		var lastFrameTime = haxe.Timer.stamp();
		while (true) {
			var now = haxe.Timer.stamp();
			var dt = now - lastFrameTime;
			lastFrameTime = now;
			var rc = exampleFrame(dt);
			if (rc > 0) {
				break;
			}
			if (rc < 0) {
				exampleShutdown();
				Sys.exit(1);
			}
			Sys.sleep(0.001);
		}
		exampleShutdown();
		#end
	}
}
