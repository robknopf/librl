import Types.RTResult;

typedef InitCallback = () -> RTResult;
typedef TickCallback = (dt:Float) -> RTResult;
typedef ShutdownCallback = () -> Void;
typedef LoadCallback = (data:Dynamic) -> RTResult;
typedef UnloadCallback = () -> Dynamic;

class Script {
    public function new() {}
    public function onInit():RTResult { return RTResult.RT_SUCCESS; }
    public function onTick(dt:Float):RTResult { return RTResult.RT_SUCCESS; }
    public function onShutdown():Void {}
    public function onLoad(data:Dynamic):RTResult { return RTResult.RT_SUCCESS; }
    public function onUnload():Dynamic { return null; }
}


/*
interface Script {
    public function onInit():RTResult;
    public function onTick(dt:Float):RTResult;
    public function onShutdown():Void;
    public function onLoad(data:Dynamic):RTResult;
    public function onUnload():Dynamic;
}
*/


