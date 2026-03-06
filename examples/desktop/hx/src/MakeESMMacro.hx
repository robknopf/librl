
#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Compiler;
#end

class MakeESMMacro {
	public static macro function apply() {
		if (Context.defined("js")) {
			Context.onAfterGenerate(() -> {
				var outFile = Compiler.getOutput();
				var output = sys.io.File.getContent(outFile);

				var header = "(function ($hx_exports, $global) { \"use strict\";";
				var headerNew = 'var exports = {};\n' + header;
				var headerStart = output.indexOf(header);
				if (headerStart == -1)
					trace("ERROR: Can't generate esm because header string is not found");
				else
					output = output.substring(0, headerStart) + headerNew + output.substring(headerStart + header.length);

				var footerNew = '})(exports);\nexport default exports;';
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
				// trace("ESM module rewrite is done.");
			});
		}

		return {expr: EConst(CString("", SingleQuotes)), pos: Context.makePosition({file: '', min: 0, max: 0})};
	}
}
