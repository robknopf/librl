package ws;

import haxe.io.Bytes;

#if cpp

/** Injects wgutils include + wasm `-lwebsocket.js`; requires `-D WGUTILS_ROOT` (path to wgutils tree; headers under `src/`). */
@:keep
@:buildXml('
  <files id="haxe">
    <error value="WebSocket: missing WGUTILS_ROOT (-D WGUTILS_ROOT=/path/to/wgutils)" unless="WGUTILS_ROOT" />
    <compilerflag value="-I${WGUTILS_ROOT}/src" />
  </files>
  <linker id="exe" exe="emcc" if="emscripten">
    <flag value="-lwebsocket.js" />
  </linker>
')
@:noCompletion
class WebSocketBuildInject {}

/**
 * Project-local binding over wgutils `websocket.h` (wgutils sources linked with the runtime binary).
 *
 * Call {@link #poll} every frame while the socket is alive.
 */
typedef WebSocketHandlers = {
	?onOpen: WebSocket->Void,
	?onClose: WebSocket->Int->String->Void,
	?onError: WebSocket->Void,
	?onMessage: WebSocket->Bytes->Bool->Void,
};

/** Maps {@link WebSocket#clientId} (stored in native user_data) → socket + callbacks for C springs. */
typedef WebSocketClientEntry = {
	var client: WebSocket;
	var handlers: WebSocketHandlers;
};

@:headerInclude("string.h")
@:headerInclude("websocket/websocket.h")
@:headerInclude("stdint.h")
@:headerInclude("ws/WebSocketBridge.h")
/** CPPIA generates Dynamic-arg wrappers for cpp.ConstCharStar; these are C-only entry points. */
@:unreflective
@:noCompletion
class WebSocketNative {
	@:functionCode('
		websocket_callbacks_t cb = {};
		cb.on_open = (void (*)(websocket_t *, void *)) &::ws::WebSocketBridge_obj::springOpen;
		cb.on_close = (void (*)(websocket_t *, int, const char *, void *)) &::ws::WebSocketBridge_obj::springClose;
		cb.on_error = (void (*)(websocket_t *, void *)) &::ws::WebSocketBridge_obj::springError;
		cb.on_message = (void (*)(websocket_t *, const char *, int, bool, void *)) &::ws::WebSocketBridge_obj::springMessage;
		return (void *)::websocket_create(url.utf8_str(), &cb, (void *)(intptr_t)clientId);
	')
	public static function create(url: String, clientId: Int): cpp.RawPointer<cpp.Void> {
		return null;
	}

	@:functionCode('::websocket_poll((::websocket_t *)ptr);')
	public static function poll(ptr: cpp.RawPointer<cpp.Void>): Void {}

	@:functionCode('::websocket_destroy((::websocket_t *)ptr);')
	public static function destroy(ptr: cpp.RawPointer<cpp.Void>): Void {}

	@:functionCode('return ::websocket_send_text((::websocket_t *)ptr, text.utf8_str());')
	public static function sendText(ptr: cpp.RawPointer<cpp.Void>, text: String): Int {
		return -1;
	}

	@:functionCode('return ::websocket_send_binary((::websocket_t *)ptr, bytes->b->GetBase(), (size_t)bytes->length);')
	public static function sendBinary(ptr: cpp.RawPointer<cpp.Void>, bytes: Bytes): Int {
		return -1;
	}

	@:functionCode('::websocket_close((::websocket_t *)ptr, code, reason != null() && reason.length != 0 ? reason.utf8_str() : (const char *)0);')
	public static function close(ptr: cpp.RawPointer<cpp.Void>, code: Int, reason: String): Void {}

	@:functionCode('return ::websocket_is_connected((::websocket_t *)ptr);')
	public static function isConnected(ptr: cpp.RawPointer<cpp.Void>): Bool {
		return false;
	}

	@:functionCode('return ::websocket_get_url((::websocket_t *)ptr);')
	public static function getUrlNative(ptr: cpp.RawPointer<cpp.Void>): String {
		return null;
	}
}

@:keep
/** Avoid CPPIA glue for springClose/springMessage (ConstCharStar becomes Dynamic and breaks native compile). */
@:unreflective
@:noCompletion
class WebSocketBridge {
	public static var clientEntries: Map<Int, WebSocketClientEntry> = new Map();
	static var nextClientId: Int = 1;

	public static function register(client: WebSocket, handlers: WebSocketHandlers): Int {
		var id = nextClientId++;
		clientEntries.set(id, {client: client, handlers: handlers});
		return id;
	}

	public static function unregister(id: Int): Void {
		clientEntries.remove(id);
	}

	@:keep public static function springOpen(ws: cpp.RawPointer<cpp.Void>, user: cpp.RawPointer<cpp.Void>): Void {
		var id: Int = untyped __cpp__('(int)(intptr_t){0}', user);
		var entry = clientEntries.get(id);
		if (entry != null && entry.handlers.onOpen != null)
			entry.handlers.onOpen(entry.client);
	}

	@:keep public static function springClose(ws: cpp.RawPointer<cpp.Void>, code: Int, reason: cpp.ConstCharStar,
			user: cpp.RawPointer<cpp.Void>): Void {
		var id: Int = untyped __cpp__('(int)(intptr_t){0}', user);
		var entry = clientEntries.get(id);
		if (entry == null || entry.handlers.onClose == null)
			return;
		var r: String = untyped __cpp__('(reason == nullptr) ? ::String() : ::String((const char *)reason)');
		entry.handlers.onClose(entry.client, code, r);
	}

	@:keep public static function springError(ws: cpp.RawPointer<cpp.Void>, user: cpp.RawPointer<cpp.Void>): Void {
		var id: Int = untyped __cpp__('(int)(intptr_t){0}', user);
		var entry = clientEntries.get(id);
		if (entry != null && entry.handlers.onError != null)
			entry.handlers.onError(entry.client);
	}

	@:keep public static function springMessage(ws: cpp.RawPointer<cpp.Void>, data: cpp.ConstCharStar, len: Int, isText: Bool,
			user: cpp.RawPointer<cpp.Void>): Void {
		var id: Int = untyped __cpp__('(int)(intptr_t){0}', user);
		var entry = clientEntries.get(id);
		if (entry == null || entry.handlers.onMessage == null)
			return;
		var payload = bytesFromNative(data, len);
		entry.handlers.onMessage(entry.client, payload, isText);
	}

	@:functionCode('
		if (len <= 0 || data == nullptr) {
			Array<unsigned char> emptyArr = Array_obj<unsigned char>::__new(0, 0);
			return ::haxe::io::Bytes_obj::__alloc(HX_CTX_GET, 0, emptyArr);
		}
		Array<unsigned char> arr = Array_obj<unsigned char>::__new(len, len);
		memcpy(arr->GetBase(), (const char *)data, (size_t)len);
		return ::haxe::io::Bytes_obj::__alloc(HX_CTX_GET, arr->length, arr);
	')
	static function bytesFromNative(data: cpp.ConstCharStar, len: Int): Bytes {
		return null;
	}
}

class WebSocket {
	public var nativePtr(default, null): cpp.RawPointer<cpp.Void>;
	/** Key in {@link WebSocketBridge#clientEntries}, passed as native user_data for callback routing. */
	public var clientId(default, null): Int;

	public function new(url: String, handlers: WebSocketHandlers) {
		clientId = WebSocketBridge.register(this, handlers);
		nativePtr = WebSocketNative.create(url, clientId);
		if (nativePtr == untyped __cpp__("nullptr")) {
			trace("[WebSocket] websocket_create failed (emscripten_websocket_new). url=" + url);
		}
	}

	public inline function poll(): Void {
		if (nativePtr != untyped __cpp__("nullptr"))
			WebSocketNative.poll(nativePtr);
	}

	public inline function sendText(text: String): Int {
		if (nativePtr == untyped __cpp__("nullptr"))
			return -1;
		return WebSocketNative.sendText(nativePtr, text);
	}

	public inline function sendBinary(bytes: Bytes): Int {
		if (nativePtr == untyped __cpp__("nullptr"))
			return -1;
		return WebSocketNative.sendBinary(nativePtr, bytes);
	}

	public inline function close(?code: Int = 1000, ?reason: String): Void {
		if (nativePtr == untyped __cpp__("nullptr"))
			return;
		WebSocketNative.close(nativePtr, code, reason != null ? reason : "");
	}

	public inline function isConnected(): Bool {
		if (nativePtr == untyped __cpp__("nullptr"))
			return false;
		return WebSocketNative.isConnected(nativePtr);
	}

	public function url(): String {
		if (nativePtr == untyped __cpp__("nullptr"))
			return "";
		return WebSocketNative.getUrlNative(nativePtr);
	}

	public function destroy(): Void {
		if (nativePtr != untyped __cpp__("nullptr")) {
			WebSocketNative.destroy(nativePtr);
			nativePtr = cast untyped __cpp__("nullptr");
		}
		WebSocketBridge.unregister(clientId);
	}
}

#else

typedef WebSocketHandlers = {
	?onOpen: WebSocket->Void,
	?onClose: WebSocket->Int->String->Void,
	?onError: WebSocket->Void,
	?onMessage: WebSocket->Bytes->Bool->Void,
};

class WebSocket {
	public function new(_url: String, _handlers: WebSocketHandlers) {
		throw "WebSocket is only supported on cpp/hxcpp";
	}

	public function poll(): Void {}

	public function sendText(_text: String): Int {
		return -1;
	}

	public function sendBinary(_bytes: Bytes): Int {
		return -1;
	}

	public function close(?code: Int, ?reason: String): Void {}

	public function isConnected(): Bool {
		return false;
	}

	public function url(): String {
		return "";
	}

	public function destroy(): Void {}
}

#end
