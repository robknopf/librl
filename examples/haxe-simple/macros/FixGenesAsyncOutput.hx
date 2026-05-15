package macros;

#if macro
import haxe.Json;
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

private typedef MappingSegment = {
	var line:Int;
	var generatedColumn:Int;
	@:optional var source:Int;
	@:optional var originalLine:Int;
	@:optional var originalColumn:Int;
	@:optional var name:Int;
}

/**
 * hxasync only post-processes `Compiler.getOutput()`, which works for the
 * default single-file JS emitter but misses split-output generators like genes.
 *
 * This macro walks the generated output directory and applies hxasync's JS fixup
 * to every emitted `.js` module so `%asyncPlaceholder%` markers are resolved.
 */
class FixGenesAsyncOutput {
	static final BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	static function visitJsFiles(dir:String, callback:String->Void):Void {
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) {
			return;
		}
		for (entry in FileSystem.readDirectory(dir)) {
			var path = Path.join([dir, entry]);
			if (FileSystem.isDirectory(path)) {
				visitJsFiles(path, callback);
			} else if (Path.extension(path).toLowerCase() == "js") {
				callback(path);
			}
		}
	}

	static function getDeletedGeneratedLines(source:String):Array<Int> {
		var lines = source.split("\n");
		var deleted = [];
		for (i in 0...lines.length) {
			var line = lines[i];
			if (line.indexOf(hxasync.AsyncMacro.asyncPlaceholder) >= 0 || line.indexOf(hxasync.AsyncMacro.noReturnPlaceholder) >= 0) {
				deleted.push(i + 1);
			}
		}
		return deleted;
	}

	static function fromBase64Char(charCode:Int):Int {
		return switch charCode {
			case code if (code >= "A".code && code <= "Z".code): code - "A".code;
			case code if (code >= "a".code && code <= "z".code): code - "a".code + 26;
			case code if (code >= "0".code && code <= "9".code): code - "0".code + 52;
			case "+".code: 62;
			case "/".code: 63;
			default: throw "Invalid base64 VLQ character";
		}
	}

	static function decodeVlq(segment:String, indexRef:{ var value:Int; }):Int {
		var shift = 0;
		var value = 0;
		while (true) {
			var digit = fromBase64Char(segment.charCodeAt(indexRef.value++));
			var continuation = (digit & 32) != 0;
			digit &= 31;
			value += digit << shift;
			shift += 5;
			if (!continuation) {
				break;
			}
		}
		var decoded = value >> 1;
		return (value & 1) == 1 ? -decoded : decoded;
	}

	static function encodeVlq(value:Int):String {
		var vlq = value < 0 ? ((-value) << 1) + 1 : (value << 1);
		var out = new StringBuf();
		do {
			var digit = vlq & 31;
			vlq >>= 5;
			if (vlq > 0) {
				digit |= 32;
			}
			out.add(BASE64_CHARS.charAt(digit));
		} while (vlq > 0);
		return out.toString();
	}

	static function decodeMappings(mappings:String):Array<MappingSegment> {
		var result = [];
		var lines = mappings.split(";");
		var previousSource = 0;
		var previousOriginalLine = 0;
		var previousOriginalColumn = 0;
		var previousName = 0;
		for (lineIndex in 0...lines.length) {
			var line = lines[lineIndex];
			var generatedColumn = 0;
			if (line == "") {
				continue;
			}
			for (segment in line.split(",")) {
				if (segment == "") {
					continue;
				}
				var indexRef = { value: 0 };
				generatedColumn += decodeVlq(segment, indexRef);
				var mapped:MappingSegment = {
					line: lineIndex + 1,
					generatedColumn: generatedColumn
				};
				if (indexRef.value < segment.length) {
					previousSource += decodeVlq(segment, indexRef);
					previousOriginalLine += decodeVlq(segment, indexRef);
					previousOriginalColumn += decodeVlq(segment, indexRef);
					mapped.source = previousSource;
					mapped.originalLine = previousOriginalLine;
					mapped.originalColumn = previousOriginalColumn;
					if (indexRef.value < segment.length) {
						previousName += decodeVlq(segment, indexRef);
						mapped.name = previousName;
					}
				}
				result.push(mapped);
			}
		}
		return result;
	}

	static function encodeMappings(segments:Array<MappingSegment>):String {
		if (segments.length == 0) {
			return "";
		}

		var perLine = new Map<Int, Array<MappingSegment>>();
		var maxLine = 0;
		for (segment in segments) {
			var lineSegments = perLine.get(segment.line);
			if (lineSegments == null) {
				lineSegments = [];
				perLine.set(segment.line, lineSegments);
			}
			lineSegments.push(segment);
			if (segment.line > maxLine) {
				maxLine = segment.line;
			}
		}

		var lines = [];
		var previousSource = 0;
		var previousOriginalLine = 0;
		var previousOriginalColumn = 0;
		var previousName = 0;
		for (lineNumber in 1...maxLine + 1) {
			var lineSegments = perLine.get(lineNumber);
			if (lineSegments == null || lineSegments.length == 0) {
				lines.push("");
				continue;
			}
			var generatedColumn = 0;
			var encodedSegments = [];
			for (segment in lineSegments) {
				var encoded = new StringBuf();
				encoded.add(encodeVlq(segment.generatedColumn - generatedColumn));
				generatedColumn = segment.generatedColumn;
				if (segment.source != null && segment.originalLine != null && segment.originalColumn != null) {
					encoded.add(encodeVlq(segment.source - previousSource));
					encoded.add(encodeVlq(segment.originalLine - previousOriginalLine));
					encoded.add(encodeVlq(segment.originalColumn - previousOriginalColumn));
					previousSource = segment.source;
					previousOriginalLine = segment.originalLine;
					previousOriginalColumn = segment.originalColumn;
					if (segment.name != null) {
						encoded.add(encodeVlq(segment.name - previousName));
						previousName = segment.name;
					}
				}
				encodedSegments.push(encoded.toString());
			}
			lines.push(encodedSegments.join(","));
		}
		return lines.join(";");
	}

	static function rewriteSourceMap(mapPath:String, deletedLines:Array<Int>):Void {
		if (!FileSystem.exists(mapPath) || deletedLines.length == 0) {
			return;
		}

		var map:Dynamic = Json.parse(File.getContent(mapPath));
		var deletedLookup = new Map<Int, Bool>();
		for (line in deletedLines) {
			deletedLookup.set(line, true);
		}

		var deletedBefore = 0;
		var nextDeletedIndex = 0;
		var sortedDeleted = deletedLines.copy();
		sortedDeleted.sort((a, b) -> a - b);

		var rewritten = [];
		for (segment in decodeMappings(map.mappings)) {
			if (deletedLookup.exists(segment.line)) {
				continue;
			}
			while (nextDeletedIndex < sortedDeleted.length && sortedDeleted[nextDeletedIndex] < segment.line) {
				deletedBefore++;
				nextDeletedIndex++;
			}
			rewritten.push({
				line: segment.line - deletedBefore,
				generatedColumn: segment.generatedColumn,
				source: segment.source,
				originalLine: segment.originalLine,
				originalColumn: segment.originalColumn,
				name: segment.name
			});
		}

		map.mappings = encodeMappings(rewritten);
		File.saveContent(mapPath, Json.stringify(map));
	}

	public static macro function apply() {
		if (Context.defined("js")) {
			Context.onAfterGenerate(() -> {
				var outputFile = Compiler.getOutput();
				var outputDir = Path.directory(outputFile);
				visitJsFiles(outputDir, (path) -> {
					var source = File.getContent(path);
					var deletedLines = getDeletedGeneratedLines(source);
					var fixed = hxasync.AsyncMacro.fixJSOutput(source);
					if (fixed != source) {
						File.saveContent(path, fixed);
						rewriteSourceMap(path + ".map", deletedLines);
					}
				});
			});
		}

		return macro null;
	}
}
#end
