#include "rl_sound.h"

#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>

#include "internal/exports.h"
#include "internal/rl_handle_pool.h"
#include "logger/log.h"
#include "path/path.h"

#define MAX_SOUNDS 256

typedef struct
{
    bool in_use;
    Sound sound;
    char path[256];
} rl_sound_entry_t;

static rl_sound_entry_t rl_sound_entries[MAX_SOUNDS];
static rl_handle_pool_t rl_sound_pool;
static uint16_t rl_sound_free_indices[MAX_SOUNDS];
static uint16_t rl_sound_generations[MAX_SOUNDS];
static unsigned char rl_sound_occupied[MAX_SOUNDS];

static rl_sound_entry_t *rl_sound_get_entry(rl_handle_t handle)
{
    uint16_t index = 0;
    if (!rl_handle_pool_resolve(&rl_sound_pool, handle, &index)) {
        return NULL;
    }
    if (!rl_sound_entries[index].in_use) {
        return NULL;
    }
    return &rl_sound_entries[index];
}

static void rl_sound_entry_reset(rl_sound_entry_t *entry)
{
    if (entry == NULL) {
        return;
    }
    entry->in_use = false;
    entry->sound = (Sound){0};
    entry->path[0] = '\0';
}

static bool rl_sound_ensure_audio_device(void)
{
    if (IsAudioDeviceReady()) {
        return true;
    }

    InitAudioDevice();
    if (!IsAudioDeviceReady()) {
        log_error("Failed to initialize audio device");
        return false;
    }

    return true;
}

RL_KEEP
rl_handle_t rl_sound_create(const char *filename)
{
    char normalized_path[256] = {0};
    rl_handle_t handle = 0;
    uint16_t index = 0;
    rl_sound_entry_t *entry = NULL;
    Sound loaded_sound = {0};

    if (!filename || filename[0] == '\0') {
        return 0;
    }

    if (!rl_sound_ensure_audio_device()) {
        return 0;
    }

    path_normalize(filename, normalized_path, sizeof(normalized_path));
    loaded_sound = LoadSound(normalized_path);
    if (!IsSoundValid(loaded_sound)) {
        log_error("Failed to load sound (%s)", normalized_path);
        return 0;
    }

    handle = rl_handle_pool_alloc(&rl_sound_pool);
    if (handle == 0) {
        log_error("MAX_SOUNDS reached (%d)", MAX_SOUNDS);
        UnloadSound(loaded_sound);
        return 0;
    }
    rl_handle_pool_resolve(&rl_sound_pool, handle, &index);

    entry = &rl_sound_entries[index];
    rl_sound_entry_reset(entry);
    entry->in_use = true;
    entry->sound = loaded_sound;
    snprintf(entry->path, sizeof(entry->path), "%s", normalized_path);
    return handle;
}

RL_KEEP
void rl_sound_destroy(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return;
    }

    StopSound(entry->sound);
    UnloadSound(entry->sound);
    rl_sound_entry_reset(entry);
    rl_handle_pool_free(&rl_sound_pool, handle);
}

RL_KEEP
bool rl_sound_play(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    PlaySound(entry->sound);
    return true;
}

RL_KEEP
bool rl_sound_pause(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    PauseSound(entry->sound);
    return true;
}

RL_KEEP
bool rl_sound_resume(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    ResumeSound(entry->sound);
    return true;
}

RL_KEEP
bool rl_sound_stop(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    StopSound(entry->sound);
    return true;
}

RL_KEEP
bool rl_sound_set_volume(rl_handle_t handle, float volume)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    SetSoundVolume(entry->sound, volume);
    return true;
}

RL_KEEP
bool rl_sound_set_pitch(rl_handle_t handle, float pitch)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    SetSoundPitch(entry->sound, pitch);
    return true;
}

RL_KEEP
bool rl_sound_set_pan(rl_handle_t handle, float pan)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    SetSoundPan(entry->sound, pan);
    return true;
}

RL_KEEP
bool rl_sound_is_playing(rl_handle_t handle)
{
    rl_sound_entry_t *entry = rl_sound_get_entry(handle);
    if (entry == NULL) {
        return false;
    }

    return IsSoundPlaying(entry->sound);
}

void rl_sound_init(void)
{
    rl_handle_pool_init(&rl_sound_pool,
                        MAX_SOUNDS,
                        rl_sound_free_indices,
                        MAX_SOUNDS,
                        rl_sound_generations,
                        rl_sound_occupied);
    for (int i = 0; i < MAX_SOUNDS; i++) {
        rl_sound_entry_reset(&rl_sound_entries[i]);
    }
}

void rl_sound_deinit(void)
{
    int unloaded = 0;
    for (uint16_t i = 1; i < MAX_SOUNDS; i++) {
        rl_handle_t handle = 0;
        if (!rl_sound_entries[i].in_use) {
            continue;
        }
        handle = rl_handle_pool_handle_from_index(&rl_sound_pool, i);
        if (handle != 0) {
            rl_sound_destroy(handle);
            unloaded++;
        }
    }

    rl_handle_pool_reset(&rl_sound_pool);
    if (unloaded > 0) {
        log_info("rl_sound_deinit: Freed %d sounds", unloaded);
    }
}
