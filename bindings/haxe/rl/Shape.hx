/** Public façade: Shape subsystem. */
package rl;

import rl.Types.RLHandle;

@:keep
class Shape {


	public static function drawRectangle(x:Int, y:Int, width:Int, height:Int, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawRectangle(x, y, width, height, color);
	}

	public static function drawCube(positionX:Float, positionY:Float, positionZ:Float, width:Float, height:Float, length:Float, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawCube(positionX, positionY, positionZ, width, height, length, color);
	}

	public static function drawCircle3d(centerX:Float, centerY:Float, centerZ:Float, radius:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float, color:RLHandle):Void {
		rl.impl.RLImpl.shapeDrawCircle3d(centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color);
	}
}
