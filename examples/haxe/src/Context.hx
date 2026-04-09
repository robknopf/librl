import rl.RL;

typedef AssetState = {
	var ?id:RLHandle;
	var ?loaded:Bool;
}

typedef ModelAsset = {
	> AssetState,
	var path:String;
}

typedef FontAsset = {
	> AssetState,
	var path:String;
	var size:Int;
}

typedef SpriteAsset = {
	> AssetState,
	var path:String;
}

typedef SoundAsset = {
	> AssetState,
	var path:String;
}

typedef MusicAsset = {
	> AssetState,
	var path:String;
}

typedef ColorAsset = {
	> AssetState,
	var r:Int;
	var g:Int;
	var b:Int;
	var a:Int;
}

typedef Assets = {
	var ?fonts:Map<String, FontAsset>;
	var ?models:Map<String, ModelAsset>;
	var ?sprites:Map<String, SpriteAsset>;
	var ?sfx:Map<String, SoundAsset>;
	var ?colors:Map<String, ColorAsset>;
	var ?music:Map<String, MusicAsset>;
}

typedef AppContext = {
	var ?assets:Assets;
	var ?camera:RLHandle;

}

class Context {
	public static function create():AppContext {
		var ctx:AppContext = {
			assets: {
				fonts: new Map<String, FontAsset>(),
				models: new Map<String, ModelAsset>(),
				sprites: new Map<String, SpriteAsset>(),
				sfx: new Map<String, SoundAsset>(),
				colors: new Map<String, ColorAsset>(),
				music: new Map<String, MusicAsset>(),
			}
		}
		return ctx;
	}

	public static function destroy(ctx:AppContext) {
		if (ctx == null) {
			return;
		}
		if (ctx.camera != null) {
			RL.camera3dDestroy(ctx.camera);
			ctx.camera = null;
		}
		if (ctx.assets == null)
			return;
		var assets = ctx.assets;
		if (assets.fonts != null) {
			for (v in assets.fonts) {
				destroyLoadedAsset(v, RL.fontDestroy);
			}
		}
		if (assets.models != null) {
			for (v in assets.models) {
				destroyLoadedAsset(v, RL.modelDestroy);
			}
		}
		if (assets.sprites != null) {
			for (v in assets.sprites) {
				destroyLoadedAsset(v, RL.sprite3dDestroy);
			}
		}
		if (assets.sfx != null) {
			for (v in assets.sfx) {
				destroyLoadedAsset(v, RL.soundDestroy);
			}
		}
		if (assets.colors != null) {
			for (v in assets.colors) {
				destroyLoadedAsset(v, RL.colorDestroy);
			}
		}
		if (assets.music != null) {
			for (v in assets.music) {
				destroyLoadedAsset(v, RL.musicDestroy);
			}
		}
	}

	static function destroyLoadedAsset(v:AssetState, destroy:RLHandle->Void):Void {
		if ((v == null) || (v.loaded != true) || (v.id == null)) {
			return;
		}
		destroy(v.id);
		v.loaded = false;
		v.id = null;
	}
}
