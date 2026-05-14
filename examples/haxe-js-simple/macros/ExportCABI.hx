package macros;

#if macro
import StringTools;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

private enum ExportWrapKind {
	Thin;
	Entry;
	Exit;
}

/**
 * Static `@:exportc*` methods → thin `extern "C"` trampolines in `:cppFileCode`
 * (wasm `EXPORTED_FUNCTIONS` + desktop shared libs).
 *
 * - **`@:exportc`** — forward only (optional **`@:exportc("c_symbol")`**).
 * - **`@:exportc.init`** — **`hxcpp_set_top_of_stack`**, **`HX_TOP_OF_STACK`**, **`::hx::Boot()`**, **`__boot_all()`**,
 *   **`Class_obj::__register()`**, then your method. C symbol: **`@:exportc.entry("sym")`**, else **`@:exportc("sym")`** if also present, else field name.
 * - **`@:exportc.exit`** — call your method, then **`::hx::finalizer()`** (handles non-void return); same symbol rules as init.
 *
 * At most **one** **`@:exportc.entry`** and at most **one** **`@:exportc.exit`** may appear in the whole compilation (duplicate extras → **`Context.error`**).
 * Use **`@:exportc`** for additional C ABIs without bootstrap/finalizer glue.
 *
 * **`__hxcpp_main()`** is injected after **`__boot_all()`** only when **`Compiler.getConfiguration().mainClass`** is set (same condition as **`-main`** on the CLI), so hxcpp’s generated **`__hxcpp_main()` → Main_obj::main()`** exists.
 *
 * Do not combine **`@:exportc.entry`** with **`@:exportc.exit`**. You may use **`@:exportc("sym")`** together with **entry/exit** only to supply the C symbol (no thin **`@:exportc`** wrapper). Instance methods are skipped with a warning.
 *
 * Wire: `--macro ExportCABI.apply()`
 */
class ExportCABI {
	static final PREAMBLE_BASE = '
#ifdef __EMSCRIPTEN__
#include <emscripten/emscripten.h>
#define RUNTIME_C_ABI_EXPORT EMSCRIPTEN_KEEPALIVE
#else
#define RUNTIME_C_ABI_EXPORT extern "C" HXCPP_EXTERN_CLASS_ATTRIBUTES
#endif

extern "C" void hxcpp_set_top_of_stack();

';

	static final PREAMBLE_HXCPP_MAIN_DECL = 'extern "C" void __hxcpp_main();

';

	private static function typeToC(t:Type):String {
		return switch (Context.follow(t)) {
			case TAbstract(_.toString() => n, params):
				switch (n) {
					case "Int": "int";
					case "Float": "double";
					case "Bool": "bool";
					case "Void": "void";
					default:
						if (n == "cpp.Void") {
							"void";
						} else if (StringTools.startsWith(n, "cpp.RawPointer")) {
							"void*";
						} else if (StringTools.startsWith(n, "cpp.ConstCharStar")) {
							"const char*";
						} else {
							"void*";
						}
				}
			case TInst(_.toString() => n, _):
				switch (n) {
					case "String": "const char*";
					default: "void*";
				}
			default:
				"void*";
		};
	}

	static function metaCString(field:ClassField, metaName:String):Null<String> {
		for (m in field.meta.get()) {
			if (m.name != metaName || m.params.length < 1)
				continue;
			switch (m.params[0].expr) {
				case EConst(CString(s)): return s;
				default:
			}
		}
		return null;
	}

	static function exportWrapKind(field:ClassField):Null<ExportWrapKind> {
		var entry = field.meta.has(":exportc.entry");
		var exit = field.meta.has(":exportc.exit");
		if (entry && exit) {
			Context.warning('use only one of @:exportc.entry / @:exportc.exit (${field.name}); skipping', field.pos);
			return null;
		}
		if (entry)
			return Entry;
		if (exit)
			return Exit;
		if (field.meta.has(":exportc"))
			return Thin;
		return null;
	}

	static function exportSymbolName(field:ClassField, kind:ExportWrapKind):String {
		switch (kind) {
			case Entry:
				var s = metaCString(field, ":exportc.entry");
				if (s != null)
					return s;
			case Exit:
				var s = metaCString(field, ":exportc.exit");
				if (s != null)
					return s;
			case Thin:
		}
		var fromExportc = metaCString(field, ":exportc");
		if (fromExportc != null)
			return fromExportc;
		return field.name;
	}

	private static function collectEntryExit(types:Array<Type>):{entries:Array<{field:ClassField, pos:haxe.macro.Expr.Position}>, exits:Array<{field:ClassField, pos:haxe.macro.Expr.Position}>} {
		var entries:Array<{field:ClassField, pos:haxe.macro.Expr.Position}> = [];
		var exits:Array<{field:ClassField, pos:haxe.macro.Expr.Position}> = [];
		for (type in types) {
			switch (type) {
				case TInst(_.get() => cls, _):
					for (field in cls.statics.get()) {
						switch (exportWrapKind(field)) {
							case Entry:
								entries.push({field: field, pos: field.pos});
							case Exit:
								exits.push({field: field, pos: field.pos});
							default:
						}
					}
				default:
			}
		}
		return {entries: entries, exits: exits};
	}

	private static function validateSingleEntryExit(entries:Array<{field:ClassField, pos:haxe.macro.Expr.Position}>,
			exits:Array<{field:ClassField, pos:haxe.macro.Expr.Position}>):Void {
		if (entries.length > 1) {
			for (i in 1...entries.length) {
				Context.error(
					'Only one @:exportc.entry allowed (found ${entries.length}). '
					+ 'Use @:exportc for extra C exports without Boot/__boot_all/__hxcpp_main glue.',
					entries[i].pos
				);
			}
		}
		if (exits.length > 1) {
			for (i in 1...exits.length) {
				Context.error(
					'Only one @:exportc.exit allowed (found ${exits.length}). '
					+ 'Use @:exportc for extra C exports without ::hx::finalizer() glue.',
					exits[i].pos
				);
			}
		}
	}

	/** True when compilation used **`-main`** (see **`CompilerConfiguration.mainClass`**). `Compiler.getMainClass()` does not exist on Haxe 4.x std API. */
	static function compilationUsesMainEntry():Bool {
		var cfg = Compiler.getConfiguration();
		if (cfg == null)
			return false;
		return Reflect.field(cfg, "mainClass") != null;
	}

	public static function apply():Void {
		Context.onGenerate(function(types) {
			var id = collectEntryExit(types);
			validateSingleEntryExit(id.entries, id.exits);
			var callHxcppMain = compilationUsesMainEntry();

			for (type in types) {
				switch (type) {
					case TInst(_.get() => cls, _):
						processClass(cls, callHxcppMain);
					default:
				}
			}
		});
	}

	static function mergeCppFileCode(cls:haxe.macro.Type.ClassType, fragment:String, pos:haxe.macro.Expr.Position):Void {
		var parts:Array<String> = [];
		for (m in cls.meta.get()) {
			if (m.name != ":cppFileCode")
				continue;
			for (p in m.params)
				switch (p.expr) {
					case EConst(CString(s)): parts.push(s);
					default:
				}
		}
		while (cls.meta.has(":cppFileCode"))
			cls.meta.remove(":cppFileCode");
		var merged = parts.join("\n");
		if (merged.length > 0 && fragment.length > 0)
			merged += "\n";
		merged += fragment;
		cls.meta.add(":cppFileCode", [{expr: EConst(CString(merged)), pos: pos}], pos);
	}

	static function processField(field:ClassField, cls:haxe.macro.Type.ClassType, isStatic:Bool, exports:Array<String>, callHxcppMain:Bool,
			hadInit:{had:Bool}) {
		var kind = exportWrapKind(field);
		if (kind == null)
			return;
		if (!isStatic) {
			Context.warning('@:exportc* on instance methods is not supported (${cls.name}.${field.name}); skipping', field.pos);
			return;
		}
		switch (field.type) {
			case TFun(args, ret):
				var sym = exportSymbolName(field, kind);

				var params = [];
				for (arg in args) {
					params.push('${typeToC(arg.t)} ${arg.name}');
				}
				var paramStr = params.join(", ");
				var argNames = args.map(arg -> arg.name).join(", ");

				var returnType = typeToC(ret);

				var cppNamespace = cls.pack.join("::");
				var cppClassName = cls.name + "_obj";
				var fullCppClass = cppNamespace != "" ? '${cppNamespace}::${cppClassName}' : cppClassName;

				var callExpr = '${fullCppClass}::${field.name}(${argNames})';

				var inner:String = switch (kind) {
					case Thin:
						returnType == "void"
							? '${callExpr};\n    return;'
							: 'return ${callExpr};';
					case Entry:
						hadInit.had = true;
						var tail = returnType == "void"
							? '${callExpr};\n    return;'
							: 'return ${callExpr};';
						var afterBoot = 'hxcpp_set_top_of_stack();\n'
							+ '    HX_TOP_OF_STACK\n'
							+ '    ::hx::Boot();\n'
							+ '    __boot_all();\n'
							+ '    ${fullCppClass}::__register();\n';
						if (callHxcppMain)
							afterBoot += '    __hxcpp_main();\n';
						afterBoot + "    " + tail;
					case Exit:
						if (returnType == "void") {
							'${callExpr};\n'
							+ '    ::hx::finalizer();\n'
							+ '    return;';
						} else {
							'${returnType} _hx_exportc_ret = ${callExpr};\n'
							+ '    ::hx::finalizer();\n'
							+ '    return _hx_exportc_ret;';
						}
				};

				var cppCode = 'extern "C" {
RUNTIME_C_ABI_EXPORT ${returnType} ${sym}(${paramStr}) {
    ${inner}
}
}';
				exports.push(cppCode);

				field.meta.add(":keep", [], field.pos);
			default:
				Context.warning('@:exportc* requires a function (${cls.name}.${field.name})', field.pos);
		}
	}

	static function processClass(cls:haxe.macro.Type.ClassType, callHxcppMain:Bool):Void {
		var exports:Array<String> = [];
		var hadEntry = {had: false};

		for (field in cls.statics.get())
			processField(field, cls, true, exports, callHxcppMain, hadEntry);

		for (field in cls.fields.get())
			processField(field, cls, false, exports, callHxcppMain, hadEntry);

		if (exports.length > 0) {
			var preamble = PREAMBLE_BASE;
			if (callHxcppMain && hadEntry.had)
				preamble += PREAMBLE_HXCPP_MAIN_DECL;
			var body = preamble + exports.join("\n");
			mergeCppFileCode(cls, body, cls.pos);
		}
	}
}
#end
