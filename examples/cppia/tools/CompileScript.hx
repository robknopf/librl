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

enum BuildTarget {
	Cppia;
	Js;
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
	static var buildMode:BuildMode = Release; // this will change if "--debug" is provided in the sys args
	static var buildTarget:BuildTarget = Cppia;
	static var scriptsDir = joinPath(librlRoot, "examples", "www", "public", "assets", "scripts", "haxe");
	static var haxeSimpleDir = joinPath(librlRoot, "examples", "haxe-simple");
	static var srcDir = joinPath(projectRoot, "src");
	static var bindingsDir = joinPath(librlRoot, "bindings", "haxe");

	static var debugArgs = [
		"--debug", 
		"--dce", "no",
		"-lib",  "hxcpp-debug-server"
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
		if (verbosity == Verbosity.Verbose || verbosity == Verbosity.Quiet) {
			Sys.print("\x1b[90m" + "> " + msg + "\x1b[0m\n");
		}
	}

	static function debug(msg:String):Void {
		if (verbosity == Verbosity.Verbose) {
			Sys.print("\x1b[90m" + "> " + msg + "\x1b[0m\n");
		}
	}

	static function warn(msg:String):Void {
		if (verbosity == Verbosity.Verbose || verbosity == Verbosity.Quiet) {
			Sys.print("\x1b[33m" + "> " + msg + "\x1b[0m\n");
		}
	}

	static function error(msg:String):Void {
		Sys.print("\x1b[31m" + "> " + msg + "\x1b[0m\n");
	}

	static function success(msg:String):Void {
		if (verbosity == Verbosity.Verbose || verbosity == Verbosity.Quiet) {
			Sys.print("\x1b[32m" + "> " + msg + "\x1b[0m\n");
		}
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
		Sys.println("usage: haxe [-cp tools] --run CompileScript [--debug] [--js] <class-name>");
	}

	static function resolveBuildTarget():BuildTarget {
		if (Sys.getEnv("COMPILE_SCRIPT_JS") == "1") {
			return Js;
		}
		return sysArgs.contains("--js") ? Js : Cppia;
	}

	static function stripJsFlag(args:Array<String>):Void {
		var index = args.indexOf("--js");
		if (index >= 0) {
			args.splice(index, 1);
		}
	}

	static function hasDebugFlag(args:Array<String>):Bool {
		return args.contains("--debug") || args.contains("-D") && args.contains("debug");
	}

	static function classNameToBasePath(className:String):String {
		var normalized = StringTools.replace(className, ".", "/");
		return joinPath(scriptsDir, normalized);
	}

	static function classNameToPath(className:String):String {
		return classNameToBasePath(className) + ".cppia";
	}

	static function classNameToJsPath(className:String):String {
		return classNameToBasePath(className) + ".js";
	}

	static function jsBuildArgs():Array<String> {
		return [
			"-cp", haxeSimpleDir,
			"-D", "js-es=6",
			"-D", "source-map",
			"-D", "source-map-content",
			"-lib", "hxasync",
			"--macro", "macros.MakeESM.capturePreAsyncOutput()",
			"--macro", 'hxasync.AsyncMacro.makeAsyncable("")',
			"--macro", "macros.MakeESM.apply()",
		];
	}

	static function finalizeJsOutput(jsPath:String):Void {
		var content = sys.io.File.getContent(jsPath);
		// hxasync leaves bare placeholders for Void async bodies; fixJSOutput only strips `return` forms.
		content = StringTools.replace(content, "%noReturnPlaceholder%;", "");
		content = StringTools.replace(content, "return %noReturnPlaceholder%;", "");
		content = StringTools.replace(content, "%asyncPlaceholder%", "async ");
		sys.io.File.saveContent(jsPath, content);
	}

	static function buildJs(?additionalArgs:Array<String>):Int {
		var jsPath = classNameToJsPath(scriptClassName);
		info("Building script JS "
			+ (buildMode == Debug ? "debug" : "release")
			+ " '"
			+ jsPath
			+ "'...");
		var args = [];
		if (additionalArgs != null)
			args = args.concat(additionalArgs);
		if (commonArgs != null)
			args = args.concat(commonArgs);
		args = args.concat(buildModeArgs());
		args = args.concat(jsBuildArgs());
		args = args.concat(["--macro", 'macros.ClassValidator.validateExtends("${scriptClassName}", "Script")']);
		args = args.concat(["-js", jsPath]);
		args.push(scriptClassName);
		var code = runHaxe(args);
		//if (code == 0)
		//	finalizeJsOutput(jsPath);
		return code;
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
		debug("thisDir: " + thisDir);
		debug("projectRoot: " + projectRoot);
		debug("librlRoot: " + librlRoot);
		debug("wgutilsRoot: " + wgutilsRoot);
		debug("srcDir: " + srcDir);
		debug("bindingsDir: " + bindingsDir);
		debug("scriptsDir: " + scriptsDir);
		debug("exportClassesInfo: " + exportClassesInfo);
		debug("commonArgs: " + commonArgs);
		*/

		debug(sysArgs.join(" "));
		var errorCode = 0;
		var buildStartTime:Float = 0;
		var buildEndTime:Float = 0;

		// set verbosity if it was provided as a sys arg
		// TODO: add a helper to get the verbosity level from the args


		// if "--debug" was provided as an argument, set the buildMode
		// note that we don't set buildMode to release in an else clause, allowing --debug to be an override of the default
		if (hasDebugFlag(sysArgs)) {
			buildMode = Debug;
			warn("CPPIA debug builds embed hxcpp-debug-server (default ws://127.0.0.1:6972). "
				+ "In wasm the connection is made from the browser, so 127.0.0.1 is the machine running the tab "
				+ "(debug server or reverse tunnel must be reachable there).");
		}

		buildTarget = resolveBuildTarget();
		if (buildTarget == Js) {
			stripJsFlag(sysArgs);
		}

		if (scriptClassName == null || scriptClassName == "--js") {
			error("No script class name provided");
			showUsage();
			Sys.exit(1);
		}

        sysArgs.pop();
        buildStartTime = Timer.stamp();
		errorCode = switch buildTarget {
			case Js: buildJs(sysArgs);
			case Cppia: buildCppia(sysArgs);
		};
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
