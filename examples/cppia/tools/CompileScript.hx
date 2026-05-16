package tools;

// a tool to build the haxe project, in the style of the nim build tool (or nobuild/nob.h)
import sys.FileSystem;
import Sys;
import haxe.io.Path;
import haxe.Timer;
import tools.PathUtil.*;

enum BuildMode {
	Debug;
	Release;
}

enum abstract Verbosity(String) to String {
	var Silent = "HXCPP_SILENT";
	var Verbose = "HXCPP_VERBOSE";
	var Quiet = "HXCPP_QUIET";
}

class CompileScript {
	static var thisPath = Path.normalize(Sys.programPath()); // location of this file
	static var thisDir = Path.directory(thisPath);
	static var projectRoot = joinPath(thisDir, "..");
	static var librlRoot = joinPath(projectRoot, "..", "..", "..", "..", "raylib", "librl");
	static var wgutilsRoot = joinPath(librlRoot, "deps", "wgutils");
	static var sysArgs = Sys.args();
	static var scriptClassName = (sysArgs.length > 0) ? sysArgs[sysArgs.length - 1] : "";
	static var verbosity:Verbosity = Verbosity.Silent; // HXCPP_SILENT, HXCPP_VERBOSE, HXCPP_QUIET
	static var buildMode:BuildMode = Release;
	static var scriptsDir = joinPath(librlRoot, "examples", "www", "public", "assets", "scripts", "haxe");
	static var srcDir = joinPath(projectRoot, "src");
	static var bindingsDir = joinPath(librlRoot, "bindings", "haxe");

	static var debugArgs = [
		"--debug", 
		"--dce", "no"
	];
	static var releaseArgs = [
		"--dce", "full",
		"-D", "analyzer-optimize",
		// "-D", "no-traces",
	];
	static var exportClassesInfo = joinPath(projectRoot, "export_classes.info");
	static var commonArgs = [
		"-cp", srcDir,  // order matters.  haxe will look for types in the last directory first
		"-cp", bindingsDir,
		"-cp", scriptsDir,
		"-D", 'LIBRL_ROOT=${librlRoot}',
		"-D", 'WGUTILS_ROOT=${wgutilsRoot}',
		"-D", verbosity,
		"-D", 'dll_import=${exportClassesInfo}',
		//"-lib", 'hxasync'
	];

	static function info(msg:String):Void {
		Sys.print("\x1b[90m" + "> " + msg + "\x1b[0m\n");
	}

	static function warn(msg:String):Void {
		Sys.print("\x1b[33m" + "> " + msg + "\x1b[0m\n");
	}

	static function error(msg:String):Void {
		Sys.print("\x1b[31m" + "> " + msg + "\x1b[0m\n");
	}

	static function success(msg:String):Void {
		Sys.print("\x1b[32m" + "> " + msg + "\x1b[0m\n");
	}

	static function runHaxe(args:Array<String>):Int {
		info("Running Haxe " + (buildMode == Debug ? "debug" : "release") + " '" + args.join(" ") + "'...");
		var code = Sys.command("haxe", args);
		if (code != 0)
			Sys.exit(code);
		return code;
	}

	static function buildModeArgs() {
		if (buildMode == Debug) {
			return debugArgs;
		}
		return releaseArgs;
	}

	static function showUsage() {
		Sys.println("usage: haxe [-cp tools]--run CompileScript [--debug] <class-name>");
	}

	static function hasDebugFlag(args:Array<String>):Bool {
		return args.contains("--debug") || args.contains("-D") && args.contains("debug");
	}

	static function classNameToPath(className:String):String {
		// replace dots with slashes
		className = StringTools.replace(className, ".", "/");
		// add .cppia extension
		className = className + ".cppia";
		return joinPath(scriptsDir, className);
	}

	static function buildCppia(?additionalArgs:Array<String>):Int {
		var cppiaPath = classNameToPath(scriptClassName);
		info("Building CPPIA "
			+ (buildMode == Debug ? "debug" : "release")
			+ " '"
			+ cppiaPath
			+ "'...");
		var args = [];
		if (additionalArgs != null)
			args = args.concat(additionalArgs);
		if (commonArgs != null)
			args = args.concat(commonArgs);
		args = args.concat(buildModeArgs());
		args = args.concat(["--macro", 'macros.ClassValidator.validateExtends("${scriptClassName}", "Script")']);
		args = args.concat(["-cppia", cppiaPath]);
		args.push(scriptClassName);
		return runHaxe(args);
	}

	static function main() {
		/*
		// debugging, show the paths
		trace("thisDir: " + thisDir);
		trace("projectRoot: " + projectRoot);
		trace("librlRoot: " + librlRoot);
		trace("wgutilsRoot: " + wgutilsRoot);
		trace("srcDir: " + srcDir);
		trace("bindingsDir: " + bindingsDir);
		trace("scriptsDir: " + scriptsDir);
		trace("exportClassesInfo: " + exportClassesInfo);
		trace("commonArgs: " + commonArgs);
		*/

		trace(sysArgs);
		var errorCode = 0;
		var buildStartTime:Float = 0;
		var buildEndTime:Float = 0;

		if (hasDebugFlag(sysArgs)) {
			buildMode = Debug;
		} else {
			buildMode = Release;
		}

		if (scriptClassName == null) {
			error("No script class name provided");
			Sys.exit(1);
		}

        sysArgs.pop();
        buildStartTime = Timer.stamp();
        errorCode = buildCppia(sysArgs);
        buildEndTime = Timer.stamp();
        if (errorCode != 0) {
            error('Failed: ${errorCode}');
        } else {
            var buildDuration = buildEndTime - buildStartTime;
            var buildDurationRounded = Math.round(buildDuration * 10000) / 10000;
            success('Build complete.  Total time: (${buildDurationRounded} seconds)');
        }
	}
}
