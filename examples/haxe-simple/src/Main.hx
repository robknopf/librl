package;

import rl.Texture;
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
import rl.Types.RLHandle;
import rl.helpers.Log;
import haxe.io.Path;
import rl.Types.RLPickResult;
import rl.Types.RLAsyncVoid;
import InjectWasmExports;
//import test.TestImport;

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
	var model:RLHandle;
	var reloadCount:Int;
	var spriteYOffset:Float;
	var backgroundColor:RLHandle;
}

@:keep
class MainScript extends Script {
	final SCREEN_WIDTH:Int = 1024;
	final SCREEN_HEIGHT:Int = 1280;
	final SCREEN_TITLE:String = "simple (Haxe runtime)";
	final SCREEN_FLAGS:Int = Window.FLAG_MSAA_4X_HINT;

	// this doesn't work since we are a script.  emscripten/platform web isn't defined
	// TODO: figure out how to detect if we are running in a browser or not (ask the host?)
	#if (emscripten || PLATFORM_WEB || js)
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
	final BGM_1_PATH:String = "assets/music/ethernight_club.mp3";
	final BGM_2_PATH:String = "assets/music/dancing_on_the_edge.mp3";

	static var ctx:AppContext = null;

	var msg:String = "Hello from Haxe Simple Main !";
	var platformText:String = "Platform: <unknown>";

	public static function joinPath(pathComponents:haxe.Rest<String>):String {
		return Path.normalize(Path.join(pathComponents.toArray()));
	}

	@async
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
			model: 0,
			reloadCount: 0,
			spriteYOffset: 3.0,
			backgroundColor: 0
		};
		Logger.setLevel(Logger.LEVEL_WARN);
		var err = @await RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
			assetHost: ASSET_HOST,
			// fsRootDir: LOADER_CACHE_DIR
		});
		if (err != RL.INIT_OK) {
			trace("Main: onInit failed with error: " + err);
			return RT_FAILED;
		}
		Logger.setLevel(Logger.LEVEL_INFO);

		Window.setMonitor(1);

		Fs.clear();

		setupScene();

		// draw a blank frame while assets load
		Render.begin();
		Render.clearBackground(ctx.backgroundColor);
		Render.end();

		return RT_SUCCESS;
	}


	private function setupScene():Void {
		Render.enableLighting();
		Render.setLightDirection(-0.6, -1.0, -0.5);
		Render.setLightAmbient(0.25);
		ctx.camera = Camera3d.create(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, Camera3d.PERSPECTIVE);
		Camera3d.setActive(ctx.camera);
		ctx.greyAlphaColor = Color.create(0, 0, 0, 128);
		ctx.backgroundColor = Color.create(245, 245, 245, 255);
	}

	private function teardownScene():Void {
		Render.disableLighting();
		Camera3d.setActive(0);
		Camera3d.destroy(ctx.camera);
		ctx.camera = 0;
		Color.destroy(ctx.greyAlphaColor);
		ctx.greyAlphaColor = 0;
		Color.destroy(ctx.backgroundColor);
		ctx.backgroundColor = 0;
	}

	function loadAssets():Void {	
		ctx.model = Model.create(0);
		Model.setTransform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		Model.setAnimation(ctx.model, 1);
		Model.setAnimationSpeed(ctx.model, 1.0);
		Model.setAnimationLoop(ctx.model, true);
		Asset.addTask(Asset.ensureAsync(MODEL_PATH), (path, _) -> {
			var modelAsset = Model.loadAsset(MODEL_PATH);
			Model.setAsset(ctx.model, modelAsset);
		}, null, ctx);

		ctx.sprite = Sprite3d.create(0);
		Sprite3d.setTransform(ctx.sprite, 0.0, 0.0, ctx.spriteYOffset, 1.0);
		Asset.addTask(Asset.ensureAsync(SPRITE_PATH), (path, _) -> {
			var textureAsset = Texture.create(path);
			Sprite3d.setTexture(ctx.sprite, textureAsset);
		}, null, ctx);

		ctx.labelText2d = Text2d.create(0, KOMIKA_FONT_SIZE);
		Text2d.setContent(ctx.labelText2d, "rl_text2d: retained label");
		Text2d.setPosition(ctx.labelText2d, 10, 136);
		Text2d.setColor(ctx.labelText2d, Color.GREEN);
		
		Asset.addTask(Asset.ensureAsync(DEBUG_FONT_PATH), (path, _) -> {
			ctx.debugFont = Font.create(path, DEBUG_FONT_SIZE);
		}, null, ctx);

		Asset.addTask(Asset.ensureAsync(KOMIKA_FONT_PATH), (path, _) -> {
			ctx.komikaFont = Font.create(path, KOMIKA_FONT_SIZE);
			if (ctx.labelText2d != 0) {
				Text2d.setFont(ctx.labelText2d, ctx.komikaFont);
			}
		}, null, ctx);

		Asset.addTask(Asset.ensureAsync(BGM_2_PATH), (path, _) -> {
			ctx.bgm = Music.create(path);
			Music.setLoop(ctx.bgm, true);
			Music.play(ctx.bgm);
		}, null, ctx);
	}

	private function unloadAssets():Void {
		if (ctx.model != 0) {
			Model.destroy(ctx.model);
			ctx.model = 0;
		}
		if (ctx.sprite != 0) {
			Sprite3d.destroy(ctx.sprite);
			ctx.sprite = 0;
	}
		if (ctx.bgm != 0) {
			Music.destroy(ctx.bgm);
			ctx.bgm = 0;
		}
		if (ctx.debugFont != 0) {
			Font.destroy(ctx.debugFont);
			ctx.debugFont = 0;
		}
	}

	public function animateFrame(deltaTimeSec:Float):Void {
		if (ctx.model != 0) {
			Model.animate(ctx.model, deltaTimeSec);
		}

		var spriteX = 0.0;
		var spriteY = 0.0;
		var spriteZ = 0.0;

		// bob the sprite up and down
		var bobSpeed = 1.0;
		var bobHeight = 1.5;
		bobHeight = bobHeight * 2;
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

	override public function onTick(deltaTimeSec:Float):RTResult {
		// trace("Main: onTick called with deltaTimeMS: " + deltaTimeMS);
		ctx.elapsed = ctx.elapsed + deltaTimeSec;
		ctx.totalTime += deltaTimeSec;
		ctx.countdownTimer -= deltaTimeSec;
		if (ctx.countdownTimer <= 0) {
			// return RT_STOPPED;
		}

		//TestImport.test();

		animateFrame(deltaTimeSec);

		Music.updateAll();

		var mouse = Input.getMouseState();
		var mouseText = 'Mouse: (${mouse.x}, ${mouse.y}) w:${mouse.wheel} b:[${mouse.left}, ${mouse.right}, ${mouse.middle}]';
		var remainingText = 'Remaining: ${formatFixed(ctx.countdownTimer, 2)}';
		var elapsedText = 'Elapsed: ${formatFixed(ctx.totalTime, 2)}';

		msg = "Nothing picked!";

		var pickResult:RLPickResult;

		pickResult = Pick.model(ctx.camera, ctx.model, mouse.x, mouse.y);
		if (pickResult.hit) {
			trace('Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
			msg = 'Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
		}

		pickResult = Pick.sprite3d(ctx.camera, ctx.sprite, mouse.x, mouse.y);
		if (pickResult.hit) {
			trace('Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y);
			msg = 'Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + pickResult.point.y;
		}

		Render.begin();
		Render.clearBackground(ctx.backgroundColor);

		// 3d render
		Render.beginMode3d();

		Model.draw(ctx.model, Color.WHITE);
		Sprite3d.draw(ctx.sprite, Color.WHITE);

		Render.endMode3d();

		// 2D UI overlay
		var screen = Window.getScreenSize();
		var textSize = Text.measureEx(ctx.komikaFont, msg, KOMIKA_FONT_SIZE, 1.0);
		var textX = Std.int((screen.x - textSize.x) / 2);
		var textY = Std.int((screen.y - textSize.y) / 2);
		Text.drawEx(ctx.komikaFont, msg, textX, textY, KOMIKA_FONT_SIZE, 1.0, Color.BLUE);
		Text.drawEx(ctx.debugFont, remainingText, 10, 36, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, elapsedText, 10, 56, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, mouseText, 10, 76, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, 'Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, platformText, 10, 116, DEBUG_FONT_SIZE, 1.0, Color.BLACK);

		Text.drawFpsEx(ctx.debugFont, 10, 10, DEBUG_FONT_SIZE, ctx.greyAlphaColor);

		Text2d.draw(ctx.labelText2d);

		Render.end();

		return RT_SUCCESS;
	}


	public function getPlatformText():String {
		#if sys
		return 'Platform: ${RL.getPlatform()} (${Sys.systemName()})';
		#else
		return 'Platform: ${RL.getPlatform()} (Unknown)';
		#end
	}
	
	override public function onLoad(stashedData:Dynamic):RTResult {
		trace("Main: onLoad");
		if (stashedData != null) {
			ctx = stashedData;
			ctx.reloadCount++;
		}

		//Logger.setLevel(Logger.LEVEL_DEBUG);

		loadAssets();

		platformText = getPlatformText();

		/*
		// if we wanted to swap models on load (for giggles)
		var modelPath:String = "";
		if (ctx.reloadCount % 2 == 0) {
			modelPath = "assets/models/cultist/cultist.glb";
		} else {
			modelPath = "assets/models/gumshoe/gumshoe.glb";
		}

		Asset.addTask(Asset.ensureAsync(modelPath), (path, _) -> {
			var modelAsset = Model.loadAsset(path);
			// trace(modelAsset);
			Model.setAsset(ctx.model, modelAsset);
		}, (path, _) -> {
			Log.error('Failed to ensure asset: ${path}');
		}, ctx);

		// and swap the bgm on load
		if (ctx.bgm != 0) {
			// stop the bgm
			Music.stop(ctx.bgm);
			// release the asset
			Music.destroy(ctx.bgm);
			ctx.bgm = 0;
		}

		var bgmPath:String = "";
		switch (ctx.reloadCount % 3) {
			case 0:
				bgmPath = BGM_1_PATH;
			case 1:
				bgmPath = BGM_2_PATH;
			case 2:
				bgmPath = ""; // no bgm
		}

		if (bgmPath != "") {
			// load the new bgm
			ctx.bgm = Music.create(bgmPath);
			Music.setLoop(ctx.bgm, true);
			Music.play(ctx.bgm);
			Asset.addTask(Asset.ensureAsync(bgmPath), (path, _) -> {
				ctx.bgm = Music.create(path);
				Music.setLoop(ctx.bgm, true);
				Music.play(ctx.bgm);
			}, null, ctx);
		}
		*/
		return RT_SUCCESS;
	}

	override public function onUnload():Dynamic {
		trace("Main: onUnload");
		unloadAssets();
		return ctx;
	}

	@async
	override public function onShutdown() :RLAsyncVoid {
		trace("Main: onShutdown");
		teardownScene();
		@await RL.deinit();
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

///////////  Runtime ABI, called by host  ///////////

//typedef MainScript = MyMainScript;

typedef RTResult = Int;
final RT_SUCCESS:RTResult = 0;
final RT_FAILED:RTResult = -1;
final RT_STOPPED:RTResult = 1;

class Script {
	public function new() {}
	// provide a default implementation of onBoot that can be overridden
	@async public function onBoot():RTResult {
		var rc = @await RL.boot({
			canvasId: "renderCanvas",
		});
		if (rc != RL.BOOT_OK) {
			Log.error("RL.boot failed: " + rc);
			return RT_FAILED;
		}
		return RT_SUCCESS;
	}
	@async public function onInit():RTResult { return RT_SUCCESS; }
	public function onLoad(stashedData:Dynamic):RTResult { return RT_SUCCESS; }
	public function onUnload():Dynamic { return null; }
	public function onTick(deltaTimeSec:Float):RTResult { return RT_SUCCESS; }
	@async public function onShutdown() :RLAsyncVoid {  }
}

@:expose
@async
class Main {
	private static var _scriptInstance:Script = null;

	@:expose("_rt_boot")
	@:exportc.entry
	@async static function rt_boot():Int {
		if (_scriptInstance == null) {
			_scriptInstance = new MainScript();
		}
		return @await _scriptInstance.onBoot();
	}

	@:expose("_rt_init")
	@:exportc
	@async static function rt_init(_hostData:Dynamic):RTResult {
		if (_scriptInstance != null) {
			return @await _scriptInstance.onInit();
		}
		return RT_FAILED;
	}

	@:expose("_rt_load")
	@:exportc
	static function rt_load(stashedData:Dynamic):RTResult {
		try {
			if (_scriptInstance == null) {
				_scriptInstance = new MainScript();
			}
			return _scriptInstance.onLoad(stashedData);
		} catch (e:Dynamic) {
			Log.error("Main: rt_load failed with exception: " + e);
			return RT_FAILED;
		}
	}

	@:expose("_rt_unload")
	@:exportc
	static function rt_unload():Dynamic {
		if (_scriptInstance != null) {
			return _scriptInstance.onUnload();
		}
		return null;
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
			if (_scriptInstance != null) {
				return _scriptInstance.onTick(dt);
			}
			return RT_SUCCESS;
		} catch (e:Dynamic) {
			Log.error("Main: rt_tick failed with exception: " + e);
			return RT_FAILED;
		}
	}

	@:expose("_rt_shutdown")
	@:exportc.exit
	@async static function rt_shutdown() {
		if (_scriptInstance != null) {
			cast @await _scriptInstance.onShutdown();
			_scriptInstance = null;
		}

		return;
	}

	public static function main() {
		if (_scriptInstance == null) {
			_scriptInstance = new MainScript();
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

		rc = rt_load(null);
		if (rc != RT_SUCCESS) {
			trace("Main: onLoad failed with error: " + rc);
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
