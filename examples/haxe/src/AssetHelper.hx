import rl.RL;
import rl.Log;
import Context.AppContext;
import Context.FontAsset;
import Context.ColorAsset;
import Context.ModelAsset;
import Context.SpriteAsset;
import Context.SoundAsset;
import Context.MusicAsset;

typedef EnsureAssetSyncCallback = String->Void;
typedef QueueAssetCallback = String->Any->Void;

class AssetHelper {
	public static var queuedAssetsRemaining:Int = 0;

	public static function ensureAssetSync(assetPath:String, ?successCallback:EnsureAssetSyncCallback, ?failCallback:EnsureAssetSyncCallback,
			?timeoutSec:Float):Void {
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

	public static function queueAsset(assetPath:String, ctx:Any, ?successCallback:QueueAssetCallback, ?failCallback:QueueAssetCallback):Void {
		Log.warn('queueing asset: ${assetPath}');

		queuedAssetsRemaining++;
		var callbackInvoked = false;
		var task = RL.loaderImportAssetAsync(assetPath);
		var rc = RL.loaderAddTask(task, assetPath, (assetPath:String, ctx:Any) -> {
			callbackInvoked = true;
			queuedAssetsRemaining--;
			if (successCallback != null) {
				successCallback(assetPath, ctx);
			} else {
				Log.info("Loaded asset: " + assetPath);
			}
		}, (assetPath:String, ctx:Any) -> {
			callbackInvoked = true;
			queuedAssetsRemaining--;
			if (queuedAssetsRemaining < 0) {
				Log.warn("Negative number of assets remaining to load!");
			}
			if (failCallback != null) {
				failCallback(assetPath, ctx);
			} else {
				Log.warn("Failed to load asset: " + assetPath);
			}
		}, ctx);
		if (rc != RL.LOADER_ADD_TASK_OK) {
			if (!callbackInvoked) {
				queuedAssetsRemaining--;
			}
			Log.warn('Failed to queue asset ${assetPath}: rc=${rc}');
		}
	}

	public static function awaitQueuedAssets(timeoutSec:Float = 5.0) {
		var timeout = timeoutSec + haxe.Timer.stamp();
		var assetsRemaining = queuedAssetsRemaining;
		while (assetsRemaining > 0 && (haxe.Timer.stamp() < timeout)) {
			Sys.sleep(0.001);
			// this needs to let rl_loader do any polling
			RL.loaderTick();
			// if an asset was processed, reset the timeout
			if (queuedAssetsRemaining < assetsRemaining) {
				assetsRemaining = queuedAssetsRemaining;
				timeout = timeoutSec + haxe.Timer.stamp();
			}
		}
	}

	public static function queueContextAssets(ctx:AppContext) {
		if ((ctx == null) || (ctx.assets == null))
			return;
		var assets = ctx.assets;

		if (assets.fonts != null) {
			for (v in assets.fonts) {
				queueFontAsset(v, ctx);
			}
		}

		if (assets.models != null) {
			for (v in assets.models) {
				queueModelAsset(v, ctx);
			}
		}

		if (assets.sprites != null) {
			for (v in assets.sprites) {
				queueSpriteAsset(v, ctx);
			}
		}

		if (assets.music != null) {
			for (v in assets.music) {
				queueMusicAsset(v, ctx);
			}
		}

		if (assets.sfx != null) {
			for (v in assets.sfx) {
				queueSoundAsset(v, ctx);
			}
		}

		if (assets.colors != null) {
			for (v in assets.colors) {
				createColorAsset(v);
			}
		}
	}

	static function shouldQueueAssetPath(path:String, loaded:Bool):Bool {
		return (path != null) && (path.length > 0) && (loaded != true);
	}

	static function shouldQueueModelAsset(v:ModelAsset):Bool {
		return (v != null) && (v.path.length > 0) && (v.loaded != true);
	}

	static function queueModelAsset(v:ModelAsset, ctx:AppContext):Void {
		if (!shouldQueueModelAsset(v)) {
			return;
		}
		queueAssetPath(v, ctx, (assetPath:String) -> RL.modelCreate(assetPath), "model");
	}

	static function queueSpriteAsset(v:SpriteAsset, ctx:AppContext):Void {
		if ((v == null) || !shouldQueueAssetPath(v.path, v.loaded)) {
			return;
		}
		queueAssetPath(v, ctx, (assetPath:String) -> RL.sprite3dCreate(assetPath), "sprite");
	}

	static function queueSoundAsset(v:SoundAsset, ctx:AppContext):Void {
		if ((v == null) || !shouldQueueAssetPath(v.path, v.loaded)) {
			return;
		}
		queueAssetPath(v, ctx, (assetPath:String) -> RL.soundCreate(assetPath), "sfx");
	}

	static function queueMusicAsset(v:MusicAsset, ctx:AppContext):Void {
		if ((v == null) || !shouldQueueAssetPath(v.path, v.loaded)) {
			return;
		}
		queueAssetPath(v, ctx, (assetPath:String) -> RL.musicCreate(assetPath), "music");
	}

	static function queueAssetPath(v:{?id:RLHandle, path:String, ?loaded:Bool}, ctx:AppContext, createHandle:String->RLHandle, kind:String):Void {
		if (!shouldQueueAssetPath(v.path, v.loaded)) {
			return;
		}

		var asset = v;
		var assetPath = asset.path;
		Log.warn('encountered ${kind} asset: ${assetPath}');
		queueAsset(assetPath, ctx, (loadedPath, _ctx) -> {
			asset.id = createHandle(loadedPath);
			asset.loaded = asset.id != null;
			Log.info('created ${kind}: ${loadedPath}');
		}, (failedPath, _ctx) -> {
			asset.loaded = false;
			Log.warn('Failed to load ${kind} asset: ${failedPath}');
		});
	}

	static function queueFontAsset(v:FontAsset, ctx:AppContext):Void {
		if ((v == null) || (v.path.length == 0) || (v.loaded == true)) {
			return;
		}

		var asset = v;
		Log.warn('encountered font asset: ${asset.path}');
		queueAsset(asset.path, ctx, (loadedPath, _ctx) -> {
			asset.id = RL.fontCreate(loadedPath, asset.size);
			asset.loaded = asset.id != null;
			Log.info('created font: ${loadedPath}');
		}, (failedPath, _ctx) -> {
			asset.loaded = false;
			Log.warn('Failed to load font asset: ${failedPath}');
		});
	}

	static function createColorAsset(v:ColorAsset):Void {
		if ((v == null) || (v.loaded == true)) {
			return;
		}

		v.id = RL.colorCreate(v.r, v.g, v.b, v.a);
		v.loaded = v.id != null;
		if (v.loaded == true) {
			Log.info('created color asset: rgba(${v.r}, ${v.g}, ${v.b}, ${v.a})');
		}
	}
}
