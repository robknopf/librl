#include "rl_resource_handler.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_texture.h"
#include "rl_model.h"
#include "rl_sound.h"
#include "rl_music.h"
#include "rl_camera3d.h"
#include "rl_sprite3d.h"
#include "rl_logger.h"
#include <stdio.h>
#include <string.h>

static void tracked_slot_reset(rl_resource_handler_t *handler, int index) {
  if (handler == NULL || index < 0 || index >= RL_RESOURCE_HANDLER_MAX_TRACKED) {
    return;
  }

  handler->tracked[index].in_use = false;
  handler->tracked[index].type = 0;
  handler->tracked[index].handle = 0;
}

static int find_free_tracked_slot(rl_resource_handler_t *handler) {
  int i = 0;

  if (handler == NULL) {
    return -1;
  }

  for (i = 0; i < RL_RESOURCE_HANDLER_MAX_TRACKED; i++) {
    if (!handler->tracked[i].in_use) {
      return i;
    }
  }

  return -1;
}

static void track_created_handle(rl_resource_handler_t *handler,
                                 rl_resource_request_type_t type,
                                 rl_handle_t handle) {
  int index = 0;

  if (handler == NULL || handle == 0) {
    return;
  }

  index = find_free_tracked_slot(handler);
  if (index < 0) {
    log_warn("[ResourceHandler] No free tracked slots for handle %u",
             (unsigned int)handle);
    return;
  }

  handler->tracked[index].in_use = true;
  handler->tracked[index].type = type;
  handler->tracked[index].handle = handle;
}

static void destroy_handle_for_type(rl_resource_request_type_t type, rl_handle_t handle) {
  switch (type) {
    case RL_RESOURCE_REQUEST_CREATE_COLOR:
      rl_color_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_FONT:
      rl_font_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_TEXTURE:
      rl_texture_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_MODEL:
      rl_model_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_SOUND:
      rl_sound_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_MUSIC:
      rl_music_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_CAMERA3D:
      rl_camera3d_destroy(handle);
      break;
    case RL_RESOURCE_REQUEST_CREATE_SPRITE3D:
      rl_sprite3d_destroy(handle);
      break;
    default:
      break;
  }
}

static rl_handle_t process_create_color(const rl_resource_request_create_color_t *data) {
  return rl_color_create(data->r, data->g, data->b, data->a);
}

static rl_handle_t process_create_camera3d(const rl_resource_request_create_camera3d_t *data) {
  rl_handle_t handle = rl_camera3d_create(
    data->posX, data->posY, data->posZ,
    data->targetX, data->targetY, data->targetZ,
    data->upX, data->upY, data->upZ,
    data->fovy, data->projection
  );
  
  if (handle != 0) {
    rl_camera3d_set_active(handle);
  }
  
  return handle;
}

static rl_pending_resource_load_t *find_free_pending(rl_resource_handler_t *handler) {
  int i = 0;
  for (i = 0; i < RL_RESOURCE_HANDLER_MAX_PENDING; i++) {
    if (!handler->pending[i].in_use) {
      return &handler->pending[i];
    }
  }
  return NULL;
}

static bool start_async_load(rl_resource_handler_t *handler, uint32_t rid,
                              rl_resource_request_type_t type,
                              const char *filename, float size) {
  rl_pending_resource_load_t *pending = find_free_pending(handler);
  if (pending == NULL) {
    log_error("[ResourceHandler] No free pending slots");
    return false;
  }
  
  pending->loader_task = rl_loader_import_asset_async(filename);
  if (pending->loader_task == NULL) {
    log_error("[ResourceHandler] Failed to start loader for: %s", filename);
    return false;
  }
  
  pending->in_use = true;
  pending->rid = rid;
  pending->type = type;
  snprintf(pending->filename, sizeof(pending->filename), "%s", filename);
  pending->size = size;
  
  log_debug("[ResourceHandler] Started async load: %s (rid=%u)", filename, rid);
  return true;
}

static rl_handle_t create_handle_for_type(rl_resource_request_type_t type,
                                           const char *filename, float size) {
  switch (type) {
    case RL_RESOURCE_REQUEST_CREATE_FONT:
      return rl_font_create(filename, size);
    case RL_RESOURCE_REQUEST_CREATE_TEXTURE:
      return rl_texture_create(filename);
    case RL_RESOURCE_REQUEST_CREATE_MODEL:
      return rl_model_create(filename);
    case RL_RESOURCE_REQUEST_CREATE_SOUND:
      return rl_sound_create(filename);
    case RL_RESOURCE_REQUEST_CREATE_MUSIC:
      return rl_music_create(filename);
    case RL_RESOURCE_REQUEST_CREATE_SPRITE3D:
      return rl_sprite3d_create(filename);
    default:
      return 0;
  }
}

void rl_resource_handler_init(rl_resource_handler_t *handler) {
  if (handler == NULL) {
    return;
  }
  memset(handler, 0, sizeof(rl_resource_handler_t));
}

int rl_resource_handler_process_requests(rl_resource_handler_t *handler,
                                         const rl_resource_request_t *requests,
                                         int request_count,
                                         rl_resource_response_t *responses,
                                         int max_responses) {
  int count = 0;
  int i = 0;
  
  if (handler == NULL || requests == NULL || request_count <= 0 ||
      responses == NULL || max_responses <= 0) {
    return 0;
  }
  
  for (i = 0; i < request_count && count < max_responses; i++) {
    const rl_resource_request_t *req = &requests[i];
    rl_handle_t handle = 0;
    
    switch (req->type) {
      case RL_RESOURCE_REQUEST_CREATE_COLOR:
        handle = process_create_color(&req->data.create_color);
        responses[count].rid = req->rid;
        responses[count].handle = handle;
        responses[count].success = (handle != 0);
        if (handle != 0) {
          track_created_handle(handler, req->type, handle);
        }
        count++;
        break;
      case RL_RESOURCE_REQUEST_CREATE_CAMERA3D:
        handle = process_create_camera3d(&req->data.create_camera3d);
        responses[count].rid = req->rid;
        responses[count].handle = handle;
        responses[count].success = (handle != 0);
        if (handle != 0) {
          track_created_handle(handler, req->type, handle);
        }
        count++;
        break;
      case RL_RESOURCE_REQUEST_CREATE_FONT:
        if (!start_async_load(handler, req->rid, req->type,
                              req->data.create_font.filename,
                              req->data.create_font.fontSize)) {
          responses[count].rid = req->rid;
          responses[count].handle = 0;
          responses[count].success = false;
          count++;
        }
        break;
      case RL_RESOURCE_REQUEST_CREATE_TEXTURE:
      case RL_RESOURCE_REQUEST_CREATE_MODEL:
      case RL_RESOURCE_REQUEST_CREATE_SOUND:
      case RL_RESOURCE_REQUEST_CREATE_MUSIC:
      case RL_RESOURCE_REQUEST_CREATE_SPRITE3D: {
        const char *filename = NULL;
        switch (req->type) {
          case RL_RESOURCE_REQUEST_CREATE_TEXTURE:  filename = req->data.create_texture.filename; break;
          case RL_RESOURCE_REQUEST_CREATE_MODEL:    filename = req->data.create_model.filename;   break;
          case RL_RESOURCE_REQUEST_CREATE_SOUND:    filename = req->data.create_sound.filename;   break;
          case RL_RESOURCE_REQUEST_CREATE_MUSIC:    filename = req->data.create_music.filename;   break;
          case RL_RESOURCE_REQUEST_CREATE_SPRITE3D: filename = req->data.create_sprite3d.filename; break;
          default: break;
        }
        if (filename != NULL) {
          if (!start_async_load(handler, req->rid, req->type, filename, 0.0f)) {
            responses[count].rid = req->rid;
            responses[count].handle = 0;
            responses[count].success = false;
            count++;
          }
        }
        break;
      }
      case RL_RESOURCE_REQUEST_DESTROY:
        log_warn("[ResourceHandler] Warning: destroy not implemented yet (handle: %u)",
                 (unsigned int)req->data.destroy.handle);
        responses[count].rid = req->rid;
        responses[count].handle = 0;
        responses[count].success = true;
        count++;
        break;
      default:
        log_warn("[ResourceHandler] Unknown request type: %d", req->type);
        break;
    }
  }
  
  return count;
}

int rl_resource_handler_poll(rl_resource_handler_t *handler,
                              rl_resource_response_t *responses,
                              int max_responses) {
  int count = 0;
  int i = 0;
  
  if (handler == NULL || responses == NULL || max_responses <= 0) {
    return 0;
  }
  
  for (i = 0; i < RL_RESOURCE_HANDLER_MAX_PENDING; i++) {
    rl_pending_resource_load_t *pending = &handler->pending[i];
    int rc = 0;
    rl_handle_t handle = 0;
    
    if (!pending->in_use || pending->loader_task == NULL) {
      continue;
    }
    
    if (!rl_loader_poll_task(pending->loader_task)) {
      continue;
    }
    
    if (count >= max_responses) {
      break;
    }
    
    rc = rl_loader_finish_task(pending->loader_task);
    rl_loader_free_task(pending->loader_task);
    pending->loader_task = NULL;
    
    if (rc != 0) {
      log_error("[ResourceHandler] Loader failed for: %s", pending->filename);
      responses[count].rid = pending->rid;
      responses[count].handle = 0;
      responses[count].success = false;
      count++;
      pending->in_use = false;
      continue;
    }
    
    handle = create_handle_for_type(pending->type, pending->filename, pending->size);
    log_info("[ResourceHandler] Loaded %s -> handle %u", pending->filename, (unsigned int)handle);
    
    responses[count].rid = pending->rid;
    responses[count].handle = handle;
    responses[count].success = (handle != 0);
    if (handle != 0) {
      track_created_handle(handler, pending->type, handle);
    }
    count++;
    
    pending->in_use = false;
  }
  
  return count;
}

void rl_resource_handler_reset(rl_resource_handler_t *handler) {
  int i = 0;

  if (handler == NULL) {
    return;
  }

  for (i = 0; i < RL_RESOURCE_HANDLER_MAX_PENDING; i++) {
    if (handler->pending[i].in_use && handler->pending[i].loader_task != NULL) {
      rl_loader_free_task(handler->pending[i].loader_task);
    }
    handler->pending[i].in_use = false;
    handler->pending[i].loader_task = NULL;
  }

  for (i = RL_RESOURCE_HANDLER_MAX_TRACKED - 1; i >= 0; i--) {
    if (!handler->tracked[i].in_use || handler->tracked[i].handle == 0) {
      continue;
    }

    destroy_handle_for_type(handler->tracked[i].type, handler->tracked[i].handle);
    tracked_slot_reset(handler, i);
  }
}

void rl_resource_handler_cleanup(rl_resource_handler_t *handler) {
  rl_resource_handler_reset(handler);
}
