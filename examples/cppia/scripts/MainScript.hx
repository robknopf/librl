package scripts;

// import rl;
// import rl.Debug;
// import rl.RL;
import rl.Types.RLVec2;
import rl.*;
import rl.helpers.Log;
import rl.Types.RLHandle;
import rl.Types.RLScenePickResult;
import Types.RTResult;
import Script;
import haxe.io.Path;
import utils.StringUtil.formatFixed;
import scripts.test.TestImport;

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
	var scene:RLHandle;
	var reloadCount:Int;
	var spriteYOffset:Float;
	var backgroundColor:RLHandle;
}

@:keep
class MainScript extends Script {
	final IDEAL_SCREEN_WIDTH:Int = 1024;
	final IDEAL_SCREEN_HEIGHT:Int = 1280;
	final SCREEN_TITLE:String = "cppia-simple (Haxe runtime)";
	final SCREEN_FLAGS:Int = Window.FLAG_MSAA_4X_HINT;

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
	final BGM_1_PATH:String = "assets/music/ethernight_club.mp3";
	final BGM_2_PATH:String = "assets/music/dancing_on_the_edge.mp3";

	static var ctx:AppContext = null;

	var screenWidth:Int = 1024;
	var screenHeight:Int = 768;

	var platformText:String = "Platform: <unknown>";

	public static function joinPath(pathComponents:haxe.Rest<String>):String {
		return Path.normalize(Path.join(pathComponents.toArray()));
	}

	@async
	override public function onInit():RTResult {
		trace("Main: onInit");

		trace("creating context");
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
			scene: 0,
			reloadCount: 0,
			spriteYOffset: 3.0,
			backgroundColor: 0
		};
		trace("context created");
		trace("setting logger level to WARN");
		Logger.setLevel(Logger.LEVEL_WARN);
		trace("logger level set to WARN");

		trace("calling RL.init");
		var err = @await RL.init({
			windowWidth: IDEAL_SCREEN_WIDTH,
			windowHeight: IDEAL_SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
			assetHost: ASSET_HOST,
			// fsRootDir: LOADER_CACHE_DIR
		});
		trace("RL.init returned: " + err);
		if (err != RL.INIT_OK) {
			trace("Main: onInit failed with error: " + err);
			return RT_FAILED;
		}
		Logger.setLevel(Logger.LEVEL_INFO);

		Debug.enableFps(10, 10, DEBUG_FONT_SIZE, ctx.greyAlphaColor);

		Fs.clear();

		Window.setMonitor(1);
		resizeWindow();

		setupScene();

		// draw a blank frame while assets load
		Render.begin();
		Render.clearBackground(ctx.backgroundColor);
		Render.end();

		return RT_SUCCESS;
	}

	private function resizeWindow() {
		var currentMonitor = Window.getCurrentMonitor();
		var monitorWidth = Window.getMonitorWidth(currentMonitor);
		var monitorHeight = Window.getMonitorHeight(currentMonitor);
		var screenScalar = 0.95;
		screenWidth = Std.int(Math.min(Window.getMonitorWidth(currentMonitor) * screenScalar, IDEAL_SCREEN_WIDTH));
		screenHeight = Std.int(Math.min(Window.getMonitorHeight(currentMonitor) * screenScalar, IDEAL_SCREEN_HEIGHT));
		Window.setSize(screenWidth, screenHeight);
	}

	private function setupScene():Void {
		Render.enableLighting();
		Render.setLightDirection(-0.6, -1.0, -0.5);
		Render.setLightAmbient(0.25);
		ctx.camera = Camera3d.create(12.0, 12.0, 12.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 45.0, Camera3d.PERSPECTIVE);
		Camera3d.setActive(ctx.camera);

		ctx.scene = Scene.create();

		// if (ctx.scene != 0) {
		Scene.setActiveCamera(ctx.scene, ctx.camera);
		// }
		ctx.greyAlphaColor = Color.create(0, 0, 0, 128);
		ctx.backgroundColor = Color.create(245, 245, 245, 255);
	}

	private function teardownScene():Void {
		Render.disableLighting();
		// if (ctx.scene != 0) {
		Scene.destroy(ctx.scene);
		ctx.scene = 0;
		// }
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
		Scene.add(ctx.scene, ctx.model);
		Model.setTransform(ctx.model, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		Model.setTint(ctx.model, Color.WHITE);
		Model.setAnimation(ctx.model, 1);
		Model.setAnimationSpeed(ctx.model, 1.0);
		Model.setAnimationLoop(ctx.model, true);
		Asset.addTask(Asset.ensureAsync(MODEL_PATH), (path, _) -> {
			var modelAsset = Model.loadAsset(MODEL_PATH);
			Model.setAsset(ctx.model, modelAsset);
			// if (ctx.scene != 0 && ctx.model != 0) {
			//	Scene.add(ctx.scene, ctx.model, 0);
			// }
		}, null, ctx);

		ctx.sprite = Sprite3d.create(0);
		Scene.add(ctx.scene, ctx.sprite);
		Sprite3d.setTransform(ctx.sprite, 0.0, 0.0, ctx.spriteYOffset, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		Sprite3d.setTint(ctx.sprite, Color.WHITE);
		Asset.addTask(Asset.ensureAsync(SPRITE_PATH), (path, _) -> {
			var textureAsset = Texture.create(path);
			Sprite3d.setTexture(ctx.sprite, textureAsset);
			// if (ctx.scene != 0 && ctx.sprite != 0) {
			//	Scene.add(ctx.scene, ctx.sprite, 0);
			// }
		}, null, ctx);

		ctx.labelText2d = Text2d.create(0, KOMIKA_FONT_SIZE);
		Scene.add(ctx.scene, ctx.labelText2d);
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

		if (ctx.bgm == 0) {
			Asset.addTask(Asset.ensureAsync(BGM_2_PATH), (path, _) -> {
				ctx.bgm = Music.create(path);
				Music.setLoop(ctx.bgm, true);
				Music.play(ctx.bgm);
			}, null, ctx);
		}
	}

	private function unloadAssets():Void {
		// if (ctx.model != 0) {
		Model.destroy(ctx.model);
		ctx.model = 0;
		// }
		// if (ctx.sprite != 0) {
		Sprite3d.destroy(ctx.sprite);
		ctx.sprite = 0;
		// }
		Text2d.destroy(ctx.labelText2d);
		ctx.labelText2d = 0;
		// if (ctx.bgm != 0) {
		//Music.destroy(ctx.bgm);
		//ctx.bgm = 0;
		// }
		// if (ctx.debugFont != 0) {
		Font.destroy(ctx.debugFont);
		ctx.debugFont = 0;
		// }
		Font.destroy(ctx.komikaFont);
		ctx.komikaFont = 0;

		//Music.destroy(ctx.bgm);
		//ctx.bgm = 0;
	}

	public function animateFrame(deltaTimeSec:Float):Void {
		// if (ctx.model != 0) {
		Model.animate(ctx.model, deltaTimeSec);
		// }

		var spriteX = 0.0;
		var spriteY = 0.0;
		var spriteZ = 0.0;

		// bob the sprite up and down
		var bobSpeed = 1.0;
		var bobHeight = 1.5;
		bobHeight = bobHeight * 2;
		// if (ctx.sprite != 0) {
		var y = Math.sin(ctx.elapsed * bobSpeed) * bobHeight;
		spriteY = y + ctx.spriteYOffset;
		// }

		// move the sprite in a circle
		/*
			var rotationSpeed = 1.0;
			var rotationRadius = 2.0;
			if (ctx.sprite != 0) {
				spriteX = Math.cos(ctx.elapsed * rotationSpeed) * rotationRadius;
				spriteZ = Math.sin(ctx.elapsed * rotationSpeed) * rotationRadius;
			}
		 */

		// if (ctx.sprite != 0) {
		Sprite3d.setTransform(ctx.sprite, spriteX, spriteY, spriteZ, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
		// }
	}

	// only calculate the message size when it changes
	final msgDefault = "Hello from Cppia";
	var msg = "";
	var msgTextSize:RLVec2;
	var msgTextX:Int;
	var msgTextY:Int;

	private function setMessage(message:String) {
		if (msg == message)
			return; // early out, it's the same
		msg = message;
		msgTextSize = Text.measureEx(ctx.komikaFont, msg, KOMIKA_FONT_SIZE, 1.0);
		msgTextX = Std.int((screenWidth - msgTextSize.x) / 2);
		msgTextY = Std.int(screenHeight - (msgTextSize.y + (msgTextSize.y / 2)));
	}

	override public function onTick(deltaTimeSec:Float):RTResult {
		// trace("Main: onTick called with deltaTimeMS: " + deltaTimeMS);
		ctx.elapsed = ctx.elapsed + deltaTimeSec;
		ctx.totalTime += deltaTimeSec;
		ctx.countdownTimer -= deltaTimeSec;
		if (ctx.countdownTimer <= 0) {
			// return RT_STOPPED;
		}

		TestImport.test();

		animateFrame(deltaTimeSec);

		Music.updateAll();

		var mouse = Input.getMouseState();
		var mouseText = 'Mouse: (${mouse.x}, ${mouse.y}) w:${mouse.wheel} b:[${mouse.left}, ${mouse.right}, ${mouse.middle}]';
		var remainingText = 'Remaining: ${formatFixed(ctx.countdownTimer, 2)}';
		var elapsedText = 'Elapsed: ${formatFixed(ctx.totalTime, 2)}';

		// if (ctx.scene != 0) {
		var scenePick:RLScenePickResult = Scene.pick(ctx.scene, 0, mouse.x, mouse.y);
		if (scenePick.hit) {
			// trace('Scene pick: handle=${scenePick.handle} y=${scenePick.point.y}');
			if (scenePick.handle == ctx.model)
				setMessage('Model pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + scenePick.point.y);
			else if (scenePick.handle == ctx.sprite)
				setMessage('Sprite pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + scenePick.point.y);
			else
				setMessage('<Unknown> pick: Mouse position (mouse.x:${mouse.x}, mouse.y:${mouse.y}) pick result y: ' + scenePick.point.y);
		} else {
			// nothing was picked, reset the message
			if (msg != msgDefault)
				setMessage(msgDefault);
		}
		// }

		Render.begin();
		Render.clearBackground(ctx.backgroundColor);

		// if (ctx.scene != 0) {
		Scene.draw(ctx.scene);
		// }

		// 2D UI overlay
		Text.drawEx(ctx.komikaFont, msg, msgTextX, msgTextY, KOMIKA_FONT_SIZE, 1.0, Color.BLUE);
		Text.drawEx(ctx.debugFont, remainingText, 10, 36, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, elapsedText, 10, 56, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, mouseText, 10, 76, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, 'Reloads: ${ctx.reloadCount}', 10, 96, DEBUG_FONT_SIZE, 1.0, Color.BLACK);
		Text.drawEx(ctx.debugFont, platformText, 10, 116, DEBUG_FONT_SIZE, 1.0, Color.BLACK);

		// Text.drawFpsEx(ctx.debugFont, 10, 10, DEBUG_FONT_SIZE, ctx.greyAlphaColor);

		// Text2d.draw(ctx.labelText2d);

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

		Logger.setLevel(Logger.LEVEL_TRACE);
		resizeWindow();
		setMessage(msgDefault);

		//	setupScene();
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

	override public function onShutdown():Void {
		trace("Main: onShutdown");
		teardownScene();
		RL.deinit();
	}
}
