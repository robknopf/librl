package macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Compiler;

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
	public static macro function apply() {
		if (Context.defined("js")) {
			Context.onAfterGenerate(() -> {
				var outFile = Compiler.getOutput();
				var output = sys.io.File.getContent(outFile);

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
			});
		}

		return {expr: EConst(CString("", SingleQuotes)), pos: Context.makePosition({file: '', min: 0, max: 0})};
	}
}
#end
