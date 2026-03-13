#include "raylib.h"
#include "rl_logger.h"

#include <stdarg.h>
#include <stdio.h>

static void rl_logger_reroute_raylib_log(int log_level, const char *text, va_list args)
{
    char msg[2048];
    va_list copy;
    int level = LOG_LEVEL_INFO;

    va_copy(copy, args);
    vsnprintf(msg, sizeof(msg), text, copy);
    va_end(copy);

    switch (log_level) {
        case LOG_TRACE:
            level = LOG_LEVEL_TRACE;
            break;
        case LOG_DEBUG:
            level = LOG_LEVEL_DEBUG;
            break;
        case LOG_INFO:
            level = LOG_LEVEL_INFO;
            break;
        case LOG_WARNING:
            level = LOG_LEVEL_WARN;
            break;
        case LOG_ERROR:
            level = LOG_LEVEL_ERROR;
            break;
        case LOG_FATAL:
            level = LOG_LEVEL_FATAL;
            break;
        default:
            level = LOG_LEVEL_INFO;
            break;
    }

    log_message(level, "raylib", 0, "%s", msg);
}

void rl_logger_set_level(int level)
{
    int raylib_level = LOG_INFO;

    log_set_log_level((size_t)level);

    switch (level) {
        case LOG_LEVEL_TRACE:
            raylib_level = LOG_TRACE;
            break;
        case LOG_LEVEL_DEBUG:
            raylib_level = LOG_DEBUG;
            break;
        case LOG_LEVEL_INFO:
            raylib_level = LOG_INFO;
            break;
        case LOG_LEVEL_WARN:
            raylib_level = LOG_WARNING;
            break;
        case LOG_LEVEL_ERROR:
            raylib_level = LOG_ERROR;
            break;
        case LOG_LEVEL_FATAL:
            raylib_level = LOG_FATAL;
            break;
        default:
            raylib_level = LOG_INFO;
            break;
    }

    SetTraceLogLevel(raylib_level);
}

void rl_logger_init(void)
{
    SetTraceLogCallback(rl_logger_reroute_raylib_log);
}

void rl_logger_deinit(void)
{
    /* no-op: raylib does not provide a public API to restore internal default callback */
}
