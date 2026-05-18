#include "rl_frame_command.h"
#include "rl_camera3d.h"
#include "rl_model.h"
#include "rl_music.h"
#include "rl_render.h"
#include "rl_shape.h"
#include "rl_sound.h"
#include "rl_sprite2d.h"
#include "rl_sprite3d.h"
#include "rl_text.h"
#include "rl_texture.h"
#include <stdlib.h>

void rl_frame_commands_reset(rl_frame_command_buffer_t *frame_commands) {
    if (frame_commands == NULL) {
        return;
    }
    frame_commands->count = 0;
}

void rl_frame_commands_append(void *user_data,
                              const rl_render_command_t *command) {
    rl_frame_command_buffer_t *frame_commands =
        (rl_frame_command_buffer_t *)user_data;

    if (frame_commands == NULL || command == NULL) {
        return;
    }

    if (frame_commands->count < RL_FRAME_COMMAND_CAPACITY) {
        frame_commands->commands[frame_commands->count++] = *command;
    }
}

void rl_frame_commands_execute_clear(
    const rl_frame_command_buffer_t *frame_commands) {
    int i = 0;

    if (frame_commands == NULL) {
        return;
    }

    for (i = 0; i < frame_commands->count; i++) {
        const rl_render_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_RENDER_CMD_CLEAR:
            rl_render_clear_background(command->data.clear.color);
            break;
        default:
            break;
        }
    }
}

void rl_frame_commands_execute_audio(
    const rl_frame_command_buffer_t *frame_commands) {
    int i = 0;

    rl_music_update_all();

    if (frame_commands == NULL) {
        return;
    }

    for (i = 0; i < frame_commands->count; i++) {
        const rl_render_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_RENDER_CMD_PLAY_SOUND:
            (void)rl_sound_set_volume(command->data.play_sound.sound,
                                      command->data.play_sound.volume);
            (void)rl_sound_set_pitch(command->data.play_sound.sound,
                                     command->data.play_sound.pitch);
            (void)rl_sound_set_pan(command->data.play_sound.sound,
                                   command->data.play_sound.pan);
            (void)rl_sound_play(command->data.play_sound.sound);
            break;
        case RL_RENDER_CMD_PLAY_MUSIC:
            (void)rl_music_play(command->data.play_music.music);
            break;
        case RL_RENDER_CMD_PAUSE_MUSIC:
            (void)rl_music_pause(command->data.pause_music.music);
            break;
        case RL_RENDER_CMD_STOP_MUSIC:
            (void)rl_music_stop(command->data.stop_music.music);
            break;
        case RL_RENDER_CMD_SET_MUSIC_LOOP:
            (void)rl_music_set_loop(command->data.set_music_loop.music,
                                    command->data.set_music_loop.loop);
            break;
        case RL_RENDER_CMD_SET_MUSIC_VOLUME:
            (void)rl_music_set_volume(command->data.set_music_volume.music,
                                      command->data.set_music_volume.volume);
            break;
        default:
            break;
        }
    }
}

void rl_frame_commands_execute_state(
    const rl_frame_command_buffer_t *frame_commands) {
    int i = 0;

    if (frame_commands == NULL) {
        return;
    }

    for (i = 0; i < frame_commands->count; i++) {
        const rl_render_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_RENDER_CMD_SET_CAMERA3D:
            (void)rl_camera3d_set(command->data.set_camera3d.camera,
                                  command->data.set_camera3d.position_x,
                                  command->data.set_camera3d.position_y,
                                  command->data.set_camera3d.position_z,
                                  command->data.set_camera3d.target_x,
                                  command->data.set_camera3d.target_y,
                                  command->data.set_camera3d.target_z,
                                  command->data.set_camera3d.up_x,
                                  command->data.set_camera3d.up_y,
                                  command->data.set_camera3d.up_z,
                                  command->data.set_camera3d.fovy,
                                  command->data.set_camera3d.projection);
            break;
        case RL_RENDER_CMD_SET_ACTIVE_CAMERA3D:
            (void)rl_camera3d_set_active(command->data.set_active_camera3d.camera);
            break;
        case RL_RENDER_CMD_SET_MODEL_TRANSFORM:
            (void)rl_model_set_transform(command->data.set_model_transform.model,
                                         command->data.set_model_transform.position_x,
                                         command->data.set_model_transform.position_y,
                                         command->data.set_model_transform.position_z,
                                         command->data.set_model_transform.rotation_x,
                                         command->data.set_model_transform.rotation_y,
                                         command->data.set_model_transform.rotation_z,
                                         command->data.set_model_transform.scale_x,
                                         command->data.set_model_transform.scale_y,
                                         command->data.set_model_transform.scale_z);
            break;
        case RL_RENDER_CMD_SET_SPRITE3D_TRANSFORM:
            (void)rl_sprite3d_set_transform(command->data.set_sprite3d_transform.sprite,
                                            command->data.set_sprite3d_transform.position_x,
                                            command->data.set_sprite3d_transform.position_y,
                                            command->data.set_sprite3d_transform.position_z,
                                            command->data.set_sprite3d_transform.size);
            break;
        case RL_RENDER_CMD_SET_SPRITE2D_TRANSFORM:
            (void)rl_sprite2d_set_transform(command->data.set_sprite2d_transform.sprite,
                                            command->data.set_sprite2d_transform.x,
                                            command->data.set_sprite2d_transform.y,
                                            command->data.set_sprite2d_transform.scale,
                                            command->data.set_sprite2d_transform.rotation);
            break;
        default:
            break;
        }
    }
}

void rl_frame_commands_execute_3d(
    const rl_frame_command_buffer_t *frame_commands) {
    int i = 0;

    if (frame_commands == NULL) {
        return;
    }

    for (i = 0; i < frame_commands->count; i++) {
        const rl_render_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_RENDER_CMD_DRAW_MODEL:
            if (command->data.draw_model.animation_index >= 0) {
                rl_model_animation_update(command->data.draw_model.model,
                                          command->data.draw_model.animation_index,
                                          command->data.draw_model.animation_frame);
            }
            rl_model_draw(command->data.draw_model.model,
                          command->data.draw_model.tint);
            break;
        case RL_RENDER_CMD_DRAW_SPRITE3D:
            rl_sprite3d_draw(command->data.draw_sprite3d.sprite,
                             command->data.draw_sprite3d.tint);
            break;
        case RL_RENDER_CMD_DRAW_CUBE:
            rl_shape_draw_cube(command->data.draw_cube.x,
                               command->data.draw_cube.y,
                               command->data.draw_cube.z,
                               command->data.draw_cube.width,
                               command->data.draw_cube.height,
                               command->data.draw_cube.length,
                               command->data.draw_cube.color);
            break;
        case RL_RENDER_CMD_DRAW_GROUND_TEXTURE:
            rl_texture_draw_ground(command->data.draw_ground_texture.texture,
                                   command->data.draw_ground_texture.x,
                                   command->data.draw_ground_texture.y,
                                   command->data.draw_ground_texture.z,
                                   command->data.draw_ground_texture.width,
                                   command->data.draw_ground_texture.length,
                                   command->data.draw_ground_texture.tint);
            break;
        default:
            break;
        }
    }
}

void rl_frame_commands_execute_2d(
    const rl_frame_command_buffer_t *frame_commands) {
    int i = 0;

    if (frame_commands == NULL) {
        return;
    }

    for (i = 0; i < frame_commands->count; i++) {
        const rl_render_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_RENDER_CMD_DRAW_SPRITE2D:
            rl_sprite2d_draw(command->data.draw_sprite2d.sprite,
                             command->data.draw_sprite2d.tint);
            break;
        case RL_RENDER_CMD_DRAW_TEXTURE:
            rl_texture_draw_ex(command->data.draw_texture.texture,
                               command->data.draw_texture.x,
                               command->data.draw_texture.y,
                               command->data.draw_texture.scale,
                               command->data.draw_texture.rotation,
                               command->data.draw_texture.tint);
            break;
        case RL_RENDER_CMD_DRAW_TEXT:
            rl_text_draw_ex(command->data.draw_text.font,
                            command->data.draw_text.text,
                            (int)command->data.draw_text.x,
                            (int)command->data.draw_text.y,
                            command->data.draw_text.font_size,
                            command->data.draw_text.spacing,
                            command->data.draw_text.color);
            break;
        default:
            break;
        }
    }
}
