package macros;

#if macro
import haxe.Json;
import haxe.crypto.Md5;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Compiler;

private typedef MappingSegment = {
	var line:Int;
	var generatedColumn:Int;
	@:optional var source:Int;
	@:optional var originalLine:Int;
	@:optional var originalColumn:Int;
	@:optional var name:Int;
}

private typedef LineColumn = {
	var line:Int;
	var column:Int;
}

/**
 * Rewrites the Haxe-emitted JS bundle toward an ESM shape (`export default exports`).
 *
 * **Source maps:** Haxe writes the `.map` for the pre-transform output. This macro does not
 * patch the map; doing that correctly requires a VLQ-aware merge (e.g. `source-map` on Node),
 * not `;`-row surgery. The header/footer rewrites are kept on a single line each (no extra
 * `\\n` before the bundle body) so emitted **line numbers** stay aligned with the original
 * output after the first line / last line. Use `debugger;` or a build without this step if
 * you still need exact DevTools alignment.
 */
class MakeESM {
	static final BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	static function snapshotPath(outFile:String):String {
		return "/tmp/librl-makeesm-" + Md5.encode(outFile) + ".preasync.js";
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

	static function offsetToLineColumn(content:String, offset:Int):LineColumn {
		var line = 1;
		var column = 0;
		for (i in 0...offset) {
			if (content.charCodeAt(i) == "\n".code) {
				line++;
				column = 0;
			} else {
				column++;
			}
		}
		return { line: line, column: column };
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

	static function rewriteSourceMap(mapPath:String, headerPos:LineColumn, headerDelta:Int, footerPos:LineColumn, footerDelta:Int):Void {
		if (!sys.FileSystem.exists(mapPath)) {
			return;
		}
		var map:Dynamic = Json.parse(sys.io.File.getContent(mapPath));
		var rewritten = [];
		for (segment in decodeMappings(map.mappings)) {
			var generatedColumn = segment.generatedColumn;
			if (headerDelta != 0 && segment.line == headerPos.line && generatedColumn >= headerPos.column) {
				generatedColumn += headerDelta;
			}
			if (footerDelta != 0 && segment.line == footerPos.line && generatedColumn >= footerPos.column) {
				generatedColumn += footerDelta;
				if (generatedColumn < 0) {
					generatedColumn = 0;
				}
			}
			rewritten.push({
				line: segment.line,
				generatedColumn: generatedColumn,
				source: segment.source,
				originalLine: segment.originalLine,
				originalColumn: segment.originalColumn,
				name: segment.name
			});
		}
		map.mappings = encodeMappings(rewritten);
		sys.io.File.saveContent(mapPath, Json.stringify(map));
	}

	static function rewriteSourceMapForDeletedLines(mapPath:String, deletedLines:Array<Int>):Void {
		if (!sys.FileSystem.exists(mapPath) || deletedLines.length == 0) {
			return;
		}
		var map:Dynamic = Json.parse(sys.io.File.getContent(mapPath));
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
		sys.io.File.saveContent(mapPath, Json.stringify(map));
	}

	public static macro function capturePreAsyncOutput() {
		if (Context.defined("js")) {
			Context.onAfterGenerate(() -> {
				var outFile = Compiler.getOutput();
				sys.io.File.saveContent(snapshotPath(outFile), sys.io.File.getContent(outFile));
			});
		}
		return {expr: EConst(CString("", SingleQuotes)), pos: Context.makePosition({file: '', min: 0, max: 0})};
	}

	public static macro function apply() {
		if (Context.defined("js")) {
			Context.onAfterGenerate(() -> {
				var outFile = Compiler.getOutput();
				var output = sys.io.File.getContent(outFile);
				var originalOutput = output;
				var preAsyncPath = snapshotPath(outFile);
				var deletedLines = [];
				if (sys.FileSystem.exists(preAsyncPath)) {
					originalOutput = sys.io.File.getContent(preAsyncPath);
					deletedLines = getDeletedGeneratedLines(originalOutput);
				}
				var currentOutput = output;

				var header = "(function ($hx_exports, $global) { \"use strict\";";
				// Same line as original opening so following lines keep the same line numbers vs .map
				var headerNew = 'var exports = {};' + header;
				var headerStart = output.indexOf(header);
				if (headerStart == -1)
					trace("ERROR: Can't generate esm because header string is not found");
				else
					output = output.substring(0, headerStart) + headerNew + output.substring(headerStart + header.length);

				// One line so we do not add a line before EOF vs the pre-transform bundle
				var footerNew = '})(exports); export default exports;';
				var footerVariants = [
					"})(typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this, {});",
					"})(typeof exports != \"undefined\" ? exports : typeof window != \"undefined\" ? window : typeof self != \"undefined\" ? self : this, typeof window != \"undefined\" ? window : typeof global != \"undefined\" ? global : typeof self != \"undefined\" ? self : this);"
				];
				var footerStart = -1;
				var footerLen = 0;
				for (footer in footerVariants) {
					var idx = output.lastIndexOf(footer);
					if (idx != -1) {
						footerStart = idx;
						footerLen = footer.length;
						break;
					}
				}
				if (footerStart == -1)
					trace("ERROR: Can't generate esm because footer string is not found");
				else
					output = output.substring(0, footerStart) + footerNew + output.substring(footerStart + footerLen);

				sys.io.File.saveContent(outFile, output);
				if (headerStart != -1 && footerStart != -1) {
					if (deletedLines.length > 0) {
						rewriteSourceMapForDeletedLines(outFile + ".map", deletedLines);
					}
					rewriteSourceMap(
						outFile + ".map",
						offsetToLineColumn(currentOutput, headerStart),
						headerNew.length - header.length,
						offsetToLineColumn(currentOutput, footerStart),
						footerNew.length - footerLen
					);
				}
				if (sys.FileSystem.exists(preAsyncPath)) {
					sys.FileSystem.deleteFile(preAsyncPath);
				}
			});
		}

		return {expr: EConst(CString("", SingleQuotes)), pos: Context.makePosition({file: '', min: 0, max: 0})};
	}
}
#end
