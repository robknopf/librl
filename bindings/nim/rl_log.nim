import ./rl

proc loggerSetLevel*(level: SomeInteger) {.inline.} =
  rl_logger_set_level(cint(level))

proc loggerMessage*(level: SomeInteger, message: string) {.inline.} =
  rl_logger_message(cint(level), "%s", message.cstring)

proc loggerMessageSource*(level: SomeInteger, sourceFile: string,
                          sourceLine: SomeInteger, message: string) {.inline.} =
  rl_logger_message_source(cint(level), sourceFile.cstring, cint(sourceLine), "%s", message.cstring)

proc log*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_INFO, message)

proc setLevel*(level: SomeInteger) {.inline.} =
  loggerSetLevel(level)

proc message*(level: SomeInteger, text: string) {.inline.} =
  loggerMessage(level, text)

proc messageSource*(level: SomeInteger, sourceFile: string,
                    sourceLine: SomeInteger, text: string) {.inline.} =
  loggerMessageSource(level, sourceFile, sourceLine, text)

proc debug*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_DEBUG, message)

proc info*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_INFO, message)

proc warn*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_WARN, message)

proc error*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_ERROR, message)

proc fatal*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_FATAL, message)

proc logDebug*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_DEBUG, message)

proc logInfo*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_INFO, message)

proc logWarn*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_WARN, message)

proc logError*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_ERROR, message)

proc logFatal*(message: string) {.inline.} =
  loggerMessage(RL_LOGGER_LEVEL_FATAL, message)

template logTrace*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_TRACE, info.filename, info.line, message)

template trace*(message: string) =
  logTrace(message)

template logDebugSource*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_DEBUG, info.filename, info.line, message)

template logInfoSource*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_INFO, info.filename, info.line, message)

template logWarnSource*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_WARN, info.filename, info.line, message)

template logErrorSource*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_ERROR, info.filename, info.line, message)

template logFatalSource*(message: string) =
  let info {.inject.} = instantiationInfo(fullPaths = true)
  loggerMessageSource(RL_LOGGER_LEVEL_FATAL, info.filename, info.line, message)
