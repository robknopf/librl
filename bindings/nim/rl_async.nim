import std/macros

proc wrapReturnInFuture(fn: NimNode): NimNode =
  result = fn
  if result.kind notin {nnkProcDef, nnkFuncDef, nnkMethodDef}:
    return
  let retType = result[3][0]
  let alreadyFuture = retType.kind == nnkBracketExpr and
                      retType.len > 0 and
                      retType[0].kind == nnkIdent and
                      retType[0].strVal == "Future"
  let isVoid = retType.kind == nnkEmpty or
               (retType.kind == nnkIdent and retType.strVal == "void")
  if not alreadyFuture and not isVoid:
    result[3][0] = newNimNode(nnkBracketExpr).add(ident"Future", retType)

when defined(js):
  import std/asyncjs
  export asyncjs

  macro rlAsync*(fn: untyped): untyped =
    result = wrapReturnInFuture(fn)
    if result.kind in {nnkProcDef, nnkFuncDef, nnkMethodDef}:
      if result[4].kind == nnkEmpty:
        result[4] = newNimNode(nnkPragma)
      result[4].add(ident"async")

  template rlAwait*[T](f: Future[T]): T = (await f)
  template rlAwaitVoid*(call: untyped) = await call

else:
  ## On native/wasm, Future[T] is a transparent alias for T.
  ## rlAsync wraps the return type in Future[T] (a no-op alias) and rlAwait is identity.
  type Future*[T] = T

  macro rlAsync*(fn: untyped): untyped =
    wrapReturnInFuture(fn)

  template rlAwait*[T](f: T): T = f
  template rlAwaitVoid*(call: untyped) = call
