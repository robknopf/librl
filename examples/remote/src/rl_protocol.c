#include "rl_protocol.h"
#include "../../deps/wgutils/vendor/cjson/cJSON.h"
#include <string.h>
#include <stdio.h>

static int parse_command(const cJSON *cmd_json, rl_module_frame_command_t *out_cmd) {
  const cJSON *type_json = NULL;
  int type = 0;
  
  if (cmd_json == NULL || out_cmd == NULL) {
    return -1;
  }
  
  type_json = cJSON_GetObjectItemCaseSensitive(cmd_json, "type");
  if (!cJSON_IsNumber(type_json)) {
    return -1;
  }
  
  type = type_json->valueint;
  out_cmd->type = type;
  
  switch (type) {
    case RL_MODULE_FRAME_CMD_CLEAR: {
      const cJSON *color = cJSON_GetObjectItemCaseSensitive(cmd_json, "color");
      if (cJSON_IsNumber(color)) {
        out_cmd->data.clear.color = (rl_handle_t)color->valueint;
      }
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_TEXT: {
      const cJSON *font = cJSON_GetObjectItemCaseSensitive(cmd_json, "font");
      const cJSON *color = cJSON_GetObjectItemCaseSensitive(cmd_json, "color");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *fontSize = cJSON_GetObjectItemCaseSensitive(cmd_json, "fontSize");
      const cJSON *spacing = cJSON_GetObjectItemCaseSensitive(cmd_json, "spacing");
      const cJSON *text = cJSON_GetObjectItemCaseSensitive(cmd_json, "text");
      
      if (cJSON_IsNumber(font)) out_cmd->data.draw_text.font = (rl_handle_t)font->valueint;
      if (cJSON_IsNumber(color)) out_cmd->data.draw_text.color = (rl_handle_t)color->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_text.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_text.y = (float)y->valuedouble;
      if (cJSON_IsNumber(fontSize)) out_cmd->data.draw_text.font_size = (float)fontSize->valuedouble;
      if (cJSON_IsNumber(spacing)) out_cmd->data.draw_text.spacing = (float)spacing->valuedouble;
      if (cJSON_IsString(text)) {
        snprintf(out_cmd->data.draw_text.text, RL_MODULE_FRAME_TEXT_MAX, "%s", text->valuestring);
      }
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_SPRITE3D: {
      const cJSON *sprite = cJSON_GetObjectItemCaseSensitive(cmd_json, "sprite");
      const cJSON *tint = cJSON_GetObjectItemCaseSensitive(cmd_json, "tint");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *z = cJSON_GetObjectItemCaseSensitive(cmd_json, "z");
      const cJSON *size = cJSON_GetObjectItemCaseSensitive(cmd_json, "size");
      
      if (cJSON_IsNumber(sprite)) out_cmd->data.draw_sprite3d.sprite = (rl_handle_t)sprite->valueint;
      if (cJSON_IsNumber(tint)) out_cmd->data.draw_sprite3d.tint = (rl_handle_t)tint->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_sprite3d.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_sprite3d.y = (float)y->valuedouble;
      if (cJSON_IsNumber(z)) out_cmd->data.draw_sprite3d.z = (float)z->valuedouble;
      if (cJSON_IsNumber(size)) out_cmd->data.draw_sprite3d.size = (float)size->valuedouble;
      break;
    }
    
    case RL_MODULE_FRAME_CMD_PLAY_SOUND: {
      const cJSON *sound = cJSON_GetObjectItemCaseSensitive(cmd_json, "sound");
      if (cJSON_IsNumber(sound)) {
        out_cmd->data.play_sound.sound = (rl_handle_t)sound->valueint;
      }
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_MODEL: {
      const cJSON *model = cJSON_GetObjectItemCaseSensitive(cmd_json, "model");
      const cJSON *tint = cJSON_GetObjectItemCaseSensitive(cmd_json, "tint");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *z = cJSON_GetObjectItemCaseSensitive(cmd_json, "z");
      const cJSON *scale = cJSON_GetObjectItemCaseSensitive(cmd_json, "scale");
      const cJSON *rotationX = cJSON_GetObjectItemCaseSensitive(cmd_json, "rotationX");
      const cJSON *rotationY = cJSON_GetObjectItemCaseSensitive(cmd_json, "rotationY");
      const cJSON *rotationZ = cJSON_GetObjectItemCaseSensitive(cmd_json, "rotationZ");
      const cJSON *animationIndex = cJSON_GetObjectItemCaseSensitive(cmd_json, "animationIndex");
      const cJSON *animationFrame = cJSON_GetObjectItemCaseSensitive(cmd_json, "animationFrame");
      
      if (cJSON_IsNumber(model)) out_cmd->data.draw_model.model = (rl_handle_t)model->valueint;
      if (cJSON_IsNumber(tint)) out_cmd->data.draw_model.tint = (rl_handle_t)tint->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_model.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_model.y = (float)y->valuedouble;
      if (cJSON_IsNumber(z)) out_cmd->data.draw_model.z = (float)z->valuedouble;
      if (cJSON_IsNumber(scale)) out_cmd->data.draw_model.scale = (float)scale->valuedouble;
      if (cJSON_IsNumber(rotationX)) out_cmd->data.draw_model.rotation_x = (float)rotationX->valuedouble;
      if (cJSON_IsNumber(rotationY)) out_cmd->data.draw_model.rotation_y = (float)rotationY->valuedouble;
      if (cJSON_IsNumber(rotationZ)) out_cmd->data.draw_model.rotation_z = (float)rotationZ->valuedouble;
      if (cJSON_IsNumber(animationIndex)) out_cmd->data.draw_model.animation_index = animationIndex->valueint;
      if (cJSON_IsNumber(animationFrame)) out_cmd->data.draw_model.animation_frame = animationFrame->valueint;
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_TEXTURE: {
      const cJSON *texture = cJSON_GetObjectItemCaseSensitive(cmd_json, "texture");
      const cJSON *tint = cJSON_GetObjectItemCaseSensitive(cmd_json, "tint");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *scale = cJSON_GetObjectItemCaseSensitive(cmd_json, "scale");
      const cJSON *rotation = cJSON_GetObjectItemCaseSensitive(cmd_json, "rotation");
      
      if (cJSON_IsNumber(texture)) out_cmd->data.draw_texture.texture = (rl_handle_t)texture->valueint;
      if (cJSON_IsNumber(tint)) out_cmd->data.draw_texture.tint = (rl_handle_t)tint->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_texture.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_texture.y = (float)y->valuedouble;
      if (cJSON_IsNumber(scale)) out_cmd->data.draw_texture.scale = (float)scale->valuedouble;
      if (cJSON_IsNumber(rotation)) out_cmd->data.draw_texture.rotation = (float)rotation->valuedouble;
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_CUBE: {
      const cJSON *color = cJSON_GetObjectItemCaseSensitive(cmd_json, "color");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *z = cJSON_GetObjectItemCaseSensitive(cmd_json, "z");
      const cJSON *width = cJSON_GetObjectItemCaseSensitive(cmd_json, "width");
      const cJSON *height = cJSON_GetObjectItemCaseSensitive(cmd_json, "height");
      const cJSON *length = cJSON_GetObjectItemCaseSensitive(cmd_json, "length");
      
      if (cJSON_IsNumber(color)) out_cmd->data.draw_cube.color = (rl_handle_t)color->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_cube.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_cube.y = (float)y->valuedouble;
      if (cJSON_IsNumber(z)) out_cmd->data.draw_cube.z = (float)z->valuedouble;
      if (cJSON_IsNumber(width)) out_cmd->data.draw_cube.width = (float)width->valuedouble;
      if (cJSON_IsNumber(height)) out_cmd->data.draw_cube.height = (float)height->valuedouble;
      if (cJSON_IsNumber(length)) out_cmd->data.draw_cube.length = (float)length->valuedouble;
      break;
    }
    
    case RL_MODULE_FRAME_CMD_DRAW_GROUND_TEXTURE: {
      const cJSON *texture = cJSON_GetObjectItemCaseSensitive(cmd_json, "texture");
      const cJSON *tint = cJSON_GetObjectItemCaseSensitive(cmd_json, "tint");
      const cJSON *x = cJSON_GetObjectItemCaseSensitive(cmd_json, "x");
      const cJSON *y = cJSON_GetObjectItemCaseSensitive(cmd_json, "y");
      const cJSON *z = cJSON_GetObjectItemCaseSensitive(cmd_json, "z");
      const cJSON *width = cJSON_GetObjectItemCaseSensitive(cmd_json, "width");
      const cJSON *length = cJSON_GetObjectItemCaseSensitive(cmd_json, "length");
      
      if (cJSON_IsNumber(texture)) out_cmd->data.draw_ground_texture.texture = (rl_handle_t)texture->valueint;
      if (cJSON_IsNumber(tint)) out_cmd->data.draw_ground_texture.tint = (rl_handle_t)tint->valueint;
      if (cJSON_IsNumber(x)) out_cmd->data.draw_ground_texture.x = (float)x->valuedouble;
      if (cJSON_IsNumber(y)) out_cmd->data.draw_ground_texture.y = (float)y->valuedouble;
      if (cJSON_IsNumber(z)) out_cmd->data.draw_ground_texture.z = (float)z->valuedouble;
      if (cJSON_IsNumber(width)) out_cmd->data.draw_ground_texture.width = (float)width->valuedouble;
      if (cJSON_IsNumber(length)) out_cmd->data.draw_ground_texture.length = (float)length->valuedouble;
      break;
    }
    
    default:
      return -1;
  }
  
  return 0;
}

static int parse_frame_object(const cJSON *json_obj, rl_ws_frame_data_t *out_frame) {
  const cJSON *frame_number = NULL;
  const cJSON *delta_time = NULL;
  const cJSON *commands = NULL;
  const cJSON *cmd_json = NULL;
  int cmd_count = 0;
  int i = 0;
  
  if (json_obj == NULL || out_frame == NULL) {
    return -1;
  }
  
  memset(out_frame, 0, sizeof(rl_ws_frame_data_t));
  
  frame_number = cJSON_GetObjectItemCaseSensitive(json_obj, "frameNumber");
  if (cJSON_IsNumber(frame_number)) {
    out_frame->frame_number = frame_number->valueint;
  }
  
  delta_time = cJSON_GetObjectItemCaseSensitive(json_obj, "deltaTime");
  if (cJSON_IsNumber(delta_time)) {
    out_frame->delta_time = (float)delta_time->valuedouble;
  }
  
  commands = cJSON_GetObjectItemCaseSensitive(json_obj, "commands");
  if (!cJSON_IsArray(commands)) {
    return -1;
  }
  
  cmd_count = cJSON_GetArraySize(commands);
  if (cmd_count > RL_FRAME_COMMAND_CAPACITY) {
    cmd_count = RL_FRAME_COMMAND_CAPACITY;
  }
  
  i = 0;
  cJSON_ArrayForEach(cmd_json, commands) {
    if (i >= cmd_count) {
      break;
    }
    
    if (parse_command(cmd_json, &out_frame->commands.commands[i]) == 0) {
      i++;
    }
  }
  
  out_frame->commands.count = i;
  return 0;
}

static int parse_resource_request(const cJSON *req_json, rl_resource_request_t *out) {
  const cJSON *rid = NULL;
  const cJSON *type = NULL;
  
  if (req_json == NULL || out == NULL) {
    return -1;
  }
  
  rid = cJSON_GetObjectItem(req_json, "rid");
  type = cJSON_GetObjectItem(req_json, "type");
  
  if (!cJSON_IsNumber(rid) || !cJSON_IsNumber(type)) {
    return -1;
  }
  
  memset(out, 0, sizeof(rl_resource_request_t));
  out->rid = (uint32_t)rid->valueint;
  out->type = (rl_resource_request_type_t)type->valueint;
  
  switch (out->type) {
    case RL_RESOURCE_REQUEST_CREATE_COLOR: {
      const cJSON *r = cJSON_GetObjectItem(req_json, "r");
      const cJSON *g = cJSON_GetObjectItem(req_json, "g");
      const cJSON *b = cJSON_GetObjectItem(req_json, "b");
      const cJSON *a = cJSON_GetObjectItem(req_json, "a");
      if (!cJSON_IsNumber(r) || !cJSON_IsNumber(g) ||
          !cJSON_IsNumber(b) || !cJSON_IsNumber(a)) {
        return -1;
      }
      out->data.create_color.r = r->valueint;
      out->data.create_color.g = g->valueint;
      out->data.create_color.b = b->valueint;
      out->data.create_color.a = a->valueint;
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_CAMERA3D: {
      const cJSON *posX = cJSON_GetObjectItem(req_json, "posX");
      const cJSON *posY = cJSON_GetObjectItem(req_json, "posY");
      const cJSON *posZ = cJSON_GetObjectItem(req_json, "posZ");
      const cJSON *targetX = cJSON_GetObjectItem(req_json, "targetX");
      const cJSON *targetY = cJSON_GetObjectItem(req_json, "targetY");
      const cJSON *targetZ = cJSON_GetObjectItem(req_json, "targetZ");
      const cJSON *upX = cJSON_GetObjectItem(req_json, "upX");
      const cJSON *upY = cJSON_GetObjectItem(req_json, "upY");
      const cJSON *upZ = cJSON_GetObjectItem(req_json, "upZ");
      const cJSON *fovy = cJSON_GetObjectItem(req_json, "fovy");
      const cJSON *projection = cJSON_GetObjectItem(req_json, "projection");
      if (!cJSON_IsNumber(posX) || !cJSON_IsNumber(posY) || !cJSON_IsNumber(posZ) ||
          !cJSON_IsNumber(targetX) || !cJSON_IsNumber(targetY) || !cJSON_IsNumber(targetZ) ||
          !cJSON_IsNumber(upX) || !cJSON_IsNumber(upY) || !cJSON_IsNumber(upZ) ||
          !cJSON_IsNumber(fovy) || !cJSON_IsNumber(projection)) {
        return -1;
      }
      out->data.create_camera3d.posX = (float)posX->valuedouble;
      out->data.create_camera3d.posY = (float)posY->valuedouble;
      out->data.create_camera3d.posZ = (float)posZ->valuedouble;
      out->data.create_camera3d.targetX = (float)targetX->valuedouble;
      out->data.create_camera3d.targetY = (float)targetY->valuedouble;
      out->data.create_camera3d.targetZ = (float)targetZ->valuedouble;
      out->data.create_camera3d.upX = (float)upX->valuedouble;
      out->data.create_camera3d.upY = (float)upY->valuedouble;
      out->data.create_camera3d.upZ = (float)upZ->valuedouble;
      out->data.create_camera3d.fovy = (float)fovy->valuedouble;
      out->data.create_camera3d.projection = projection->valueint;
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_FONT: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      const cJSON *fontSize = cJSON_GetObjectItem(req_json, "fontSize");
      if (!cJSON_IsString(filename) || !cJSON_IsNumber(fontSize)) {
        return -1;
      }
      snprintf(out->data.create_font.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      out->data.create_font.fontSize = (float)fontSize->valuedouble;
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_TEXTURE: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      if (!cJSON_IsString(filename)) return -1;
      snprintf(out->data.create_texture.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_MODEL: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      if (!cJSON_IsString(filename)) return -1;
      snprintf(out->data.create_model.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_SOUND: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      if (!cJSON_IsString(filename)) return -1;
      snprintf(out->data.create_sound.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_MUSIC: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      if (!cJSON_IsString(filename)) return -1;
      snprintf(out->data.create_music.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      break;
    }
    case RL_RESOURCE_REQUEST_CREATE_SPRITE3D: {
      const cJSON *filename = cJSON_GetObjectItem(req_json, "filename");
      if (!cJSON_IsString(filename)) return -1;
      snprintf(out->data.create_sprite3d.filename, RL_RESOURCE_REQUEST_MAX_FILENAME, "%s", filename->valuestring);
      break;
    }
    case RL_RESOURCE_REQUEST_DESTROY: {
      const cJSON *handle = cJSON_GetObjectItem(req_json, "handle");
      if (!cJSON_IsNumber(handle)) return -1;
      out->data.destroy.handle = (rl_handle_t)handle->valueint;
      break;
    }
    default:
      return -1;
  }
  
  return 0;
}

int rl_protocol_parse_message(const char *raw, int len,
                               rl_protocol_message_type_t *out_type,
                               rl_ws_frame_data_t *out_frame,
                               bool *out_has_frame,
                               rl_protocol_requests_t *out_requests) {
  cJSON *root = NULL;
  cJSON *type_obj = NULL;
  cJSON *frame_obj = NULL;
  cJSON *resource_requests = NULL;
  
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
  
  root = cJSON_ParseWithLength(raw, (size_t)len);
  if (root == NULL) {
    return -1;
  }

  type_obj = cJSON_GetObjectItemCaseSensitive(root, "type");
  if (!cJSON_IsString(type_obj) || type_obj->valuestring == NULL) {
    cJSON_Delete(root);
    return -1;
  }

  if (strcmp(type_obj->valuestring, "frame") == 0) {
    frame_obj = cJSON_GetObjectItemCaseSensitive(root, "frame");
    if (frame_obj == NULL || out_frame == NULL || parse_frame_object(frame_obj, out_frame) != 0) {
      cJSON_Delete(root);
      return -1;
    }
    if (out_type != NULL) {
      *out_type = RL_PROTOCOL_MESSAGE_FRAME;
    }
    if (out_has_frame != NULL) {
      *out_has_frame = true;
    }
  } else if (strcmp(type_obj->valuestring, "resourceRequests") == 0) {
    const cJSON *req_json = NULL;
    int count = 0;

    resource_requests = cJSON_GetObjectItemCaseSensitive(root, "resourceRequests");
    if (!cJSON_IsArray(resource_requests) || out_requests == NULL) {
      cJSON_Delete(root);
      return -1;
    }

    cJSON_ArrayForEach(req_json, resource_requests) {
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
    cJSON_Delete(root);
    return -1;
  }
  
  cJSON_Delete(root);
  return 0;
}

int rl_protocol_serialize_responses(const rl_resource_response_t *responses, int count,
                                     char *out_buf, int buf_size) {
  cJSON *root = NULL;
  cJSON *responses_array = NULL;
  char *json_str = NULL;
  int len = 0;
  int i = 0;
  
  if (responses == NULL || count <= 0 || out_buf == NULL || buf_size <= 0) {
    return -1;
  }
  
  root = cJSON_CreateObject();
  if (root == NULL) {
    return -1;
  }
  
  responses_array = cJSON_CreateArray();
  if (responses_array == NULL) {
    cJSON_Delete(root);
    return -1;
  }
  
  for (i = 0; i < count; i++) {
    cJSON *resp = cJSON_CreateObject();
    if (resp == NULL) {
      continue;
    }
    cJSON_AddNumberToObject(resp, "rid", responses[i].rid);
    cJSON_AddNumberToObject(resp, "handle", responses[i].handle);
    cJSON_AddBoolToObject(resp, "success", responses[i].success);
    cJSON_AddItemToArray(responses_array, resp);
  }
  
  cJSON_AddStringToObject(root, "type", "resourceResponses");
  cJSON_AddItemToObject(root, "resourceResponses", responses_array);
  
  json_str = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  
  if (json_str == NULL) {
    return -1;
  }
  
  len = (int)strlen(json_str);
  if (len >= buf_size) {
    cJSON_free(json_str);
    return -1;
  }
  
  memcpy(out_buf, json_str, len + 1);
  cJSON_free(json_str);
  return len;
}
