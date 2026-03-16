#ifndef RAYLIB_H
#define RAYLIB_H

#include <stdarg.h>

typedef unsigned char *(*LoadFileDataCallback)(const char *file_name, int *data_size);

void SetLoadFileDataCallback(LoadFileDataCallback callback);

/* Stubs for rl_logger.c when built with HEADLESS */
#define LOG_TRACE    0
#define LOG_DEBUG    1
#define LOG_INFO     2
#define LOG_WARNING  4
#define LOG_ERROR    8
#define LOG_FATAL    16
typedef void (*TraceLogCallback)(int log_level, const char *text, va_list args);
void SetTraceLogCallback(TraceLogCallback callback);
void SetTraceLogLevel(int level);

#endif // RAYLIB_H
