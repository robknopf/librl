#include "rl_model.h"
#include <math.h>
#include <raylib.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "exports.h"

#define MAX_MODELS 255
#define RL_MODEL_FRAMERATE                                                     \
  60.0f // Matches rmodels.c GLTF_FRAMERATE, but raylib does not expose that
        // constant publicly.

bool rl_model_is_valid_model(Model model) {
  return (model.meshCount > 0 && model.meshes != NULL);
}

bool rl_model_is_valid_model_strict(Model model) { return IsModelValid(model); }

static void rl_model_log_invalid_details(const char *filename, Model model) {
  fprintf(stderr, "Model validity check failed for %s\n", filename);
  fprintf(stderr, "  model.meshes != NULL: %s\n",
          model.meshes ? "true" : "false");
  fprintf(stderr, "  model.materials != NULL: %s\n",
          model.materials ? "true" : "false");
  fprintf(stderr, "  model.meshMaterial != NULL: %s\n",
          model.meshMaterial ? "true" : "false");
  fprintf(stderr, "  model.meshCount: %d\n", model.meshCount);
  fprintf(stderr, "  model.materialCount: %d\n", model.materialCount);

  if (!model.meshes || model.meshCount <= 0) {
    return;
  }

  for (int i = 0; i < model.meshCount; i++) {
    Mesh *mesh = &model.meshes[i];
    fprintf(stderr, "  mesh[%d]: vaoId=%u\n", i, mesh->vaoId);

    if (mesh->vertices != NULL && mesh->vboId[0] == 0)
      fprintf(stderr, "    missing VBO[0] vertices\n");
    if (mesh->texcoords != NULL && mesh->vboId[1] == 0)
      fprintf(stderr, "    missing VBO[1] texcoords\n");
    if (mesh->normals != NULL && mesh->vboId[2] == 0)
      fprintf(stderr, "    missing VBO[2] normals\n");
    if (mesh->colors != NULL && mesh->vboId[3] == 0)
      fprintf(stderr, "    missing VBO[3] colors\n");
    if (mesh->tangents != NULL && mesh->vboId[4] == 0)
      fprintf(stderr, "    missing VBO[4] tangents\n");
    if (mesh->texcoords2 != NULL && mesh->vboId[5] == 0)
      fprintf(stderr, "    missing VBO[5] texcoords2\n");
    if (mesh->indices != NULL && mesh->vboId[6] == 0)
      fprintf(stderr, "    missing VBO[6] indices\n");
    if (mesh->boneIndices != NULL && mesh->vboId[7] == 0)
      fprintf(stderr, "    missing VBO[7] boneIndices\n");
    if (mesh->boneWeights != NULL && mesh->vboId[8] == 0)
      fprintf(stderr, "    missing VBO[8] boneWeights\n");
  }
}

Color rl_color_get(rl_handle_t handle);
Model rl_model_get(rl_handle_t handle);
void rl_model_set(rl_handle_t handle, Model model);
Model rl_model_create_cube(void);

typedef struct {
  Model *model;
  ModelAnimation *animations;
  int animation_count;
  int selected_animation;
  float animation_time;
  float animation_speed;
  bool animation_loop;
  bool animation_playing;
} rl_model_instance_t;

// model handles map to concrete runtime instances (model + animation playback
// state)
rl_model_instance_t rl_model_instances[MAX_MODELS];

rl_handle_t rl_next_model_handle = 1;

static void rl_model_instance_reset(rl_model_instance_t *instance) {
  if (!instance) {
    return;
  }
  instance->model = NULL;
  instance->animations = NULL;
  instance->animation_count = 0;
  instance->selected_animation = -1;
  instance->animation_time = 0.0f;
  instance->animation_speed = 1.0f;
  instance->animation_loop = true;
  instance->animation_playing = false;
}

static rl_model_instance_t *rl_model_get_instance(rl_handle_t handle) {
  if (handle >= MAX_MODELS) {
    return NULL;
  }

  if (rl_model_instances[handle].model == NULL) {
    return NULL;
  }

  return &rl_model_instances[handle];
}

static void rl_model_unload_instance(rl_handle_t handle) {
  if (handle >= MAX_MODELS) {
    return;
  }

  rl_model_instance_t *instance = &rl_model_instances[handle];

  if (instance->animations != NULL && instance->animation_count > 0) {
    UnloadModelAnimations(instance->animations, instance->animation_count);
  }

  if (instance->model != NULL) {
    UnloadModel(*(instance->model));
    free(instance->model);
  }

  rl_model_instance_reset(instance);
}

static bool rl_model_prepare_animation_gpu_state(rl_model_instance_t *instance,
                                                 rl_handle_t handle) {
  if (instance == NULL || instance->model == NULL || !IsWindowReady()) {
    return false;
  }

  Model *model = instance->model;
  for (int m = 0; m < model->meshCount; m++) {
    Mesh *mesh = &model->meshes[m];

    // Skip non-skinned/animated meshes
    if ((mesh->boneWeights == NULL) || (mesh->boneIndices == NULL) ||
        (mesh->animVertices == NULL) || (mesh->animNormals == NULL))
      continue;

    if ((mesh->vboId == NULL) ||
        (mesh->vboId[SHADER_LOC_VERTEX_POSITION] == 0)) {
        fprintf(stderr,
                "WARNING: Skipping model animation, missing position VBO for "
                "handle %u mesh %d\n",
                handle, m);
      return false;
    }

    // Some web-imported meshes may lack a normal VBO while still carrying
    // normal pointers. Disable normal uploads for those meshes to avoid
    // rlUpdateVertexBuffer(..., id=0, ...).
    if ((mesh->normals != NULL) &&
        (mesh->vboId[SHADER_LOC_VERTEX_NORMAL] == 0)) {
        fprintf(stderr,
                "WARNING: Model animation normals disabled for handle %u mesh "
                "%d (missing normal VBO)\n",
                handle, m);
      mesh->normals = NULL;
    }
  }

  return true;
}

rl_handle_t rl_model_get_next_handle() {
  if (rl_next_model_handle >= MAX_MODELS) {
    fprintf(stderr, "ERROR: MAX_MODELS reached (%d)\n", rl_next_model_handle);
    return 0;
  }
  return rl_next_model_handle++;
}

RL_KEEP
rl_handle_t rl_model_create(const char *filename) {
  if (!IsWindowReady()) {
    fprintf(
        stderr,
        "ERROR: rl_model_create(%s) called before window/context is ready\n",
        filename);
    return 0;
  }

  // Load the requested model first.
  Model loaded_model = LoadModel(filename);
  if (!rl_model_is_valid_model(loaded_model)) {
    rl_model_log_invalid_details(filename, loaded_model);
    fprintf(stderr,
            "ERROR: Failed to load model (%s).  Substituting placeholder.\n",
            filename);
    UnloadModel(loaded_model);
    // Keep behavior deterministic for callers: provide a visible placeholder.
    loaded_model = rl_model_create_cube();
    rl_handle_t handle = rl_model_get_next_handle();
    if (handle == 0) {
      UnloadModel(loaded_model);
      return 0;
    }
    rl_model_instances[handle].model = malloc(sizeof(Model));
    *(rl_model_instances[handle].model) = loaded_model;
    rl_model_instances[handle].animations = NULL;
    rl_model_instances[handle].animation_count = 0;
    rl_model_instances[handle].selected_animation = -1;
    rl_model_instances[handle].animation_playing = false;
    return handle;
  }

  rl_handle_t handle = rl_model_get_next_handle();
  if (handle == 0) {
    UnloadModel(loaded_model);
    return 0;
  }
  rl_model_instances[handle].model = malloc(sizeof(Model));
  *(rl_model_instances[handle].model) = loaded_model;

  // Load optional animations bundled with the source file.
  int animation_count = 0;
  ModelAnimation *animations = LoadModelAnimations(filename, &animation_count);
  if (animations != NULL && animation_count > 0) {
    rl_model_instances[handle].animations = animations;
    rl_model_instances[handle].animation_count = animation_count;
    rl_model_instances[handle].selected_animation = 0;
    rl_model_instances[handle].animation_playing = true;
  } else {
    rl_model_instances[handle].animations = NULL;
    rl_model_instances[handle].animation_count = 0;
    rl_model_instances[handle].selected_animation = -1;
    rl_model_instances[handle].animation_playing = false;
  }

  printf("Loaded model: %s as handle: %d\n", filename, handle);
  return handle;
}

RL_KEEP
void rl_model_destroy(rl_handle_t handle) { rl_model_unload_instance(handle); }

RL_KEEP
int rl_model_animation_count(rl_handle_t handle) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return 0;
  }
  return instance->animation_count;
}

RL_KEEP
int rl_model_animation_frame_count(rl_handle_t handle, int animation_index) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return 0;
  }
  if (animation_index < 0 || animation_index >= instance->animation_count) {
    return 0;
  }
  return instance->animations[animation_index].keyframeCount;
}

RL_KEEP
void rl_model_animation_update(rl_handle_t handle, int animation_index,
                               int frame) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return;
  }
  if (animation_index < 0 || animation_index >= instance->animation_count) {
    return;
  }

  int frame_count = instance->animations[animation_index].keyframeCount;
  if (frame_count <= 0) {
    return;
  }
  if (!rl_model_prepare_animation_gpu_state(instance, handle)) {
    return;
  }

  // Keep frame in-bounds so callers can increment freely.
  int normalized_frame = frame % frame_count;
  if (normalized_frame < 0) {
    normalized_frame += frame_count;
  }

  UpdateModelAnimation(*(instance->model),
                       instance->animations[animation_index], normalized_frame);
  // keep manual update in sync with high-level animation state
  instance->selected_animation = animation_index;
  instance->animation_time = (float)normalized_frame;
  instance->animation_playing = true;
}

RL_KEEP
bool rl_model_set_animation(rl_handle_t handle, int animation_index) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL || instance->animation_count <= 0) {
    return false;
  }
  if (animation_index < 0 || animation_index >= instance->animation_count) {
    return false;
  }

  // Switch to a new clip and restart playback from frame 0.
  instance->selected_animation = animation_index;
  instance->animation_time = 0.0f;
  instance->animation_playing = true;
  // Defer GPU animation upload to the first animate/update tick.
  // Calling UpdateModelAnimation() here can run before mesh animation buffers
  // are ready on web.
  return true;
}

RL_KEEP
bool rl_model_set_animation_speed(rl_handle_t handle, float speed) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return false;
  }

  // Speed is a multiplier where 1.0 is normal playback at RL_MODEL_FRAMERATE.
  // <= 0 pauses animate().
  instance->animation_speed = speed;
  return true;
}

RL_KEEP
bool rl_model_set_animation_loop(rl_handle_t handle, bool should_loop) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return false;
  }

  instance->animation_loop = should_loop;
  return true;
}

RL_KEEP
bool rl_model_animate(rl_handle_t handle, float delta_seconds) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  int frame_count = 0;
  int frame = 0;

  // No-op conditions are expected and return 0 (no update applied).
  if (instance == NULL || instance->animation_count <= 0) {
    return false;
  }
  if (instance->selected_animation < 0 ||
      instance->selected_animation >= instance->animation_count) {
    return false;
  }
  if (!instance->animation_playing) {
    return false;
  }
  if (instance->animation_speed <= 0.0f || delta_seconds <= 0.0f) {
    return false;
  }

  frame_count =
      instance->animations[instance->selected_animation].keyframeCount;
  if (frame_count <= 0) {
    return false;
  }

  if (!rl_model_prepare_animation_gpu_state(instance, handle)) {
    return false;
  }

  // Advance timeline in frame units so we can feed UpdateModelAnimation() an
  // integer frame.
  instance->animation_time +=
      delta_seconds * (RL_MODEL_FRAMERATE * instance->animation_speed);

  if (instance->animation_loop) {
    // Keep fractional frame progress so low-delta updates still advance over
    // time.
    while (instance->animation_time >= (float)frame_count) {
      instance->animation_time -= (float)frame_count;
    }
    while (instance->animation_time < 0.0f) {
      instance->animation_time += (float)frame_count;
    }
    frame = (int)floorf(instance->animation_time);
  } else {
    frame = (int)floorf(instance->animation_time);
    // Non-looping clamps to the last frame and marks playback as stopped.
    if (frame >= frame_count) {
      frame = frame_count - 1;
      instance->animation_time = (float)frame;
      instance->animation_playing = false;
    } else if (frame < 0) {
      frame = 0;
      instance->animation_time = 0.0f;
    }
  }

  UpdateModelAnimation(*(instance->model),
                       instance->animations[instance->selected_animation],
                       frame);
  return true;
}

RL_KEEP
void rl_model_draw(rl_handle_t handle, float position_x, float position_y,
                   float position_z, float scale, rl_handle_t tint) {
  Model model = rl_model_get(handle);
  Color color = rl_color_get(tint);
  DrawModel(model, (Vector3){position_x, position_y, position_z}, scale, color);
}

RL_KEEP
bool rl_model_is_valid(rl_handle_t handle) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return false;
  }
  return rl_model_is_valid_model(*(instance->model));
}

RL_KEEP
bool rl_model_is_valid_strict(rl_handle_t handle) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    return false;
  }
  return rl_model_is_valid_model_strict(*(instance->model));
}

void rl_model_set(rl_handle_t handle, Model model) {
  if (handle >= MAX_MODELS) {
    return;
  }

  if (rl_model_instances[handle].model != NULL) {
    rl_model_unload_instance(handle);
  }

  rl_model_instances[handle].model = malloc(sizeof(Model));
  *(rl_model_instances[handle].model) = model;
}

Model rl_model_get(rl_handle_t handle) {
  rl_model_instance_t *instance = rl_model_get_instance(handle);
  if (instance == NULL) {
    fprintf(stderr, "ERROR: Invalid model handle (%d)\n", handle);
    return (Model){0};
  }
  return *(instance->model);
}

Model rl_model_create_cube() {
  Image checked = GenImageChecked(2, 2, 1, 1, MAGENTA, BLACK);
  Texture2D texture = LoadTextureFromImage(checked);
  UnloadImage(checked);

  Mesh cube_mesh = GenMeshCube(1.0f, 1.0f, 1.0f);
  Model cube_model = LoadModelFromMesh(cube_mesh);
  cube_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = texture;

  return cube_model;
}

void rl_model_init() {
  // init our model handles
  for (int i = 0; i < MAX_MODELS; i++) {
    rl_model_instance_reset(&rl_model_instances[i]);
  }
  rl_next_model_handle = 1;
}

void rl_model_deinit() {
  int models_freed = 0;
  for (rl_handle_t i = 0; i < MAX_MODELS; i++) {
    if (rl_model_instances[i].model != NULL) {
      rl_model_unload_instance(i);
      models_freed++;
    }
  }
  rl_next_model_handle = 0;

  printf("rl_model_deinit: Freed %d models\n", models_freed);
}
