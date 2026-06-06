/** Public façade: Shape subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Shape {

	public static function create():RLHandle {
		return rl.impl.RLImpl.shapeCreate();
	}

	public static function destroy(shape:RLHandle):Void {
		rl.impl.RLImpl.shapeDestroy(shape);
	}

	public static function setVisible(shape:RLHandle, visible:Bool):Bool {
		return rl.impl.RLImpl.shapeSetVisible(shape, visible);
	}

	public static function isVisible(shape:RLHandle):Bool {
		return rl.impl.RLImpl.shapeIsVisible(shape);
	}

	public static function setStrokeColor(shape:RLHandle, color:RLHandle):Bool {
		return rl.impl.RLImpl.shapeSetStrokeColor(shape, color);
	}

	public static function setLine3d(shape:RLHandle, startX:Float, startY:Float, startZ:Float, endX:Float, endY:Float, endZ:Float):Bool {
		return rl.impl.RLImpl.shapeSetLine3d(shape, startX, startY, startZ, endX, endY, endZ);
	}

	public static function setLineStrip3d(shape:RLHandle, points:Array<Float>):Bool {
		return rl.impl.RLImpl.shapeSetLineStrip3d(shape, points);
	}

	public static function draw(shape:RLHandle):Void {
		rl.impl.RLImpl.shapeDraw(shape);
	}

	public static function drawRectangle(x:Int, y:Int, width:Int, height:Int, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawRectangle(x, y, width, height, color);
	}

	public static function drawCube(positionX:Float, positionY:Float, positionZ:Float, width:Float, height:Float, length:Float, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawCube(positionX, positionY, positionZ, width, height, length, color);
	}

	public static function drawCircle3d(centerX:Float, centerY:Float, centerZ:Float, radius:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawCircle3d(centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color);
	}

	public static function drawLine3d(startX:Float, startY:Float, startZ:Float, endX:Float, endY:Float, endZ:Float, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawLine3d(startX, startY, startZ, endX, endY, endZ, color);
	}

	public static function drawLineStrip3d(points:Array<Float>, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawLineStrip3d(points, color);
	}
}
