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
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_sprite3d.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_sprite3d.y);
      (void)json_read_float_field(cmd_json, "z", &out_cmd->data.draw_sprite3d.z);
      (void)json_read_float_field(cmd_json, "size", &out_cmd->data.draw_sprite3d.size);
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
      (void)json_read_float_field(cmd_json, "x", &out_cmd->data.draw_model.x);
      (void)json_read_float_field(cmd_json, "y", &out_cmd->data.draw_model.y);
      (void)json_read_float_field(cmd_json, "z", &out_cmd->data.draw_model.z);
      (void)json_read_float_field(cmd_json, "scale", &out_cmd->data.draw_model.scale);
      (void)json_read_float_field(cmd_json, "rotationX", &out_cmd->data.draw_model.rotation_x);
      (void)json_read_float_field(cmd_json, "rotationY", &out_cmd->data.draw_model.rotation_y);
      (void)json_read_float_field(cmd_json, "rotationZ", &out_cmd->data.draw_model.rotation_z);
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

int rl_protocol_parse_message(const char *raw, int len,
                              rl_protocol_message_type_t *out_type,
                              rl_ws_frame_data_t *out_frame,
                              bool *out_has_frame,
                              rl_protocol_requests_t *out_requests)
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
