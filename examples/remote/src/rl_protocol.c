#include "rl_protocol.h"
#include "json/json.h"

#include <stdio.h>
#include <string.h>

static int json_read_int_field(const json_value_t *object, const char *key, int *out_value)
{
  return json_object_get_int_value(object, key, out_value) ? 0 : -1;
}

static int json_read_float_field(const json_value_t *object, const char *key, float *out_value)
{
  double value = 0.0;

  if (!json_object_get_number_value(object, key, &value) || out_value == NULL) {
    return -1;
  }

  *out_value = (float)value;
  return 0;
}

static int json_read_string_field(const json_value_t *object, const char *key, char *out_value, size_t out_size)
{
  const char *value = NULL;

  if (!json_object_get_string_value(object, key, &value) || out_value == NULL || out_size == 0) {
    return -1;
  }

  snprintf(out_value, out_size, "%s", value);
  return 0;
}

static int parse_command(const json_value_t *cmd_json, rl_module_frame_command_t *out_cmd)
{
  int type = 0;

  if (cmd_json == NULL || out_cmd == NULL) {
    return -1;
  }

  if (!json_object_get_int_value(cmd_json, "type", &type)) {
    return -1;
  }

  out_cmd->type = type;

  switch (type) {
    case RL_MODULE_FRAME_CMD_CLEAR: {
      int color = 0;
      if (json_object_get_int_value(cmd_json, "color", &color)) {
        out_cmd->data.clear.color = (rl_handle_t)color;
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_TEXT: {
      int font = 0;
      int color = 0;
      const char *text = NULL;

      if (json_object_get_int_value(cmd_json, "font", &font)) {
        out_cmd->data.draw_text.font = (rl_handle_t)font;
      }
      if (json_object_get_int_value(cmd_json, "color", &color)) {
        out_cmd->data.draw_text.color = (rl_handle_t)color;
      }
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_text.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_text.y);
      (void)json_read_float_field(cmd_json, "fontSize", &out_cmd->data.draw_text.font_size);
      (void)json_read_float_field(cmd_json, "spacing", &out_cmd->data.draw_text.spacing);
      if (json_object_get_string_value(cmd_json, "text", &text)) {
        snprintf(out_cmd->data.draw_text.text, RL_MODULE_FRAME_TEXT_MAX, "%s", text);
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_SPRITE3D: {
      int sprite = 0;
      int tint = 0;

      if (json_object_get_int_value(cmd_json, "sprite", &sprite)) {
        out_cmd->data.draw_sprite3d.sprite = (rl_handle_t)sprite;
      }
      if (json_object_get_int_value(cmd_json, "tint", &tint)) {
        out_cmd->data.draw_sprite3d.tint = (rl_handle_t)tint;
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_PLAY_SOUND: {
      int sound = 0;
      if (json_object_get_int_value(cmd_json, "sound", &sound)) {
        out_cmd->data.play_sound.sound = (rl_handle_t)sound;
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_MODEL: {
      int model = 0;
      int tint = 0;
      int animation_index = 0;
      int animation_frame = 0;

      if (json_object_get_int_value(cmd_json, "model", &model)) {
        out_cmd->data.draw_model.model = (rl_handle_t)model;
      }
      if (json_object_get_int_value(cmd_json, "tint", &tint)) {
        out_cmd->data.draw_model.tint = (rl_handle_t)tint;
      }
      if (json_object_get_int_value(cmd_json, "animationIndex", &animation_index)) {
        out_cmd->data.draw_model.animation_index = animation_index;
      }
      if (json_object_get_int_value(cmd_json, "animationFrame", &animation_frame)) {
        out_cmd->data.draw_model.animation_frame = animation_frame;
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_TEXTURE: {
      int texture = 0;
      int tint = 0;

      if (json_object_get_int_value(cmd_json, "texture", &texture)) {
        out_cmd->data.draw_texture.texture = (rl_handle_t)texture;
      }
      if (json_object_get_int_value(cmd_json, "tint", &tint)) {
        out_cmd->data.draw_texture.tint = (rl_handle_t)tint;
      }
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_texture.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_texture.y);
      (void)json_read_float_field(cmd_json, "scale", &out_cmd->data.draw_texture.scale);
      (void)json_read_float_field(cmd_json, "rotation", &out_cmd->data.draw_texture.rotation);
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_CUBE: {
      int color = 0;

      if (json_object_get_int_value(cmd_json, "color", &color)) {
        out_cmd->data.draw_cube.color = (rl_handle_t)color;
      }
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_cube.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_cube.y);
      (void)json_read_float_field(cmd_json, "z", &out_cmd->data.draw_cube.z);
      (void)json_read_float_field(cmd_json, "width", &out_cmd->data.draw_cube.width);
      (void)json_read_float_field(cmd_json, "height", &out_cmd->data.draw_cube.height);
      (void)json_read_float_field(cmd_json, "length", &out_cmd->data.draw_cube.length);
      break;
    }

    case RL_MODULE_FRAME_CMD_DRAW_GROUND_TEXTURE: {
      int texture = 0;
      int tint = 0;

      if (json_object_get_int_value(cmd_json, "texture", &texture)) {
        out_cmd->data.draw_ground_texture.texture = (rl_handle_t)texture;
      }
      if (json_object_get_int_value(cmd_json, "tint", &tint)) {
        out_cmd->data.draw_ground_texture.tint = (rl_handle_t)tint;
      }
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_ground_texture.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_ground_texture.y);
      (void)json_read_float_field(cmd_json, "z", &out_cmd->data.draw_ground_texture.z);
      (void)json_read_float_field(cmd_json, "width", &out_cmd->data.draw_ground_texture.width);
      (void)json_read_float_field(cmd_json, "length", &out_cmd->data.draw_ground_texture.length);
      break;
    }

    case RL_MODULE_FRAME_CMD_SET_CAMERA3D: {
      int camera = 0;
      int projection = 0;

      if (json_object_get_int_value(cmd_json, "camera", &camera)) {
        out_cmd->data.set_camera3d.camera = (rl_handle_t)camera;
      }
      (void)json_read_float_field(cmd_json, "positionX", &out_cmd->data.set_camera3d.position_x);
      (void)json_read_float_field(cmd_json, "positionY", &out_cmd->data.set_camera3d.position_y);
      (void)json_read_float_field(cmd_json, "positionZ", &out_cmd->data.set_camera3d.position_z);
      (void)json_read_float_field(cmd_json, "targetX", &out_cmd->data.set_camera3d.target_x);
      (void)json_read_float_field(cmd_json, "targetY", &out_cmd->data.set_camera3d.target_y);
      (void)json_read_float_field(cmd_json, "targetZ", &out_cmd->data.set_camera3d.target_z);
      (void)json_read_float_field(cmd_json, "upX", &out_cmd->data.set_camera3d.up_x);
      (void)json_read_float_field(cmd_json, "upY", &out_cmd->data.set_camera3d.up_y);
      (void)json_read_float_field(cmd_json, "upZ", &out_cmd->data.set_camera3d.up_z);
      (void)json_read_float_field(cmd_json, "fovy", &out_cmd->data.set_camera3d.fovy);
      if (json_object_get_int_value(cmd_json, "projection", &projection)) {
        out_cmd->data.set_camera3d.projection = projection;
      }
      break;
    }

    case RL_MODULE_FRAME_CMD_SET_MODEL_TRANSFORM: {
      int model = 0;

      if (json_object_get_int_value(cmd_json, "model", &model)) {
        out_cmd->data.set_model_transform.model = (rl_handle_t)model;
      }
      (void)json_read_float_field(cmd_json, "positionX", &out_cmd->data.set_model_transform.position_x);
      (void)json_read_float_field(cmd_json, "positionY", &out_cmd->data.set_model_transform.position_y);
      (void)json_read_float_field(cmd_json, "positionZ", &out_cmd->data.set_model_transform.position_z);
      (void)json_read_float_field(cmd_json, "rotationX", &out_cmd->data.set_model_transform.rotation_x);
      (void)json_read_float_field(cmd_json, "rotationY", &out_cmd->data.set_model_transform.rotation_y);
      (void)json_read_float_field(cmd_json, "rotationZ", &out_cmd->data.set_model_transform.rotation_z);
      (void)json_read_float_field(cmd_json, "scaleX", &out_cmd->data.set_model_transform.scale_x);
      (void)json_read_float_field(cmd_json, "scaleY", &out_cmd->data.set_model_transform.scale_y);
      (void)json_read_float_field(cmd_json, "scaleZ", &out_cmd->data.set_model_transform.scale_z);
      break;
    }

    case RL_MODULE_FRAME_CMD_SET_SPRITE3D_TRANSFORM: {
      int sprite = 0;

      if (json_object_get_int_value(cmd_json, "sprite", &sprite)) {
        out_cmd->data.set_sprite3d_transform.sprite = (rl_handle_t)sprite;
      }
      (void)json_read_float_field(cmd_json, "positionX", &out_cmd->data.set_sprite3d_transform.position_x);
      (void)json_read_float_field(cmd_json, "positionY", &out_cmd->data.set_sprite3d_transform.position_y);
      (void)json_read_float_field(cmd_json, "positionZ", &out_cmd->data.set_sprite3d_transform.position_z);
      (void)json_read_float_field(cmd_json, "size", &out_cmd->data.set_sprite3d_transform.size);
      break;
    }

    default:
      return -1;
  }

  return 0;
}

static int parse_frame_object(const json_value_t *json_obj, rl_ws_frame_data_t *out_frame)
{
  const json_value_t *commands = NULL;
  int cmd_count = 0;
  int i = 0;

  if (json_obj == NULL || out_frame == NULL) {
    return -1;
  }

  memset(out_frame, 0, sizeof(rl_ws_frame_data_t));

  (void)json_object_get_int_value(json_obj, "frameNumber", &out_frame->frame_number);
  (void)json_read_float_field(json_obj, "deltaTime", &out_frame->delta_time);

  commands = json_object_get(json_obj, "commands");
  if (!json_is_array(commands)) {
    return -1;
  }

  cmd_count = json_array_size(commands);
  if (cmd_count > RL_FRAME_COMMAND_CAPACITY) {
    cmd_count = RL_FRAME_COMMAND_CAPACITY;
  }

  for (i = 0; i < cmd_count; ++i) {
    const json_value_t *cmd_json = json_array_get(commands, i);
    if (parse_command(cmd_json, &out_frame->commands.commands[out_frame->commands.count]) == 0) {
      out_frame->commands.count++;
    }
  }

  return 0;
}

static int parse_resource_request(const json_value_t *req_json, rl_resource_request_t *out)
{
  int rid = 0;
  int type = 0;

  if (req_json == NULL || out == NULL) {
    return -1;
  }

  if (!json_object_get_int_value(req_json, "rid", &rid) ||
      !json_object_get_int_value(req_json, "type", &type)) {
    return -1;
  }

  memset(out, 0, sizeof(rl_resource_request_t));
  out->rid = (uint32_t)rid;
  out->type = (rl_resource_request_type_t)type;

  switch (out->type) {
    case RL_RESOURCE_REQUEST_CREATE_COLOR:
      if (json_read_int_field(req_json, "r", &out->data.create_color.r) != 0 ||
          json_read_int_field(req_json, "g", &out->data.create_color.g) != 0 ||
          json_read_int_field(req_json, "b", &out->data.create_color.b) != 0 ||
          json_read_int_field(req_json, "a", &out->data.create_color.a) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_CAMERA3D:
      if (json_read_float_field(req_json, "posX", &out->data.create_camera3d.posX) != 0 ||
          json_read_float_field(req_json, "posY", &out->data.create_camera3d.posY) != 0 ||
          json_read_float_field(req_json, "posZ", &out->data.create_camera3d.posZ) != 0 ||
          json_read_float_field(req_json, "targetX", &out->data.create_camera3d.targetX) != 0 ||
          json_read_float_field(req_json, "targetY", &out->data.create_camera3d.targetY) != 0 ||
          json_read_float_field(req_json, "targetZ", &out->data.create_camera3d.targetZ) != 0 ||
          json_read_float_field(req_json, "upX", &out->data.create_camera3d.upX) != 0 ||
          json_read_float_field(req_json, "upY", &out->data.create_camera3d.upY) != 0 ||
          json_read_float_field(req_json, "upZ", &out->data.create_camera3d.upZ) != 0 ||
          json_read_float_field(req_json, "fovy", &out->data.create_camera3d.fovy) != 0 ||
          json_read_int_field(req_json, "projection", &out->data.create_camera3d.projection) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_FONT:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_font.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0 ||
          json_read_float_field(req_json, "fontSize", &out->data.create_font.fontSize) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_TEXTURE:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_texture.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_MODEL:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_model.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_SOUND:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_sound.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_MUSIC:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_music.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_CREATE_SPRITE3D:
      if (json_read_string_field(req_json, "filename",
                                 out->data.create_sprite3d.filename,
                                 RL_RESOURCE_REQUEST_MAX_FILENAME) != 0) {
        return -1;
      }
      break;

    case RL_RESOURCE_REQUEST_DESTROY:
      if (json_read_int_field(req_json, "handle", (int *)&out->data.destroy.handle) != 0) {
        return -1;
      }
      break;

    default:
      return -1;
  }

  return 0;
}

static int parse_pick_request(const json_value_t *req_json, rl_pick_request_t *out)
{
  int rid = 0;
  int type = 0;
  int camera = 0;
  int model = 0;

  if (req_json == NULL || out == NULL) {
    return -1;
  }

  if (!json_object_get_int_value(req_json, "rid", &rid) ||
      !json_object_get_int_value(req_json, "type", &type)) {
    return -1;
  }

  memset(out, 0, sizeof(rl_pick_request_t));
  out->rid = (uint32_t)rid;
  out->type = (rl_pick_request_type_t)type;

  switch (out->type) {
    case RL_PICK_REQUEST_MODEL:
      if (!json_object_get_int_value(req_json, "camera", &camera) ||
          !json_object_get_int_value(req_json, "handle", &model) ||
          json_read_float_field(req_json, "mouseX", &out->data.model.mouse_x) != 0 ||
          json_read_float_field(req_json, "mouseY", &out->data.model.mouse_y) != 0 ||
          json_read_float_field(req_json, "x", &out->data.model.x) != 0 ||
          json_read_float_field(req_json, "y", &out->data.model.y) != 0 ||
          json_read_float_field(req_json, "z", &out->data.model.z) != 0 ||
          json_read_float_field(req_json, "scale", &out->data.model.scale) != 0 ||
          json_read_float_field(req_json, "rotationX", &out->data.model.rotation_x) != 0 ||
          json_read_float_field(req_json, "rotationY", &out->data.model.rotation_y) != 0 ||
          json_read_float_field(req_json, "rotationZ", &out->data.model.rotation_z) != 0) {
        return -1;
      }
      out->data.model.camera = (rl_handle_t)camera;
      out->data.model.handle = (rl_handle_t)model;
      break;

    case RL_PICK_REQUEST_SPRITE3D:
      if (!json_object_get_int_value(req_json, "camera", &camera) ||
          !json_object_get_int_value(req_json, "handle", &model) ||
          json_read_float_field(req_json, "mouseX", &out->data.sprite3d.mouse_x) != 0 ||
          json_read_float_field(req_json, "mouseY", &out->data.sprite3d.mouse_y) != 0 ||
          json_read_float_field(req_json, "x", &out->data.sprite3d.x) != 0 ||
          json_read_float_field(req_json, "y", &out->data.sprite3d.y) != 0 ||
          json_read_float_field(req_json, "z", &out->data.sprite3d.z) != 0 ||
          json_read_float_field(req_json, "size", &out->data.sprite3d.size) != 0) {
        return -1;
      }
      out->data.sprite3d.camera = (rl_handle_t)camera;
      out->data.sprite3d.handle = (rl_handle_t)model;
      break;

    default:
      return -1;
  }

  return 0;
}

static int parse_music_command(const json_value_t *cmd_json, rl_music_command_t *out)
{
  int type = 0;
  int handle = 0;
  bool loop = false;
  double volume = 0.0;

  if (cmd_json == NULL || out == NULL) {
    return -1;
  }

  if (!json_object_get_int_value(cmd_json, "type", &type) ||
      !json_object_get_int_value(cmd_json, "handle", &handle)) {
    return -1;
  }

  memset(out, 0, sizeof(rl_music_command_t));
  out->type = (rl_music_command_type_t)type;
  out->handle = (rl_handle_t)handle;

  if (json_object_get_bool_value(cmd_json, "loop", &loop)) {
    out->loop = loop;
  }
  if (json_object_get_number_value(cmd_json, "volume", &volume)) {
    out->volume = (float)volume;
  }

  return 0;
}

int rl_protocol_parse_message(const char *raw, int len,
                              rl_protocol_message_type_t *out_type,
                              rl_ws_frame_data_t *out_frame,
                              bool *out_has_frame,
                              rl_protocol_requests_t *out_requests,
                              rl_protocol_pick_requests_t *out_pick_requests,
                              rl_protocol_music_commands_t *out_music_commands)
{
  json_value_t *root = NULL;
  const json_value_t *type_obj = NULL;

  if (raw == NULL || len <= 0) {
    return -1;
  }

  if (out_type != NULL) {
    *out_type = RL_PROTOCOL_MESSAGE_UNKNOWN;
  }
  if (out_has_frame != NULL) {
    *out_has_frame = false;
  }
  if (out_requests != NULL) {
    out_requests->count = 0;
  }
  if (out_pick_requests != NULL) {
    out_pick_requests->count = 0;
  }
  if (out_music_commands != NULL) {
    out_music_commands->count = 0;
  }

  root = json_parse_with_length(raw, (size_t)len);
  if (root == NULL) {
    return -1;
  }

  type_obj = json_object_get(root, "type");
  if (!json_is_string(type_obj) || json_get_string(type_obj) == NULL) {
    json_delete(root);
    return -1;
  }

  if (strcmp(json_get_string(type_obj), "frame") == 0) {
    const json_value_t *frame_obj = json_object_get(root, "frame");
    if (frame_obj == NULL || out_frame == NULL || parse_frame_object(frame_obj, out_frame) != 0) {
      json_delete(root);
      return -1;
    }
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_FRAME;
    }
    if (out_has_frame != NULL) {
      *out_has_frame = true;
    }
  } else if (strcmp(json_get_string(type_obj), "resourceRequests") == 0) {
    const json_value_t *resource_requests = json_object_get(root, "resourceRequests");
    int count = 0;
    int index = 0;

    if (!json_is_array(resource_requests) || out_requests == NULL) {
      json_delete(root);
      return -1;
    }

    for (index = 0; index < json_array_size(resource_requests); ++index) {
      const json_value_t *req_json = json_array_get(resource_requests, index);
      if (count >= RL_PROTOCOL_MAX_REQUESTS) {
        break;
      }
      if (parse_resource_request(req_json, &out_requests->items[count]) == 0) {
        count++;
      }
    }

    out_requests->count = count;
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_RESOURCE_REQUESTS;
    }
  } else if (strcmp(json_get_string(type_obj), "pickRequests") == 0) {
    const json_value_t *pick_requests = json_object_get(root, "pickRequests");
    int count = 0;
    int index = 0;

    if (!json_is_array(pick_requests) || out_pick_requests == NULL) {
      json_delete(root);
      return -1;
    }

    for (index = 0; index < json_array_size(pick_requests); ++index) {
      const json_value_t *req_json = json_array_get(pick_requests, index);
      if (count >= RL_PROTOCOL_MAX_PICK_REQUESTS) {
        break;
      }
      if (parse_pick_request(req_json, &out_pick_requests->items[count]) == 0) {
        count++;
      }
    }

    out_pick_requests->count = count;
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_PICK_REQUESTS;
    }
  } else if (strcmp(json_get_string(type_obj), "musicCommands") == 0) {
    const json_value_t *music_commands = json_object_get(root, "musicCommands");
    int count = 0;
    int index = 0;

    if (!json_is_array(music_commands) || out_music_commands == NULL) {
      json_delete(root);
      return -1;
    }

    for (index = 0; index < json_array_size(music_commands); ++index) {
      const json_value_t *cmd_json = json_array_get(music_commands, index);
      if (count >= RL_PROTOCOL_MAX_MUSIC_COMMANDS) {
        break;
      }
      if (parse_music_command(cmd_json, &out_music_commands->items[count]) == 0) {
        count++;
      }
    }

    out_music_commands->count = count;
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_MUSIC_COMMANDS;
    }
  } else if (strcmp(json_get_string(type_obj), "reset") == 0) {
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_RESET;
    }
  } else {
    json_delete(root);
    return -1;
  }

  json_delete(root);
  return 0;
}

int rl_protocol_serialize_responses(const rl_resource_response_t *responses, int count,
                                    char *out_buf, int buf_size)
{
  json_value_t *root = NULL;
  json_value_t *responses_array = NULL;
  char *json_str = NULL;
  int len = 0;
  int i = 0;

  if (responses == NULL || count <= 0 || out_buf == NULL || buf_size <= 0) {
    return -1;
  }

  root = json_create_object();
  if (root == NULL) {
    return -1;
  }

  responses_array = json_create_array();
  if (responses_array == NULL) {
    json_delete(root);
    return -1;
  }

  for (i = 0; i < count; i++) {
    json_value_t *resp = json_create_object();
    if (resp == NULL) {
      continue;
    }

    if (json_add_number_to_object(resp, "rid", responses[i].rid) == NULL ||
        json_add_number_to_object(resp, "handle", responses[i].handle) == NULL ||
        json_add_bool_to_object(resp, "success", responses[i].success) == NULL ||
        json_add_item_to_array(responses_array, resp) != 0) {
      json_delete(resp);
      continue;
    }
  }

  if (json_add_string_to_object(root, "type", "resourceResponses") == NULL ||
      json_add_item_to_object(root, "resourceResponses", responses_array) != 0) {
    json_delete(responses_array);
    json_delete(root);
    return -1;
  }

  json_str = json_print_unformatted(root);
  json_delete(root);

  if (json_str == NULL) {
    return -1;
  }

  len = (int)strlen(json_str);
  if (len >= buf_size) {
    json_free_string(json_str);
    return -1;
  }

  memcpy(out_buf, json_str, len + 1);
  json_free_string(json_str);
  return len;
}

int rl_protocol_serialize_input_state(const rl_mouse_state_t *mouse,
                                      const rl_keyboard_state_t *keyboard,
                                      int screen_width,
                                      int screen_height,
                                      char *out_buf,
                                      int buf_size)
{
  json_value_t *root = NULL;
  json_value_t *input_state = NULL;
  json_value_t *mouse_obj = NULL;
  json_value_t *keyboard_obj = NULL;
  json_value_t *keys_down = NULL;
  json_value_t *pressed_keys = NULL;
  json_value_t *pressed_chars = NULL;
  char *json_str = NULL;
  int len = 0;
  int i = 0;

  if (mouse == NULL || keyboard == NULL || out_buf == NULL || buf_size <= 0) {
    return -1;
  }

  root = json_create_object();
  input_state = json_create_object();
  mouse_obj = json_create_object();
  keyboard_obj = json_create_object();
  keys_down = json_create_array();
  pressed_keys = json_create_array();
  pressed_chars = json_create_array();

  if (root == NULL || input_state == NULL || mouse_obj == NULL || keyboard_obj == NULL ||
      keys_down == NULL || pressed_keys == NULL || pressed_chars == NULL) {
    json_delete(root);
    json_delete(input_state);
    json_delete(mouse_obj);
    json_delete(keyboard_obj);
    json_delete(keys_down);
    json_delete(pressed_keys);
    json_delete(pressed_chars);
    return -1;
  }

  for (i = 0; i < keyboard->max_num_keys && i < RL_KEYBOARD_MAX_KEYS; i++) {
    if (keyboard->keys[i] == RL_BUTTON_DOWN || keyboard->keys[i] == RL_BUTTON_PRESSED) {
      json_value_t *entry = json_create_number((double)i);
      if (entry != NULL) {
        (void)json_add_item_to_array(keys_down, entry);
      }
    }
  }

  for (i = 0; i < keyboard->num_pressed_keys && i < RL_KEYBOARD_MAX_PRESSED_KEYS; i++) {
    json_value_t *entry = json_create_number((double)keyboard->pressed_keys[i]);
    if (entry != NULL) {
      (void)json_add_item_to_array(pressed_keys, entry);
    }
  }

  for (i = 0; i < keyboard->num_pressed_chars && i < RL_KEYBOARD_MAX_PRESSED_CHARS; i++) {
    json_value_t *entry = json_create_number((double)keyboard->pressed_chars[i]);
    if (entry != NULL) {
      (void)json_add_item_to_array(pressed_chars, entry);
    }
  }

  if (json_add_number_to_object(mouse_obj, "x", mouse->x) == NULL ||
      json_add_number_to_object(mouse_obj, "y", mouse->y) == NULL ||
      json_add_number_to_object(mouse_obj, "wheel", mouse->wheel) == NULL ||
      json_add_number_to_object(mouse_obj, "left", mouse->left) == NULL ||
      json_add_number_to_object(mouse_obj, "right", mouse->right) == NULL ||
      json_add_number_to_object(mouse_obj, "middle", mouse->middle) == NULL ||
      json_add_number_to_object(input_state, "screenWidth", screen_width) == NULL ||
      json_add_number_to_object(input_state, "screenHeight", screen_height) == NULL ||
      json_add_item_to_object(input_state, "mouse", mouse_obj) != 0 ||
      json_add_item_to_object(keyboard_obj, "keysDown", keys_down) != 0 ||
      json_add_item_to_object(keyboard_obj, "pressedKeys", pressed_keys) != 0 ||
      json_add_item_to_object(keyboard_obj, "pressedChars", pressed_chars) != 0 ||
      json_add_item_to_object(input_state, "keyboard", keyboard_obj) != 0 ||
      json_add_string_to_object(root, "type", "inputState") == NULL ||
      json_add_item_to_object(root, "inputState", input_state) != 0) {
    json_delete(mouse_obj);
    json_delete(keys_down);
    json_delete(pressed_keys);
    json_delete(pressed_chars);
    json_delete(keyboard_obj);
    json_delete(input_state);
    json_delete(root);
    return -1;
  }

  json_str = json_print_unformatted(root);
  json_delete(root);

  if (json_str == NULL) {
    return -1;
  }

  len = (int)strlen(json_str);
  if (len >= buf_size) {
    json_free_string(json_str);
    return -1;
  }

  memcpy(out_buf, json_str, len + 1);
  json_free_string(json_str);
  return len;
}

int rl_protocol_serialize_pick_responses(const rl_pick_response_t *responses,
                                         int count,
                                         char *out_buf,
                                         int buf_size)
{
  json_value_t *root = NULL;
  json_value_t *responses_array = NULL;
  char *json_str = NULL;
  int len = 0;
  int i = 0;

  if (responses == NULL || count <= 0 || out_buf == NULL || buf_size <= 0) {
    return -1;
  }

  root = json_create_object();
  responses_array = json_create_array();
  if (root == NULL || responses_array == NULL) {
    json_delete(root);
    json_delete(responses_array);
    return -1;
  }

  for (i = 0; i < count; i++) {
    json_value_t *response_obj = json_create_object();
    json_value_t *point_obj = json_create_object();
    json_value_t *normal_obj = json_create_object();

    if (response_obj == NULL || point_obj == NULL || normal_obj == NULL) {
      json_delete(response_obj);
      json_delete(point_obj);
      json_delete(normal_obj);
      continue;
    }

    if (json_add_number_to_object(point_obj, "x", responses[i].point.x) == NULL ||
        json_add_number_to_object(point_obj, "y", responses[i].point.y) == NULL ||
        json_add_number_to_object(point_obj, "z", responses[i].point.z) == NULL ||
        json_add_number_to_object(normal_obj, "x", responses[i].normal.x) == NULL ||
        json_add_number_to_object(normal_obj, "y", responses[i].normal.y) == NULL ||
        json_add_number_to_object(normal_obj, "z", responses[i].normal.z) == NULL ||
        json_add_number_to_object(response_obj, "rid", responses[i].rid) == NULL ||
        json_add_bool_to_object(response_obj, "hit", responses[i].hit) == NULL ||
        json_add_number_to_object(response_obj, "distance", responses[i].distance) == NULL ||
        json_add_item_to_object(response_obj, "point", point_obj) != 0 ||
        json_add_item_to_object(response_obj, "normal", normal_obj) != 0 ||
        json_add_item_to_array(responses_array, response_obj) != 0) {
      json_delete(point_obj);
      json_delete(normal_obj);
      json_delete(response_obj);
      continue;
    }
  }

  if (json_add_string_to_object(root, "type", "pickResponses") == NULL ||
      json_add_item_to_object(root, "pickResponses", responses_array) != 0) {
    json_delete(responses_array);
    json_delete(root);
    return -1;
  }

  json_str = json_print_unformatted(root);
  json_delete(root);

  if (json_str == NULL) {
    return -1;
  }

  len = (int)strlen(json_str);
  if (len >= buf_size) {
    json_free_string(json_str);
    return -1;
  }

  memcpy(out_buf, json_str, len + 1);
  json_free_string(json_str);
  return len;
}
