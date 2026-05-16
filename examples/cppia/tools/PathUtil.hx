package tools;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import Sys; // for Sys.command if needed

class PathUtil {
	public static function rmdir(path:String):Void {
		if (path == null || path.length == 0) {
			throw "Refusing to delete empty/null path";
		}

		if (!FileSystem.exists(path)) {
			return;
		}

		if (!FileSystem.isDirectory(path)) {
			FileSystem.deleteFile(path);
			return;
		}

		for (entry in FileSystem.readDirectory(path)) {
			var child = Path.join([path, entry]);

			if (FileSystem.isDirectory(child)) {
				rmdir(child);
			} else {
				FileSystem.deleteFile(child);
			}
		}

		FileSystem.deleteDirectory(path);
	}

	public static function mkdir(path:String):Void {
		if (!FileSystem.exists(path)) {
			FileSystem.createDirectory(path);
		}
	}

	public static function joinPath(pathComponents:haxe.Rest<String>):String {
		return Path.normalize(Path.join(pathComponents.toArray()));
	}

	public static function getStaticLibExtension():String {
		return switch (Sys.systemName()) {
			case "Windows": ".lib";
			case "Mac": ".a";
			case _: ".a";
		}
	}

	public static function findStaticLibFromPath(libPath:String):String {
		if (FileSystem.exists(libPath)) {
			return libPath;
		}
		var ext = getStaticLibExtension();
		var libPathWithExt = libPath + ext;
		if (FileSystem.exists(libPathWithExt)) {
			return libPathWithExt;
		}
		return null;
	}
}
