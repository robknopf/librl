#include <raylib.h>
#include "rl_font.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "exports.h"

#include "fetch_url/fetch_url.h"
#include "path/path.h"
//#include "rl_scratch.h"

#define MAX_FONTS 255
#define MAX_FONT_DATA_CACHE 255

// we cache loaded font data so we don't have to load it multiple times
// useful if we want to create fonts of different sizes
typedef struct
{
    char filename[256];
    size_t size;
    unsigned char *data;
    char extension[16];
} rl_font_data_t;

rl_font_data_t* font_data_cache[MAX_FONT_DATA_CACHE];
int rl_next_font_data_cache_index = 0;

// font handles for created fonts
Font *rl_fonts[MAX_FONTS];

// predefined fonts
const rl_handle_t RL_FONT_DEFAULT = 0;

rl_handle_t rl_next_font_handle = 1;

rl_handle_t rl_font_get_next_handle()
{
    if (rl_next_font_handle >= MAX_FONTS)
    {
        fprintf(stderr, "ERROR: MAX_FONTS reached (%d)\n", rl_next_font_handle);
        return 0;
    }
    return rl_next_font_handle++;
}

rl_font_data_t *rl_font_data_cache_get(const char *filename)
{
    char normalized_filename[256];
    path_normalize(filename, normalized_filename, sizeof(normalized_filename));

    for (int i = 0; i < MAX_FONT_DATA_CACHE; i++)
    {
        if (font_data_cache[i] == NULL) {
            continue;
        }

        if (strcmp(font_data_cache[i]->filename, normalized_filename) == 0)
        {
            return font_data_cache[i];
        }
    }
    return NULL;
}

void rl_font_data_cache_clear()
{
    int font_data_cache_freed = 0;

    for (int i = 0; i < MAX_FONT_DATA_CACHE; i++)
    {
        if (font_data_cache[i] != NULL)
        {
            //printf("Freeing font data cache %d\n", i);
            if (font_data_cache[i]->data) {
                free(font_data_cache[i]->data);
            } else {
                fprintf(stderr, "ERROR: Font data cache %d has no data\n", i);
            }
            free(font_data_cache[i]);
            font_data_cache[i] = NULL;
            font_data_cache_freed++;
        }
    }
    rl_next_font_data_cache_index = 0;

    printf("rl_font_data_cache_clear: Freed %d cached font data\n", font_data_cache_freed);
}

void rl_font_data_cache_add(const char *filename, size_t size, unsigned char *data, const char *extension)
{
    rl_font_data_t *cached_font_data = rl_font_data_cache_get(filename);
    if (cached_font_data != NULL && cached_font_data->size > 0 && cached_font_data->data != NULL)
    {
        printf("Cached font data exists for %s, skipping\n", filename);
        return;
    }


    if (rl_next_font_data_cache_index >= MAX_FONT_DATA_CACHE)
    {
        fprintf(stderr, "ERROR: MAX_FONT_DATA_CACHE reached (%d)\n", rl_next_font_data_cache_index);
        return;
    }
    char normalized_filename[256];
    path_normalize(filename, normalized_filename, sizeof(normalized_filename));

    printf("Caching font data for %s\n", normalized_filename);
    
    cached_font_data = malloc(sizeof(rl_font_data_t));
    cached_font_data->data = data;
    cached_font_data->size = size;
    snprintf(cached_font_data->filename, sizeof(cached_font_data->filename), "%s", normalized_filename);
    snprintf(cached_font_data->extension, sizeof(cached_font_data->extension), "%s", extension);

    font_data_cache[rl_next_font_data_cache_index] = cached_font_data;

    rl_next_font_data_cache_index++;
}




RL_KEEP
rl_handle_t rl_font_create(const char *filename, float fontSize)
{
    unsigned char *font_data = NULL;
    size_t font_data_size = 0;
    char font_extension[32];

    // first, check if the data is in our data cache
    rl_font_data_t *cached_font_data = rl_font_data_cache_get(filename);
    if (cached_font_data != NULL && cached_font_data->size > 0 && cached_font_data->data != NULL)
    {
        printf("Found cached font data for %s\n", filename);
        font_data = cached_font_data->data;
        font_data_size = cached_font_data->size;
        snprintf(font_extension, sizeof(font_extension), "%s", cached_font_data->extension);
    }
    else
    {
        // not in our cache, so we need to fetch it
        printf("No cached font data found for %s, fetching...\n", filename);

        // fetch the font
        fetch_url_result_t result = fetch_url(filename, 5000);
        if (result.code != 200)
        {
            fprintf(stderr, "ERROR: Failed to fetch font (%s)\n", filename);
            return RL_FONT_DEFAULT;
        }

        font_data = (unsigned char *)result.data;
        font_data_size = result.size;
        snprintf(font_extension, sizeof(font_extension), ".%s", path_get_extension(filename));
    }

    //printf("Loaded font data for %s\n", filename);
    //printf("Font data size: %zu\n", font_data_size);
    //printf("Font extension: %s\n", font_extension);

    // load the font from the font data
    Font loaded_font = LoadFontFromMemory(font_extension, (const unsigned char *)font_data, font_data_size, fontSize, NULL, 0);
    if (!IsFontValid(loaded_font))
    {
        fprintf(stderr, "ERROR: Failed to load font (%s)\n", filename);
        free(font_data);
        return 0;
    }
    rl_handle_t handle = rl_font_get_next_handle();
    rl_fonts[handle] = malloc(sizeof(Font));
    *(rl_fonts[handle]) = loaded_font;

    if (cached_font_data == NULL)
    {
        // store the font data in our cache
        rl_font_data_cache_add(filename, font_data_size, font_data, font_extension);
    }
    // we cached the data, so don't free it
    // free(result.data);

    printf("Loaded font: %s\n as handle: %d\n", filename, handle);
    return handle;
}

RL_KEEP
void rl_font_destroy(rl_handle_t handle)
{
    Font *font = rl_fonts[handle];
    if (font)
    {
        // Raylib owns the default font; unloading it here can double-free on shutdown.
        if (handle != RL_FONT_DEFAULT) {
            UnloadFont(*font); // Unload user-created font resources
        }
        free(font);        // Free our allocated memory
        rl_fonts[handle] = NULL;
    }
}

RL_KEEP
rl_handle_t rl_font_get_default()
{
    return RL_FONT_DEFAULT;
}

void rl_font_set(rl_handle_t handle, Font font)
{
    if (rl_fonts[handle])
    {
        rl_font_destroy(handle);
    }
    rl_fonts[handle] = malloc(sizeof(Font));
    *(rl_fonts[handle]) = font;
}

Font rl_font_get(rl_handle_t handle)
{
    if (!rl_fonts[handle])
    {
        fprintf(stderr, "ERROR: Invalid font handle (%d)\n", handle);
        return *rl_fonts[RL_FONT_DEFAULT];
    }
    return *rl_fonts[handle];
}

void rl_font_init()
{
    // init our cache
    for (int i = 0; i < MAX_FONT_DATA_CACHE; i++)
    {
        font_data_cache[i] = NULL;
    }
    rl_next_font_data_cache_index = 0;

    // init our font handles
    for (int i = 0; i < MAX_FONTS; i++)
    {
        rl_fonts[i] = NULL;
    }
    rl_next_font_handle = 0;

    rl_font_set(RL_FONT_DEFAULT, GetFontDefault()); // default
}

void rl_font_deinit()
{
    int fonts_freed = 0;
    for (rl_handle_t i = 0; i < MAX_FONTS; i++)
    {
        if (rl_fonts[i] != NULL)
        {
            // Raylib owns the default font; do not unload it from this wrapper.
            if (i != RL_FONT_DEFAULT) {
                UnloadFont(*rl_fonts[i]);
            }
            free(rl_fonts[i]);
            rl_fonts[i] = NULL;
            fonts_freed++;
        }
    }
    rl_next_font_handle = 0;

    printf("rl_font_deinit: Freed %d fonts\n", fonts_freed);

    // empty our cache
    rl_font_data_cache_clear();
}
