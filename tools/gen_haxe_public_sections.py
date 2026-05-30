#!/usr/bin/env python3
"""Generate rl/*.hx section façade classes from RLImpl method names."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "bindings/haxe/rl"

# (class_name, [(public_method, impl_method, extra_lines_before_method)])
# extra_lines: e.g. '@async' or '@async\n\tpublic static function...'
SECTIONS: dict[str, list[tuple[str, str, str]]] = {
    "Fs": [
        ("init", "fsInit", "@async"),
        ("initAsync", "fsInitAsync", ""),
        ("deinit", "fsDeinit", "@async"),
        ("deinitAsync", "fsDeinitAsync", ""),
        ("isInitialized", "fsIsInitialized", ""),
        ("isReady", "fsIsReady", ""),
        ("flush", "fsFlush", ""),
        ("getRootDir", "fsGetRootDir", ""),
        ("normalizePath", "fsNormalizePath", ""),
        ("restoreAsync", "fsRestoreAsync", ""),
        ("read", "fsRead", ""),
        ("write", "fsWrite", ""),
        ("exists", "fsExists", ""),
        ("remove", "fsRemove", ""),
        ("clear", "fsClear", ""),
        ("mkdir", "fsMkdir", ""),
        ("rmdir", "fsRmdir", ""),
    ],
    "Asset": [
        ("setHost", "assetSetHost", ""),
        ("getHost", "assetGetHost", ""),
        ("pingHost", "assetPingHost", ""),
        ("ensureAsync", "assetEnsureAsync", ""),
        ("ensure", "assetEnsure", "@async"),
        ("ensureGroupAsync", "assetEnsureGroupAsync", ""),
        ("pollTask", "assetPollTask", ""),
        ("finishTask", "assetFinishTask", ""),
        ("getTaskPath", "assetGetTaskPath", ""),
        ("freeTask", "assetFreeTask", ""),
        ("addTask", "assetAddTask", ""),
        ("tick", "assetTick", ""),
        ("taskInvalid", "assetTaskInvalid", ""),
        ("taskIsValid", "assetTaskIsValid", ""),
    ],
    "Window": [
        ("closeRequested", "windowCloseRequested", ""),
        ("getScreenSize", "windowGetScreenSize", ""),
        ("getMonitorCount", "windowGetMonitorCount", ""),
        ("setTitle", "windowSetTitle", ""),
        ("setSize", "windowSetSize", ""),
        ("getCurrentMonitor", "windowGetCurrentMonitor", ""),
        ("setMonitor", "windowSetMonitor", ""),
        ("getMonitorWidth", "windowGetMonitorWidth", ""),
        ("getMonitorHeight", "windowGetMonitorHeight", ""),
        ("getMonitorPosition", "windowGetMonitorPosition", ""),
        ("getPosition", "windowGetPosition", ""),
        ("setPosition", "windowSetPosition", ""),
    ],
    "Render": [
        ("enableLighting", "enableLighting", ""),
        ("disableLighting", "disableLighting", ""),
        ("isLightingEnabled", "isLightingEnabled", ""),
        ("setLightDirection", "setLightDirection", ""),
        ("setLightAmbient", "setLightAmbient", ""),
        ("begin", "renderBegin", ""),
        ("end", "renderEnd", ""),
        ("clearBackground", "renderClearBackground", ""),
        ("beginMode2D", "renderBeginMode2D", ""),
        ("endMode2D", "renderEndMode2D", ""),
        ("beginMode3d", "renderBeginMode3d", ""),
        ("endMode3d", "renderEndMode3d", ""),
    ],
    "Input": [
        ("pollEvents", "inputPollEvents", ""),
        ("getMousePosition", "inputGetMousePosition", ""),
        ("getMouseWheel", "inputGetMouseWheel", ""),
        ("getMouseButton", "inputGetMouseButton", ""),
        ("getMouseState", "inputGetMouseState", ""),
        ("getKeyboardState", "inputGetKeyboardState", ""),
        ("getGamepads", "inputGetGamepads", ""),
        ("getGamepad", "inputGetGamepad", ""),
        ("getTouchpoints", "inputGetTouchpoints", ""),
        ("getTouchpoint", "inputGetTouchpoint", ""),
    ],
    "Camera3d": [
        ("create", "camera3dCreate", ""),
        ("set", "camera3dSet", ""),
        ("setActive", "camera3dSetActive", ""),
        ("destroy", "camera3dDestroy", ""),
        ("getDefault", "camera3dGetDefault", ""),
        ("getActive", "camera3dGetActive", ""),
    ],
    "Font": [
        ("create", "fontCreate", ""),
        ("destroy", "fontDestroy", ""),
        ("getDefault", "fontGetDefault", ""),
    ],
    "Text": [
        ("draw", "textDraw", ""),
        ("measure", "textMeasure", ""),
        ("drawFps", "textDrawFps", ""),
        ("drawEx", "textDrawEx", ""),
        ("measureEx", "textMeasureEx", ""),
        ("drawFpsEx", "textDrawFpsEx", ""),
    ],
    "Texture": [
        ("create", "textureCreate", ""),
        ("destroy", "textureDestroy", ""),
        ("getDefault", "textureGetDefault", ""),
        ("drawEx", "textureDrawEx", ""),
        ("drawGround", "textureDrawGround", ""),
    ],
    "Model": [
        ("loadAsset", "modelLoadAsset", ""),
        ("destroyAsset", "modelDestroyAsset", ""),
        ("getDefaultAsset", "modelGetDefaultAsset", ""),
        ("create", "modelCreate", ""),
        ("createFromFile", "modelCreateFromFile", ""),
        ("setAsset", "modelSetAsset", ""),
        ("setTransform", "modelSetTransform", ""),
        ("draw", "modelDraw", ""),
        ("setAnimation", "modelSetAnimation", ""),
        ("setAnimationSpeed", "modelSetAnimationSpeed", ""),
        ("setAnimationLoop", "modelSetAnimationLoop", ""),
        ("setTint", "modelSetTint", ""),
        ("animate", "modelAnimate", ""),
        ("destroy", "modelDestroy", ""),
        ("isValid", "modelIsValid", ""),
        ("isValidStrict", "modelIsValidStrict", ""),
        ("getAnimationCount", "modelGetAnimationCount", ""),
        ("getAnimationFrameCount", "modelGetAnimationFrameCount", ""),
        ("updateAnimation", "modelUpdateAnimation", ""),
    ],
    "Sprite3d": [
        ("create", "sprite3dCreate", ""),
        ("createFromFile", "sprite3dCreateFromFile", ""),
        ("setTexture", "sprite3dSetTexture", ""),
        ("setTransform", "sprite3dSetTransform", ""),
        ("getTransform", "sprite3dGetTransform", ""),
        ("setFacing", "sprite3dSetFacing", ""),
        ("setTint", "sprite3dSetTint", ""),
        ("draw", "sprite3dDraw", ""),
        ("destroy", "sprite3dDestroy", ""),
        ("getDefaultTexture", "sprite3dGetDefaultTexture", ""),
    ],
    "Sprite2d": [
        ("create", "sprite2dCreate", ""),
        ("createFromFile", "sprite2dCreateFromFile", ""),
        ("setTexture", "sprite2dSetTexture", ""),
        ("setTransform", "sprite2dSetTransform", ""),
        ("setTint", "sprite2dSetTint", ""),
        ("draw", "sprite2dDraw", ""),
        ("destroy", "sprite2dDestroy", ""),
        ("getDefaultTexture", "sprite2dGetDefaultTexture", ""),
    ],
    "Text2d": [
        ("create", "text2dCreate", ""),
        ("setFont", "text2dSetFont", ""),
        ("setSize", "text2dSetSize", ""),
        ("setContent", "text2dSetContent", ""),
        ("setPosition", "text2dSetPosition", ""),
        ("setColor", "text2dSetColor", ""),
        ("draw", "text2dDraw", ""),
        ("destroy", "text2dDestroy", ""),
    ],
    "Pick": [
        ("model", "pickModel", ""),
        ("sprite3d", "pickSprite3d", ""),
        ("resetStats", "pickResetStats", ""),
        ("getBroadphaseTests", "pickGetBroadphaseTests", ""),
        ("getBroadphaseRejects", "pickGetBroadphaseRejects", ""),
        ("getNarrowphaseTests", "pickGetNarrowphaseTests", ""),
        ("getNarrowphaseHits", "pickGetNarrowphaseHits", ""),
    ],
    "Music": [
        ("create", "musicCreate", ""),
        ("destroy", "musicDestroy", ""),
        ("play", "musicPlay", ""),
        ("pause", "musicPause", ""),
        ("stop", "musicStop", ""),
        ("setLoop", "musicSetLoop", ""),
        ("setVolume", "musicSetVolume", ""),
        ("isPlaying", "musicIsPlaying", ""),
        ("update", "musicUpdate", ""),
        ("updateAll", "musicUpdateAll", ""),
    ],
    "Sound": [
        ("create", "soundCreate", ""),
        ("destroy", "soundDestroy", ""),
        ("play", "soundPlay", ""),
        ("pause", "soundPause", ""),
        ("resume", "soundResume", ""),
        ("stop", "soundStop", ""),
        ("setVolume", "soundSetVolume", ""),
        ("setPitch", "soundSetPitch", ""),
        ("setPan", "soundSetPan", ""),
        ("isPlaying", "soundIsPlaying", ""),
    ],
    "Logger": [
        ("message", "loggerMessage", ""),
        ("messageSource", "loggerMessageSource", ""),
        ("setLevel", "loggerSetLevel", ""),
    ],
    "Shape": [
        ("drawRectangle", "shapeDrawRectangle", ""),
        ("drawCube", "shapeDrawCube", ""),
    ],
    "Debug": [
        ("enableFps", "debugEnableFps", ""),
        ("disable", "debugDisable", ""),
    ],
    "Event": [
        ("on", "eventOn", ""),
        ("once", "eventOnce", ""),
        ("off", "eventOff", ""),
        ("offAll", "eventOffAll", ""),
        ("emit", "eventEmit", ""),
        ("listenerCount", "eventListenerCount", ""),
    ],
}

# Signatures copied from current RL.hx (impl side unchanged)
SIGNATURES: dict[str, str] = {
    "fsInit": "public static function init(?baseDir:String):Int",
    "fsInitAsync": "public static function initAsync(?baseDir:String):Int",
    "fsDeinit": "public static function deinit():RLAsyncVoid",
    "fsDeinitAsync": "public static function deinitAsync():RLHandle",
    "fsIsInitialized": "public static function isInitialized():Bool",
    "fsIsReady": "public static function isReady():Bool",
    "fsFlush": "public static function flush():Int",
    "fsGetRootDir": "public static function getRootDir():String",
    "fsNormalizePath": "public static function normalizePath(path:String):String",
    "fsRestoreAsync": "public static function restoreAsync():RLHandle",
    "fsRead": "public static function read(filename:String):Bytes",
    "fsWrite": "public static function write(path:String, bytes:Bytes):Int",
    "fsExists": "public static function exists(filename:String):Bool",
    "fsRemove": "public static function remove(filename:String):Int",
    "fsClear": "public static function clear():Int",
    "fsMkdir": "public static function mkdir(path:String):Int",
    "fsRmdir": "public static function rmdir(path:String):Int",
    "assetSetHost": "public static function setHost(assetHost:String):Int",
    "assetGetHost": "public static function getHost():String",
    "assetPingHost": "public static function pingHost(?assetHost:String):Float",
    "assetEnsureAsync": "public static function ensureAsync(localPath:String, ?src:String):RLHandle",
    "assetEnsure": "public static function ensure(localPath:String, ?src:String):Int",
    "assetEnsureGroupAsync": "public static function ensureGroupAsync(filenames:Array<String>):RLHandle",
    "assetPollTask": "public static function pollTask(task:RLHandle):Bool",
    "assetFinishTask": "public static function finishTask(task:RLHandle):Int",
    "assetGetTaskPath": "public static function getTaskPath(task:RLHandle):String",
    "assetFreeTask": "public static function freeTask(task:RLHandle):Void",
    "assetAddTask": "public static function addTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int",
    "assetTick": "public static function tick():Void",
    "assetTaskInvalid": "public static function taskInvalid():RLHandle",
    "assetTaskIsValid": "public static function taskIsValid(task:RLHandle):Bool",
    "windowCloseRequested": "public static function closeRequested():Bool",
    "windowGetScreenSize": "public static function getScreenSize():RLVec2",
    "windowGetMonitorCount": "public static function getMonitorCount():Int",
    "windowSetTitle": "public static function setTitle(title:String):Void",
    "windowSetSize": "public static function setSize(width:Int, height:Int):Void",
    "windowGetCurrentMonitor": "public static function getCurrentMonitor():Int",
    "windowSetMonitor": "public static function setMonitor(monitor:Int):Void",
    "windowGetMonitorWidth": "public static function getMonitorWidth(monitor:Int):Int",
    "windowGetMonitorHeight": "public static function getMonitorHeight(monitor:Int):Int",
    "windowGetMonitorPosition": "public static function getMonitorPosition(monitor:Int):RLVec2",
    "windowGetPosition": "public static function getPosition():RLVec2",
    "windowSetPosition": "public static function setPosition(x:Int, y:Int):Void",
    "enableLighting": "public static function enableLighting():Void",
    "disableLighting": "public static function disableLighting():Void",
    "isLightingEnabled": "public static function isLightingEnabled():Int",
    "setLightDirection": "public static function setLightDirection(x:Float, y:Float, z:Float):Void",
    "setLightAmbient": "public static function setLightAmbient(ambient:Float):Void",
    "renderBegin": "public static function begin():Void",
    "renderEnd": "public static function end():Void",
    "renderClearBackground": "public static function clearBackground(color:RLHandle):Void",
    "renderBeginMode2D": "public static function beginMode2D(camera:RLHandle):Void",
    "renderEndMode2D": "public static function endMode2D():Void",
    "renderBeginMode3d": "public static function beginMode3d():Void",
    "renderEndMode3d": "public static function endMode3d():Void",
    "inputPollEvents": "public static function pollEvents():Void",
    "inputGetMousePosition": "public static function getMousePosition():RLVec2",
    "inputGetMouseWheel": "public static function getMouseWheel():Int",
    "inputGetMouseButton": "public static function getMouseButton(button:Int):Int",
    "inputGetMouseState": "public static function getMouseState():RLMouseState",
    "inputGetKeyboardState": "public static function getKeyboardState():RLKeyboardState",
    "inputGetGamepads": "public static function getGamepads():Array<RLGamepad>",
    "inputGetGamepad": "public static function getGamepad(id:Int):Null<RLGamepad>",
    "inputGetTouchpoints": "public static function getTouchpoints():Array<RLTouchpoint>",
    "inputGetTouchpoint": "public static function getTouchpoint(id:Int):Null<RLTouchpoint>",
    "camera3dCreate": "public static function create(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle",
    "camera3dSet": "public static function set(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool",
    "camera3dSetActive": "public static function setActive(camera:RLHandle):Bool",
    "camera3dDestroy": "public static function destroy(camera:RLHandle):Void",
    "camera3dGetDefault": "public static function getDefault():RLHandle",
    "camera3dGetActive": "public static function getActive():RLHandle",
    "fontCreate": "public static function create(filename:String, fontSize:Int):RLHandle",
    "fontDestroy": "public static function destroy(font:RLHandle):Void",
    "fontGetDefault": "public static function getDefault():RLHandle",
    "textDraw": "public static function draw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void",
    "textMeasure": "public static function measure(text:String, fontSize:Int):Int",
    "textDrawFps": "public static function drawFps(x:Int, y:Int):Void",
    "textDrawEx": "public static function drawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void",
    "textMeasureEx": "public static function measureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2",
    "textDrawFpsEx": "public static function drawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void",
    "textureCreate": "public static function create(filename:String):RLHandle",
    "textureDestroy": "public static function destroy(texture:RLHandle):Void",
    "textureGetDefault": "public static function getDefault():RLHandle",
    "textureDrawEx": "public static function drawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void",
    "textureDrawGround": "public static function drawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float, tint:RLHandle):Void",
    "modelLoadAsset": "public static function loadAsset(filename:String):RLHandle",
    "modelDestroyAsset": "public static function destroyAsset(asset:RLHandle):Void",
    "modelGetDefaultAsset": "public static function getDefaultAsset():RLHandle",
    "modelCreate": "public static function create(asset:RLHandle):RLHandle",
    "modelCreateFromFile": "public static function createFromFile(filename:String):RLHandle",
    "modelSetAsset": "public static function setAsset(model:RLHandle, asset:RLHandle):Bool",
    "modelSetTransform": "public static function setTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool",
    "modelDraw": "public static function draw(model:RLHandle, tint:RLHandle = 0):Void",
    "modelSetAnimation": "public static function setAnimation(model:RLHandle, animationIndex:Int):Bool",
    "modelSetAnimationSpeed": "public static function setAnimationSpeed(model:RLHandle, speed:Float):Bool",
    "modelSetAnimationLoop": "public static function setAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool",
    "modelSetTint": "public static function setTint(model:RLHandle, color:RLHandle = 0):Bool",
    "modelAnimate": "public static function animate(model:RLHandle, deltaSeconds:Float):Bool",
    "modelDestroy": "public static function destroy(model:RLHandle):Void",
    "modelIsValid": "public static function isValid(model:RLHandle):Bool",
    "modelIsValidStrict": "public static function isValidStrict(model:RLHandle):Bool",
    "modelGetAnimationCount": "public static function getAnimationCount(model:RLHandle):Int",
    "modelGetAnimationFrameCount": "public static function getAnimationFrameCount(model:RLHandle, animationIndex:Int):Int",
    "modelUpdateAnimation": "public static function updateAnimation(model:RLHandle, animationIndex:Int, frame:Int):Void",
    "sprite3dCreate": "public static function create(texture:RLHandle):RLHandle",
    "sprite3dCreateFromFile": "public static function createFromFile(filename:String):RLHandle",
    "sprite3dSetTexture": "public static function setTexture(sprite:RLHandle, texture:RLHandle):Bool",
    "sprite3dSetTransform": "public static function setTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool",
    "sprite3dGetTransform": "public static function getTransform(sprite:RLHandle):RLSprite3dTransform",
    "sprite3dSetSize": "public static function setSize(sprite:RLHandle, size:Float):Bool",
    "sprite3dSetFacing": "public static function setFacing(sprite:RLHandle, facing:RLSprite3dFacing):Bool",
    "sprite3dSetTint": "public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool",
    "sprite3dDraw": "public static function draw(sprite:RLHandle, tint:RLHandle = 0):Void",
    "sprite3dDestroy": "public static function destroy(sprite:RLHandle):Void",
    "sprite3dGetDefaultTexture": "public static function getDefaultTexture():RLHandle",
    "sprite2dCreate": "public static function create(texture:RLHandle):RLHandle",
    "sprite2dCreateFromFile": "public static function createFromFile(filename:String):RLHandle",
    "sprite2dSetTexture": "public static function setTexture(sprite:RLHandle, texture:RLHandle):Bool",
    "sprite2dSetTransform": "public static function setTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool",
    "sprite2dSetTint": "public static function setTint(sprite:RLHandle, color:RLHandle = 0):Bool",
    "sprite2dDraw": "public static function draw(sprite:RLHandle, tint:RLHandle = 0):Void",
    "sprite2dDestroy": "public static function destroy(sprite:RLHandle):Void",
    "sprite2dGetDefaultTexture": "public static function getDefaultTexture():RLHandle",
    "text2dCreate": "public static function create(font:RLHandle, size:Float):RLHandle",
    "text2dSetFont": "public static function setFont(handle:RLHandle, font:RLHandle):Void",
    "text2dSetSize": "public static function setSize(handle:RLHandle, size:Float):Void",
    "text2dSetContent": "public static function setContent(handle:RLHandle, content:String):Void",
    "text2dSetPosition": "public static function setPosition(handle:RLHandle, x:Float, y:Float):Void",
    "text2dSetColor": "public static function setColor(handle:RLHandle, color:RLHandle):Void",
    "text2dDraw": "public static function draw(handle:RLHandle):Void",
    "text2dDestroy": "public static function destroy(handle:RLHandle):Void",
    "pickModel": "public static function model(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult",
    "pickSprite3d": "public static function sprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult",
    "pickResetStats": "public static function resetStats():Void",
    "pickGetBroadphaseTests": "public static function getBroadphaseTests():Int",
    "pickGetBroadphaseRejects": "public static function getBroadphaseRejects():Int",
    "pickGetNarrowphaseTests": "public static function getNarrowphaseTests():Int",
    "pickGetNarrowphaseHits": "public static function getNarrowphaseHits():Int",
    "musicCreate": "public static function create(filename:String):RLHandle",
    "musicDestroy": "public static function destroy(music:RLHandle):Void",
    "musicPlay": "public static function play(music:RLHandle):Bool",
    "musicPause": "public static function pause(music:RLHandle):Bool",
    "musicStop": "public static function stop(music:RLHandle):Bool",
    "musicSetLoop": "public static function setLoop(music:RLHandle, shouldLoop:Bool):Bool",
    "musicSetVolume": "public static function setVolume(music:RLHandle, volume:Float):Bool",
    "musicIsPlaying": "public static function isPlaying(music:RLHandle):Bool",
    "musicUpdate": "public static function update(music:RLHandle):Bool",
    "musicUpdateAll": "public static function updateAll():Void",
    "soundCreate": "public static function create(filename:String):RLHandle",
    "soundDestroy": "public static function destroy(sound:RLHandle):Void",
    "soundPlay": "public static function play(sound:RLHandle):Bool",
    "soundPause": "public static function pause(sound:RLHandle):Bool",
    "soundResume": "public static function resume(sound:RLHandle):Bool",
    "soundStop": "public static function stop(sound:RLHandle):Bool",
    "soundSetVolume": "public static function setVolume(sound:RLHandle, volume:Float):Bool",
    "soundSetPitch": "public static function setPitch(sound:RLHandle, pitch:Float):Bool",
    "soundSetPan": "public static function setPan(sound:RLHandle, pan:Float):Bool",
    "soundIsPlaying": "public static function isPlaying(sound:RLHandle):Bool",
    "loggerMessage": "public static function message(level:Int, message:String):Void",
    "loggerMessageSource": "public static function messageSource(level:Int, sourceFile:String, sourceLine:Int, message:String):Void",
    "loggerSetLevel": "public static function setLevel(level:Int):Void",
    "shapeDrawRectangle": "public static function drawRectangle(x:Int, y:Int, width:Int, height:Int, color:RLHandle):Void",
    "shapeDrawCube": "public static function drawCube(positionX:Float, positionY:Float, positionZ:Float, width:Float, height:Float, length:Float, color:RLHandle):Void",
    "debugEnableFps": "public static function enableFps(x:Int, y:Int, fontSize:Int, font:RLHandle):Void",
    "debugDisable": "public static function disable():Void",
    "eventOn": "public static function on(eventName:String, callback:Dynamic->Void):Int",
    "eventOnce": "public static function once(eventName:String, callback:Dynamic->Void):Int",
    "eventOff": "public static function off(eventName:String, callback:Dynamic->Void):Int",
    "eventOffAll": "public static function offAll(eventName:String):Int",
    "eventEmit": "public static function emit(eventName:String, ?payload:Int):Int",
    "eventListenerCount": "public static function listenerCount(eventName:String):Int",
}

ASYNC_CAST = {"fsInit", "fsDeinit", "assetEnsure", "init"}


def needs_bytes_import(class_name: str) -> bool:
    return class_name == "Fs"


def render_class(class_name: str, methods: list[tuple[str, str, str]]) -> str:
    imports = [
        "import rl.Types.RLHandle;",
        "import rl.Types.RLVec2;",
        "import rl.Types.RLPickResult;",
        "import rl.Types.RLMouseState;",
        "import rl.Types.RLKeyboardState;",
        "import rl.Types.RLAsyncVoid;",
    ]
    if needs_bytes_import(class_name):
        imports.insert(0, "import haxe.io.Bytes;")

    lines = [
        "/** Public façade for rl_" + class_name.lower() + " / RL." + class_name.lower() + " (generated; edit tools/gen_haxe_public_sections.py). */",
        "package rl;",
        "",
    ]
    for imp in imports:
        lines.append(imp)
    lines.extend(["", "@:keep", "class " + class_name + " {"])

    for _pub, impl, extra in methods:
        sig = SIGNATURES[impl]
        lines.append("")
        if extra:
            lines.append("\t" + extra)
        ret_type = "Int" if impl == "assetEnsure" else None
        body = f"\t\treturn rl.impl.RLImpl.{impl}("
        if impl in ASYNC_CAST:
            lines.append("\t" + sig + " {")
            if impl == "assetEnsure":
                lines.append("\t\treturn cast rl.impl.RLImpl.assetEnsure(localPath, src);")
            else:
                lines.append(f"\t\treturn cast rl.impl.RLImpl.{impl}(...)".replace("(...", "(" + _args_from_sig(sig)))
            lines.append("\t}")
            continue
        lines.append("\t" + sig + " {")
        call = call_expr(impl, sig)
        lines.append(f"\t\treturn {call};" if "return " in infer_return(sig) else f"\t\t{call};")
        lines.append("\t}")

    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def _args_from_sig(sig: str) -> str:
    m = re.search(r"\((.*)\)", sig)
    if not m:
        return ""
    inner = m.group(1).strip()
    if not inner:
        return ""
    parts = []
    for p in inner.split(","):
        p = p.strip()
        if p.startswith("?"):
            p = p[1:]
        name = p.split(":")[0].strip()
        parts.append(name)
    return ", ".join(parts)


def infer_return(sig: str) -> str:
    if ":Void" in sig:
        return "void"
    return "value"


def call_expr(impl: str, sig: str) -> str:
    args = _args_from_sig(sig)
    if ":Void" in sig:
        return f"rl.impl.RLImpl.{impl}({args})"
    return f"rl.impl.RLImpl.{impl}({args})"


CLASS_PREAMBLES: dict[str, list[str]] = {
    "Input": [
        "public static inline var BUTTON_UP:Int = rl.impl.RLImpl.BUTTON_UP;",
        "public static inline var BUTTON_PRESSED:Int = rl.impl.RLImpl.BUTTON_PRESSED;",
        "public static inline var BUTTON_DOWN:Int = rl.impl.RLImpl.BUTTON_DOWN;",
        "public static inline var BUTTON_RELEASED:Int = rl.impl.RLImpl.BUTTON_RELEASED;",
    ],
    "Window": [
        "public static inline var FLAG_WINDOW_RESIZABLE:Int = rl.impl.RLImpl.FLAG_WINDOW_RESIZABLE;",
        "public static inline var FLAG_MSAA_4X_HINT:Int = rl.impl.RLImpl.FLAG_MSAA_4X_HINT;",
        "public static inline var FLAG_VSYNC_HINT:Int = rl.impl.RLImpl.FLAG_VSYNC_HINT;",
    ],
    "Camera3d": [
        "public static inline var PERSPECTIVE:Int = rl.impl.RLImpl.CAMERA_PERSPECTIVE;",
        "public static inline var ORTHOGRAPHIC:Int = rl.impl.RLImpl.CAMERA_ORTHOGRAPHIC;",
    ],
    "Asset": [
        "public static inline var ADD_TASK_OK:Int = rl.impl.RLImpl.ASSET_ADD_TASK_OK;",
        "public static inline var ADD_TASK_ERR_INVALID:Int = rl.impl.RLImpl.ASSET_ADD_TASK_ERR_INVALID;",
        "public static inline var ADD_TASK_ERR_QUEUE_FULL:Int = rl.impl.RLImpl.ASSET_ADD_TASK_ERR_QUEUE_FULL;",
    ],
    "Logger": [
        "public static inline var LEVEL_TRACE:Int = rl.impl.RLImpl.LOGGER_LEVEL_TRACE;",
        "public static inline var LEVEL_DEBUG:Int = rl.impl.RLImpl.LOGGER_LEVEL_DEBUG;",
        "public static inline var LEVEL_INFO:Int = rl.impl.RLImpl.LOGGER_LEVEL_INFO;",
        "public static inline var LEVEL_WARN:Int = rl.impl.RLImpl.LOGGER_LEVEL_WARN;",
        "public static inline var LEVEL_ERROR:Int = rl.impl.RLImpl.LOGGER_LEVEL_ERROR;",
        "public static inline var LEVEL_FATAL:Int = rl.impl.RLImpl.LOGGER_LEVEL_FATAL;",
    ],
}

TYPE_IMPORT_LINES: list[tuple[str, str]] = [
    ("RLHandle", "import rl.Types.RLHandle;"),
    ("RLVec2", "import rl.Types.RLVec2;"),
    ("RLPickResult", "import rl.Types.RLPickResult;"),
    ("RLMouseState", "import rl.Types.RLMouseState;"),
    ("RLKeyboardState", "import rl.Types.RLKeyboardState;"),
    ("RLGamepad", "import rl.Types.RLGamepad;"),
    ("RLTouchpoint", "import rl.Types.RLTouchpoint;"),
    ("RLSprite3dTransform", "import rl.Types.RLSprite3dTransform;"),
    ("RLAsyncVoid", "import rl.Types.RLAsyncVoid;"),
    ("Bytes", "import haxe.io.Bytes;"),
]


def imports_for_class(class_name: str, methods: list[tuple[str, str, str]]) -> list[str]:
    sig_text = "\n".join(SIGNATURES[impl] for _, impl, _ in methods)
    imports: list[str] = []
    for type_name, line in TYPE_IMPORT_LINES:
        if type_name in sig_text and line not in imports:
            imports.append(line)
    if class_name == "Fs" and "import haxe.io.Bytes;" not in imports:
        imports.insert(0, "import haxe.io.Bytes;")
    return imports


def fix_method_block(content: str, class_name: str, methods: list) -> str:
    """Regenerate with proper bodies and minimal imports."""
    out = [
        f"/** Public façade: {class_name} subsystem. */",
        "package rl;",
        "",
    ]
    out.extend(imports_for_class(class_name, methods))
    out.extend(["", "@:keep", f"class {class_name} {{", ""])

    for line in CLASS_PREAMBLES.get(class_name, []):
        out.append(f"\t{line}")
    if CLASS_PREAMBLES.get(class_name):
        out.append("")

    for _pub, impl, extra in methods:
        sig = SIGNATURES[impl]
        args = _args_from_sig(sig)
        out.append("")
        if extra:
            out.append(f"\t{extra}")
        out.append(f"\t{sig} {{")
        if impl in ("fsInit", "fsDeinit", "assetEnsure"):
            out.append(f"\t\treturn cast rl.impl.RLImpl.{impl}({args});")
        elif ":Void" in sig:
            out.append(f"\t\trl.impl.RLImpl.{impl}({args});")
        else:
            out.append(f"\t\treturn rl.impl.RLImpl.{impl}({args});")
        out.append("\t}")

    out.append("}")
    out.append("")
    return "\n".join(out)


def main() -> None:
    for class_name, methods in SECTIONS.items():
        path = OUT / f"{class_name}.hx"
        path.write_text(fix_method_block("", class_name, methods), encoding="utf-8")
        print("wrote", path)


if __name__ == "__main__":
    main()
