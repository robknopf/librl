## Nim JS → ESM bridge (`exportjs` + `emitEsmExports`).
##
## **`exportc`** (built-in): C / wasm linker symbol. Implicit → proc name; explicit → your string.
## Toolchains may transform it further; this module does not.
##
## **`exportjs`** (macro): JS global name + ESM footer entry. On the **JS** backend only it:
##   - sets `{.exportc: <js name>.}` for the JS codegen (replaces any prior `exportc` on that proc)
##   - adds `{.used.}`
##   - registers `<js name>` for `emitEsmExports()`
##
## On **non-JS** backends, `exportjs` is a no-op (pragma stripped; your `exportc` / `cdecl` / `dynlib` unchanged).
##
## Name resolution for the JS public symbol:
##   - `{.exportjs("sym").}` — macro-pragma **call** syntax (see Nim user-defined pragmas)
##   - `{.exportjs.}` — uses `{.exportc: "sym".}` on the same proc if present, else proc name
##
## Different C vs JS names (e.g. wasm `rt_init` vs host `_rt_init`):
##
##   when defined(js):
##     proc rt_init*(): cint {.exportjs("_rt_init").} = ...
##   else:
##     proc rt_init*(): cint {.exportc: "rt_init", cdecl, dynlib.} = ...
##
## Same name on JS:
##
##   proc rt_boot*(): cint {.exportc: "rt_boot", exportjs.} = ...
##
## Batch: `esmExports:` wraps `*` routines (same rules per proc) + footer.
##
## Call `emitEsmExports()` after all `{.exportjs.}` / `{.exportjs("sym").}` procs are defined;
## the ESM footer uses the compile-time registry only (no source scanning).

import std/[macros, strutils]

type JsExportEntry = object
  nimName: string
  jsName: string

var jsExportRegistry {.compileTime.}: seq[JsExportEntry]

proc registerJsExport(nimName, jsName: string) {.compileTime.} =
  for e in jsExportRegistry:
    if e.jsName == jsName:
      error "duplicate JS export: " & jsName
  jsExportRegistry.add JsExportEntry(nimName: nimName, jsName: jsName)

func routineBaseName(n: NimNode): string =
  if n.kind == nnkPostfix and n[0].eqIdent("*") and n[1].kind == nnkIdent:
    n[1].strVal
  elif n.kind == nnkIdent:
    n.strVal
  else:
    ""

func isStarExportRoutine(s: NimNode): bool =
  s.kind in {nnkProcDef, nnkFuncDef, nnkMethodDef} and
    s[0].kind == nnkPostfix and s[0][0].eqIdent("*") and s[0][1].kind == nnkIdent

func isExportJsPragma(p: NimNode): bool =
  p == ident"exportjs" or p == ident"esmexport" or p == ident"jsexport"

func exportcName(s: NimNode; defaultName: string): string =
  if s.len > 4 and s[4].kind == nnkPragma:
    for p in s[4]:
      if p == ident"exportc":
        return defaultName
      if p.kind == nnkExprColonExpr and p[0] == ident"exportc" and p[1].kind == nnkStrLit:
        return p[1].strVal
  defaultName

func resolveJsExportName(s: NimNode; exportJsOverride: string = ""): string =
  let nimName = routineBaseName(s[0])
  if exportJsOverride.len > 0:
    exportJsOverride
  else:
    exportcName(s, nimName)

proc stripExportJsPragmas*(s: NimNode): NimNode =
  result = copyNimTree(s)
  if result.len <= 4 or result[4].isNil or result[4].kind notin {nnkPragma, nnkEmpty}:
    return
  var kept = newNimNode(nnkPragma)
  for p in result[4]:
    if isExportJsPragma(p):
      continue
    if p.kind == nnkExprColonExpr and p[0] == ident"exportjs":
      continue
    kept.add p
  result[4] = kept

proc patchJsExport*(s: NimNode; exportJsOverride: string = ""): NimNode {.compileTime.} =
  let nimName = routineBaseName(s[0])
  if nimName.len == 0:
    error "exportjs: expected a named routine", s
  let jsName = resolveJsExportName(s, exportJsOverride)
  registerJsExport(nimName, jsName)
  result = stripExportJsPragmas(s)
  var kept = newNimNode(nnkPragma)
  if result[4].isNil or result[4].kind == nnkEmpty:
    discard
  elif result[4].kind == nnkPragma:
    for p in result[4]:
      if p == ident"exportc":
        continue
      if p.kind == nnkExprColonExpr and p[0] == ident"exportc":
        continue
      kept.add p
  result[4] = kept
  kept.add newTree(nnkExprColonExpr, ident"exportc", newLit(jsName))
  kept.add ident"used"
  result[4] = kept

proc emitFooter(entries: seq[JsExportEntry]): NimNode =
  if entries.len == 0:
    newEmptyNode()
  else:
    var names: seq[string] = @[]
    for e in entries:
      names.add e.jsName
    let exportLine = "export { " & names.join(", ") & " };\n"
    quote do:
      {.emit: `exportLine`.}

macro exportjs*(fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, "")
  else:
    result = stripExportJsPragmas(fn)

macro exportjs*(jsName: static[string], fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, jsName)
  else:
    result = stripExportJsPragmas(fn)

macro esmexport*(fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, "")
  else:
    result = stripExportJsPragmas(fn)

macro esmexport*(jsName: static[string], fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, jsName)
  else:
    result = stripExportJsPragmas(fn)

macro jsexport*(fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, "")
  else:
    result = stripExportJsPragmas(fn)

macro jsexport*(jsName: static[string], fn: untyped): untyped =
  if defined(js):
    result = patchJsExport(fn, jsName)
  else:
    result = stripExportJsPragmas(fn)

macro esmExports*(body: untyped): untyped =
  result = newStmtList()
  for s in body:
    if isStarExportRoutine(s):
      if defined(js):
        result.add patchJsExport(s, "")
      else:
        result.add stripExportJsPragmas(s)
    else:
      result.add s
  if defined(js):
    result.add emitFooter(jsExportRegistry)

macro emitEsmExports*(): untyped =
  if not defined(js):
    result = newEmptyNode()
  else:
    result = emitFooter(jsExportRegistry)

macro emitEsmDefaultExport*(exportVar: static[string] = "__nimJsExports"): untyped =
  if not defined(js):
    result = newEmptyNode()
  else:
    let entries = jsExportRegistry
    if entries.len == 0:
      result = newEmptyNode()
    else:
      var names: seq[string] = @[]
      for e in entries:
        names.add e.jsName
      let namesCsv = names.join(", ")
      let js = "const " & exportVar & " = { " & namesCsv & " };\n" &
        "export default " & exportVar & ";\n" &
        "export { " & namesCsv & " };\n"
      result = quote do:
        {.emit: `js`.}
