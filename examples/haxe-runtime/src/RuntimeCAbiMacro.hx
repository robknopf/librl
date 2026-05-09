package;

#if macro
import StringTools;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

private enum ExportWrapKind {
	Thin;
	Init;
	Deinit;
}

/**
	Generates stable `extern "C"` runtime ABI wrappers for hxcpp runtimes.

	Static methods marked with `@:exportc*` are emitted into `@:cppFileCode`:
	- `@:exportc("symbol")` emits a thin wrapper.
	- `@:exportc.init("symbol")` emits hxcpp boot glue before calling the method.
	- `@:exportc.deinit("symbol")` calls the method, then hxcpp finalizer glue.

	Wire with:
	`--macro RuntimeCAbiMacro.registerGlobal()`
**/
class RuntimeCAbiMacro {
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
			case TAbstract(_.toString() => n, _):
				switch (n) {
					case "Int": "int";
					case "Float": "float";
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
			if (m.name != metaName || m.params.length < 1) {
				continue;
			}
			switch (m.params[0].expr) {
				case EConst(CString(s)): return s;
				default:
			}
		}
		return null;
	}

	static function exportWrapKind(field:ClassField):Null<ExportWrapKind> {
		var init = field.meta.has(":exportc.init");
		var deinit = field.meta.has(":exportc.deinit");
		if (init && deinit) {
			Context.warning('use only one of @:exportc.init / @:exportc.deinit (${field.name}); skipping', field.pos);
			return null;
		}
		if (init) {
			return Init;
		}
		if (deinit) {
			return Deinit;
		}
		if (field.meta.has(":exportc")) {
			return Thin;
		}
		return null;
	}

	static function exportSymbolName(field:ClassField, kind:ExportWrapKind):String {
		switch (kind) {
			case Init:
				var s = metaCString(field, ":exportc.init");
				if (s != null) {
					return s;
				}
			case Deinit:
				var s = metaCString(field, ":exportc.deinit");
				if (s != null) {
					return s;
				}
			case Thin:
		}
		var fromExportc = metaCString(field, ":exportc");
		if (fromExportc != null) {
			return fromExportc;
		}
		return field.name;
	}

	static function collectInitDeinit(types:Array<Type>):{
		inits:Array<{field:ClassField, pos:Position}>,
		deinits:Array<{field:ClassField, pos:Position}>
	} {
		var inits:Array<{field:ClassField, pos:Position}> = [];
		var deinits:Array<{field:ClassField, pos:Position}> = [];
		for (type in types) {
			switch (type) {
				case TInst(_.get() => cls, _):
					for (field in cls.statics.get()) {
						switch (exportWrapKind(field)) {
							case Init:
								inits.push({field: field, pos: field.pos});
							case Deinit:
								deinits.push({field: field, pos: field.pos});
							default:
						}
					}
				default:
			}
		}
		return {inits: inits, deinits: deinits};
	}

	static function validateSingleInitDeinit(inits:Array<{field:ClassField, pos:Position}>,
			deinits:Array<{field:ClassField, pos:Position}>):Void {
		if (inits.length > 1) {
			for (i in 1...inits.length) {
				Context.error("Only one @:exportc.init allowed.", inits[i].pos);
			}
		}
		if (deinits.length > 1) {
			for (i in 1...deinits.length) {
				Context.error("Only one @:exportc.deinit allowed.", deinits[i].pos);
			}
		}
	}

	static function compilationUsesMainEntry():Bool {
		var cfg = Compiler.getConfiguration();
		return cfg != null && Reflect.field(cfg, "mainClass") != null;
	}

	public static function registerGlobal():Void {
		Context.onGenerate(function(types) {
			var id = collectInitDeinit(types);
			validateSingleInitDeinit(id.inits, id.deinits);
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

	static function mergeCppFileCode(cls:haxe.macro.Type.ClassType, fragment:String, pos:Position):Void {
		var parts:Array<String> = [];
		for (m in cls.meta.get()) {
			if (m.name != ":cppFileCode") {
				continue;
			}
			for (p in m.params) {
				switch (p.expr) {
					case EConst(CString(s)): parts.push(s);
					default:
				}
			}
		}
		while (cls.meta.has(":cppFileCode")) {
			cls.meta.remove(":cppFileCode");
		}
		var merged = parts.join("\n");
		if (merged.length > 0 && fragment.length > 0) {
			merged += "\n";
		}
		merged += fragment;
		cls.meta.add(":cppFileCode", [{expr: EConst(CString(merged)), pos: pos}], pos);
	}

	static function processField(field:ClassField, cls:haxe.macro.Type.ClassType, isStatic:Bool, exports:Array<String>,
			callHxcppMain:Bool, hadInit:{had:Bool}) {
		var kind = exportWrapKind(field);
		if (kind == null) {
			return;
		}
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
						returnType == "void" ? '${callExpr};\n    return;' : 'return ${callExpr};';
					case Init:
						hadInit.had = true;
						var tail = returnType == "void" ? '${callExpr};\n    return;' : 'return ${callExpr};';
						var afterBoot = 'hxcpp_set_top_of_stack();\n'
							+ '    HX_TOP_OF_STACK\n'
							+ '    ::hx::Boot();\n'
							+ '    __boot_all();\n'
							+ '    ${fullCppClass}::__register();\n';
						if (callHxcppMain) {
							afterBoot += '    __hxcpp_main();\n';
						}
						afterBoot + "    " + tail;
					case Deinit:
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
		var hadInit = {had: false};

		for (field in cls.statics.get()) {
			processField(field, cls, true, exports, callHxcppMain, hadInit);
		}
		for (field in cls.fields.get()) {
			processField(field, cls, false, exports, callHxcppMain, hadInit);
		}

		if (exports.length > 0) {
			var preamble = PREAMBLE_BASE;
			if (callHxcppMain && hadInit.had) {
				preamble += PREAMBLE_HXCPP_MAIN_DECL;
			}
			mergeCppFileCode(cls, preamble + exports.join("\n"), cls.pos);
		}
	}
}
#end
