#include "raylib.h"

static LoadFileDataCallback g_load_file_data_callback = 0;

void SetTraceLogCallback(TraceLogCallback callback)
{
    (void)callback;
}

void SetTraceLogLevel(int level)
{
    (void)level;
}
static int g_set_callback_call_count = 0;

void SetLoadFileDataCallback(LoadFileDataCallback callback)
{
    g_load_file_data_callback = callback;
    g_set_callback_call_count++;
}

unsigned char *test_raylib_invoke_load_file_data_callback(const char *file_name, int *data_size)
{
    if (!g_load_file_data_callback) {
        if (data_size) {
            *data_size = 0;
        }
        return 0;
    }

    return g_load_file_data_callback(file_name, data_size);
}

int test_raylib_callback_is_set(void)
{
    return g_load_file_data_callback != 0;
}

int test_raylib_set_callback_call_count(void)
{
    return g_set_callback_call_count;
}
