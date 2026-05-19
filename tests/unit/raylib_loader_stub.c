#include "raylib.h"
#include "rl_types.h"

static LoadFileDataCallback g_load_file_data_callback = 0;

void DrawTextEx(Font font, const char *text, Vector2 position, float fontSize, float spacing, Color tint)
{
    (void)font; (void)text; (void)position; (void)fontSize; (void)spacing; (void)tint;
}

Font rl_font_get(rl_handle_t handle)
{
    (void)handle;
    Font f = {0};
    return f;
}

Color rl_color_get(rl_handle_t handle)
{
    (void)handle;
    Color c = {0};
    return c;
}

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
