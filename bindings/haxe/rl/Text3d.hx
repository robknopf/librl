/** Public façade: Text3d subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLVec2;

@:keep
class Text3d {

    public static function create(font:RLHandle, size:Float):RLHandle {
        return rl.impl.RLImpl.text3dCreate(font, size);
    }

    public static function setFont(handle:RLHandle, font:RLHandle):Void {
        rl.impl.RLImpl.text3dSetFont(handle, font);
    }

    public static function setSize(handle:RLHandle, size:Float):Void {
        rl.impl.RLImpl.text3dSetSize(handle, size);
    }

    public static function setContent(handle:RLHandle, content:String):Void {
        rl.impl.RLImpl.text3dSetContent(handle, content);
    }

    public static function setTransform(handle:RLHandle, x:Float, y:Float, z:Float, rx:Float, ry:Float, rz:Float):Bool {
        return rl.impl.RLImpl.text3dSetTransform(handle, x, y, z, rx, ry, rz);
    }

    public static function setColor(handle:RLHandle, color:RLHandle):Void {
        rl.impl.RLImpl.text3dSetColor(handle, color);
    }

    public static function setFacing(handle:RLHandle, facing:Int):Bool {
        return rl.impl.RLImpl.text3dSetFacing(handle, facing);
    }

    public static function setVisible(handle:RLHandle, visible:Bool):Bool {
        return rl.impl.RLImpl.text3dSetVisible(handle, visible);
    }

    public static function setPickable(handle:RLHandle, pickable:Bool):Bool {
        return rl.impl.RLImpl.text3dSetPickable(handle, pickable);
    }

    public static function isVisible(handle:RLHandle):Bool {
        return rl.impl.RLImpl.text3dIsVisible(handle);
    }

    public static function isPickable(handle:RLHandle):Bool {
        return rl.impl.RLImpl.text3dIsPickable(handle);
    }

    public static function getBounds(handle:RLHandle):RLVec2 {
        return rl.impl.RLImpl.text3dGetBounds(handle);
    }

    public static function draw(handle:RLHandle):Void {
        rl.impl.RLImpl.text3dDraw(handle);
    }

    public static function drawText(text:String, font:RLHandle, x:Float, y:Float, z:Float, size:Float, color:RLHandle):Void {
        rl.impl.RLImpl.text3dDrawText(text, font, x, y, z, size, color);
    }

    public static function destroy(handle:RLHandle):Void {
        rl.impl.RLImpl.text3dDestroy(handle);
    }
}
