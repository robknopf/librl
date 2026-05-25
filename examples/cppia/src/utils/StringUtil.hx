package utils;

class StringUtil {
	public static function formatFixed(value:Float, digits:Int):String {
		var scale = Math.pow(10, digits);
		var rounded = Math.round(value * scale) / scale;
		var text = Std.string(rounded);
		var dot = text.indexOf(".");
		if (digits <= 0) {
			return dot >= 0 ? text.substr(0, dot) : text;
		}
		if (dot < 0) {
			return text + "." + StringTools.rpad("", "0", digits);
		}
		var decimals = text.length - dot - 1;
		if (decimals > digits) {
			return text.substr(0, dot + 1 + digits);
		}
		if (decimals < digits) {
			return text + StringTools.rpad("", "0", digits - decimals);
		}
		return text;
	}
}
