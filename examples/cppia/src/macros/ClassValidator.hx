package macros;

#if macro
import haxe.macro.Context;

class ClassValidator {
	public static function validateExtends(className:String, extendsClassName:String):Void {
		Context.onAfterTyping((_) -> {
			var scriptType = Context.getType(className);
			var scriptIface = Context.getType(extendsClassName);
			if (!Context.unify(scriptType, scriptIface))
				Context.error('$className must extend $extendsClassName', Context.makePosition({file: "", min: 0, max: 0}));
		});
	}

	public static function validateImplements(className:String, implementsClassName:String):Void {
		Context.onAfterTyping((_) -> {
			var scriptType = Context.getType(className);
			var scriptIface = Context.getType(implementsClassName);
			if (!Context.unify(scriptType, scriptIface))
				Context.error('$className must implement $implementsClassName', Context.makePosition({file: "", min: 0, max: 0}));
		});
	}
}
#end