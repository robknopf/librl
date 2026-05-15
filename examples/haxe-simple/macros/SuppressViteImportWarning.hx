package macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;

class SuppressViteImportWarning {
	macro public static function apply(jsFile:String):Void {
		if (!sys.FileSystem.exists(jsFile)) {
			trace('ERROR: File does not exist: ' + jsFile);
			return;
		}

		var content = File.getContent(jsFile);
		// Search for dynamicImport and add the vite-ignore comment
		content = StringTools.replace(content, "return import(module);", "return import( /* @vite-ignore */ module);");
		File.saveContent(jsFile, content);
	}
}
