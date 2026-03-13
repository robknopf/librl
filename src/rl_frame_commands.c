#include "rl.h"

void rl_frame_commands_reset(rl_frame_command_buffer_t *frame_commands) {
    if (frame_commands == NULL) {
        return;
    }
    frame_commands->count = 0;
}

void rl_frame_commands_append(void *user_data,
                              const rl_module_frame_command_t *command) {
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
        const rl_module_frame_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_MODULE_FRAME_CMD_CLEAR:
            rl_frame_clear_background(command->data.clear.color);
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
        const rl_module_frame_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_MODULE_FRAME_CMD_PLAY_SOUND:
            (void)rl_sound_play(command->data.play_sound.sound);
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
        const rl_module_frame_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_MODULE_FRAME_CMD_DRAW_MODEL:
            if (command->data.draw_model.animation_index >= 0) {
                rl_model_animation_update(command->data.draw_model.model,
                                          command->data.draw_model.animation_index,
                                          command->data.draw_model.animation_frame);
            }
            rl_model_draw(command->data.draw_model.model,
                          command->data.draw_model.x,
                          command->data.draw_model.y,
                          command->data.draw_model.z,
                          command->data.draw_model.scale,
                          command->data.draw_model.rotation_x,
                          command->data.draw_model.rotation_y,
                          command->data.draw_model.rotation_z,
                          command->data.draw_model.tint);
            break;
        case RL_MODULE_FRAME_CMD_DRAW_SPRITE3D:
            rl_sprite3d_draw(command->data.draw_sprite3d.sprite,
                             command->data.draw_sprite3d.x,
                             command->data.draw_sprite3d.y,
                             command->data.draw_sprite3d.z,
                             command->data.draw_sprite3d.size,
                             command->data.draw_sprite3d.tint);
            break;
        case RL_MODULE_FRAME_CMD_DRAW_CUBE:
            rl_draw_cube(command->data.draw_cube.x,
                         command->data.draw_cube.y,
                         command->data.draw_cube.z,
                         command->data.draw_cube.width,
                         command->data.draw_cube.height,
                         command->data.draw_cube.length,
                         command->data.draw_cube.color);
            break;
        case RL_MODULE_FRAME_CMD_DRAW_GROUND_TEXTURE:
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
        const rl_module_frame_command_t *command = &frame_commands->commands[i];
        switch (command->type) {
        case RL_MODULE_FRAME_CMD_DRAW_TEXTURE:
            rl_texture_draw_ex(command->data.draw_texture.texture,
                               command->data.draw_texture.x,
                               command->data.draw_texture.y,
                               command->data.draw_texture.scale,
                               command->data.draw_texture.rotation,
                               command->data.draw_texture.tint);
            break;
        case RL_MODULE_FRAME_CMD_DRAW_TEXT:
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
