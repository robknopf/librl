package;

#if ENABLE_SCRIPT_WATCHER
import ws.WebSocket;
#end

typedef WatchEntry = {
	dir: String,
	ext: String,
	?recursive: Bool,
}

typedef FileChangedCallback = (assetPath: String) -> Void;

interface IScriptWatcherClient {
	function connect(url:String, ?watchEntries:Array<WatchEntry>):Void;
	function disconnect():Void;
	function tick():Void;
	var onFileChanged:Null<FileChangedCallback>;
}

#if ENABLE_SCRIPT_WATCHER
class ScriptWatcherClient implements IScriptWatcherClient {
	static inline final DEFAULT_SCRIPT_WATCHER_URL:String = "wss://192.168.1.100:9001/ws";

	var scriptWatcherSocket:Null<WebSocket> = null;
	public var onFileChanged:Null<FileChangedCallback> = null;

	public function new() {}

	public function tick():Void {
		if (scriptWatcherSocket != null) {
			scriptWatcherSocket.poll();
		}
	}

	function handleScriptWatcherMessage(payload:haxe.io.Bytes, isText:Bool):Void {
		if (!isText)
			return;
		try {
			var s = payload.toString();
			var obj:Dynamic = haxe.Json.parse(s);
			if (Reflect.field(obj, "type") != "file_changed")
				return;
			var data = Reflect.field(obj, "data");
			if (data == null)
				return;
			var pathStr = Reflect.field(data, "path");
			if (pathStr == null)
				return;
			var assetPath = Std.string(pathStr);
			trace('[script watcher client] file_changed: $assetPath');
			if (onFileChanged != null) {
				onFileChanged(assetPath);
			}
		} catch (e:Dynamic) {
			trace('[script watcher client] message ignored: $e');
		}
	}

	public function connect(url:String, ?watchEntries:Array<WatchEntry>):Void {
		var entries = watchEntries;
		if (entries == null || entries.length == 0) {
			entries = [{dir: "assets/scripts/cppia", ext: ".cppia", recursive: true}];
		}
		if (url.length == 0) {
			trace("[script watcher client] disabled (empty URL)");
			return;
		}
		disconnect();
		trace('[script watcher client] connecting to $url');
		scriptWatcherSocket = new WebSocket(url, {
			onOpen: function(ws) {
				trace("[script watcher client] connected");
				var watchMsg = haxe.Json.stringify({
					type: "watch",
					data: {watch: entries}
				});
				ws.sendText(watchMsg);
			},
			onClose: function(_, code, reason) {
				trace('[script watcher client] closed code=$code reason=$reason');
				disconnect();
			},
			onError: function(_) {
				trace("[script watcher client] WebSocket error (TLS/host/port — check DevTools→Network→WS)");
				disconnect();
			},
			onMessage: function(_, payload, isText) {
				handleScriptWatcherMessage(payload, isText);
			},
		});
	}

	public function disconnect():Void {
		if (scriptWatcherSocket != null) {
			scriptWatcherSocket.destroy();
			scriptWatcherSocket = null;
		}
	}
}
#else
class ScriptWatcherClient implements IScriptWatcherClient {
	public function new() {}
	public var onFileChanged:Null<FileChangedCallback> = null;
	public function connect(url:String, ?watchEntries:Array<WatchEntry>):Void {}
	public function disconnect():Void {}
	public function tick():Void {}
}
#end
