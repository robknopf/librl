package rl;

abstract RLHandle(Int) from Int to Int {
	public static inline function invalid():RLHandle {
		return 0;
	}

	public inline function isValid():Bool {
		return this != 0;
	}
}

#if js
typedef RLAsyncVoid = js.lib.Promise<Null<Dynamic>>;
#else
typedef RLAsyncVoid = Void;
#end

typedef RLSprite3dTransform = {
	var positionX:Float;
	var positionY:Float;
	var positionZ:Float;
	var rotationX:Float;
	var rotationY:Float;
	var rotationZ:Float;
	var scaleX:Float;
	var scaleY:Float;
	var scaleZ:Float;
}

enum abstract RLFacing(Int) from Int to Int {
	var CAMERA = 0;
	var CAMERA_FIXED_Y = 1;
	var Y_UP = 2;
	var FREE = 3;
}

typedef RLInitConfig = {
	?windowWidth:Int,
	?windowHeight:Int,
	?windowTitle:String,
	?windowFlags:Int,
	?assetHost:String,
	?fsRootDir:String,
};

typedef RLBootConfig = {
	?bindingsPath:String,
	?canvasId:String,
	?modulePath:String,
	?wasmPath:String,
	?idealWidth:Int,
	?idealHeight:Int,
	?print:String->Void,
	?printErr:String->Void,
	?locateFile:String->String->String,
};

typedef RLVec2 = {
	var x:Float;
	var y:Float;
}

typedef RLVec3 = {
	var x:Float;
	var y:Float;
	var z:Float;
}

typedef RLPickResult = {
	var hit:Bool;
	var handle:RLHandle;
	var distance:Float;
	var point:RLVec3;
	var normal:RLVec3;
}

typedef RLScenePickResult = RLPickResult;

typedef RLMouseState = {
	var x:Int;
	var y:Int;
	var wheel:Int;
	var left:Int;
	var right:Int;
	var middle:Int;
	var dx:Int;
	var dy:Int;
}

typedef RLGamepad = {
	var id:Int;
	var axis:Array<Float>;
	var buttons:Array<Int>;
}

typedef RLTouchpoint = {
	var id:Int;
	var x:Float;
	var y:Float;
}

class RLKeyboardState {
	public var max_num_keys:Int = 0;
	public var keys:Array<Int> = [];
	public var pressed_key:Int = 0;
	public var pressed_char:Int = 0;
	public var num_pressed_keys:Int = 0;
	public var pressed_keys:Array<Int> = [];
	public var num_pressed_chars:Int = 0;
	public var pressed_chars:Array<Int> = [];

	public function new() {}
}
