# rl_scene design

Design notes for a **retained-mode scene layer** on top of librl’s handle-based resources. **Raylib prototype implemented** — see `include/rl_scene.h` and `examples/c-simple/`, `examples/nim-simple/`, `examples/cppia/`.

**Related:** [API.md](../API.md), [rl_handle.h](../../include/rl_handle.h), [ROADMAP.md](../ROADMAP.md) (Research), [MAINTAINER.md](../MAINTAINER.md) (scripting / per-frame contract), `examples/cppia/` (Haxe host + cppia reload).

**Out of scope here:** backend extraction (Raylib vs Defold vs JS/Three.js, etc.) — separate design doc when scene API is stable.

---

## Problem

Today, drawable resources are **retained instances** (transform, tint, texture/asset on the handle), but **presentation is immediate-mode**: gameplay calls `rl_model_draw`, `rl_sprite3d_draw`, etc. each frame.

That fits Raylib, but it:

- Scatters draw calls across script code.
- Makes a second backend awkward later.
- Duplicates “what is in the world” vs “what we draw this frame.”

`rl_scene` is a **membership list + flush** layer: scripts mutate handles and scene membership; presentation runs once per frame via `rl_scene_draw`.

---

## Goals

| Goal | Notes |
|------|--------|
| **Same gameplay API** across backends (when added) | Create/destroy handles, `rl_*_set_*` on instances, scene add/remove. |
| **Raylib path (v1)** | `rl_scene_draw` → bucket by handle kind → existing draw implementations. |
| **Haxe / cppia** | Script owns scene create/draw (same as immediate-mode today); host stays thin. |
| **Pick / culling** (later) | `rl_scene_pick` against scene members; scene is natural broadphase set. |

## Non-goals (initial prototype)

- Defold or any non-Raylib backend until scene API is settled.
- A full scene graph (parent/child transforms) — only ordered membership + per-handle transforms unless we add hierarchy later.
- Replacing level-editor or GUI tooling.

---

## Pre-pass: tint on instances only

Before scene work, **remove the tint argument from all `rl_*_draw` calls**. Tint is instance state set via `rl_*_set_tint` (or `rl_text2d_set_color` for text2d — already the pattern there).

| Drawable | Setter | Draw |
|----------|--------|------|
| `MODEL` | `rl_model_set_tint` | `rl_model_draw(handle)` |
| `SPRITE2D` | `rl_sprite2d_set_tint` | `rl_sprite2d_draw(handle)` |
| `SPRITE3D` | `rl_sprite3d_set_tint` | `rl_sprite3d_draw(handle)` |
| `TEXT2D` | `rl_text2d_set_color` | `rl_text2d_draw(handle)` (unchanged) |

When `tint_handle` is `0`, draw uses `rl_color_get(0)` → white (raylib `WHITE`). Call sites that previously passed `RL_COLOR_RAYWHITE` at draw time should call `set_tint` once after create.

---

## Handles (kind layout)

`rl_handle_t` is 32-bit, **MSB → LSB: kind (6) | generation (10) | index (16)**. See `include/rl_handle.h` and `src/internal/rl_handle_pool.h`.

Reserved layout (draw-related kinds grouped; internal kinds at higher ids):

| Kind | Id | Notes |
|------|-----|--------|
| … existing 1–11 … | | COLOR through TEXT2D |
| `RL_HANDLE_KIND_SCENE` | 12 | Scene membership container |
| *(reserved)* | 13–31 | Future drawable / presentation kinds |
| `RL_HANDLE_KIND_ASSET_TASK` | 32 | Internal; moved out of drawable sequence |

- Each subsystem pool stamps a fixed `rl_handle_kind_t` at init.
- `rl_handle_get_kind()` decodes the high bits; scene dispatch branches on kind without a separate registry.

---

## Layering

```
┌─────────────────────────────────────────┐
│  Gameplay (c-simple, cppia MainScript)  │
│  create handles, set props, scene add/  │
│  remove; rl_scene_draw / rl_scene_pick  │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│  librl core                               │
│  handle pools + instance state            │
│  rl_scene (membership, order, camera)     │
└─────────────────┬───────────────────────┘
                  │
                  ▼
            rl_scene_draw()  (Raylib v1)
            iterate members → rl_*_draw()
```

**Gameplay** should not call `rl_*_draw` in the normal path once scene is adopted; keep draw APIs as **escape hatches** (debug, one-offs).

Scene creation is **optional** — callers without a scene keep immediate-mode draw until they migrate.

---

## Proposed C API (sketch)

Scene is a handle (`RL_HANDLE_KIND_SCENE`).

```c
rl_handle_t rl_scene_create(void);
void        rl_scene_destroy(rl_handle_t scene);

bool rl_scene_add(rl_handle_t scene, rl_handle_t drawable, int layer);
bool rl_scene_set_layer(rl_handle_t scene, rl_handle_t drawable, int layer);
bool rl_scene_remove(rl_handle_t scene, rl_handle_t drawable);
void rl_scene_clear(rl_handle_t scene);

void rl_scene_set_active_camera(rl_handle_t scene, rl_handle_t camera);

void rl_scene_draw(rl_handle_t scene);

rl_pick_result_t rl_scene_pick(rl_handle_t scene,
                               rl_handle_t camera,  /* 0 → active camera */
                               float mouse_x,
                               float mouse_y);
```

**Membership record** (internal): drawable handle, kind (for validation), layer, stable insertion order. **Visibility** and **pickability** live on the drawable instances (`rl_model_set_visible`, `rl_sprite3d_set_visible`, etc.); `rl_scene_draw` / `rl_scene_pick` may early-out using those flags, while `rl_*_draw` and `rl_pick_*` enforce the same rules when called directly.

**Draw order:** one `rl_scene_draw` owns the frame presentation pass. Internally, bucket/dispatch by `rl_handle_get_kind()`:

1. Resolve scene; set active camera from scene (or current if scene camera is `0`).
2. `rl_render_begin` / clear as today.
3. 3D kinds (`MODEL`, `SPRITE3D`): `rl_render_begin_mode_3d`, then for each **scene layer**:
   - draw opaque 3D contributions first
   - draw transparent 3D contributions second
4. 2D kinds (`SPRITE2D`, `TEXT2D`): draw each member whose instance is visible, in layer order (no 3D mode).
5. `rl_render_end`.

Layers ascend first; stable insertion order is the base tie-breaker within a layer. Transparent 3D items are additionally depth-sorted just before their pass. `SPRITE3D` contributes only to the transparent pass; `MODEL` may contribute to both passes based on per-mesh material alpha.

**Pick:** `rl_scene_pick` tests only **model** and **sprite3d** members whose instance **`pickable`** is true. Closest hit wins. Camera argument: explicit handle, or **`0` → currently active camera** (same rule for scene draw when scene has no camera set). *Note:* per-handle `rl_pick_model` / `rl_pick_sprite3d` today require a valid camera handle and do **not** fall back to active — scene pick adds that fallback.

## Drawable kinds (v1)

| Kind | Instance state | Draw dispatch |
|------|----------------|---------------|
| `RL_HANDLE_KIND_MODEL` | transform, tint, animation, **visible**, **pickable** | `rl_model_draw` |
| `RL_HANDLE_KIND_SPRITE3D` | transform, tint, texture, **visible**, **pickable** | `rl_sprite3d_draw` |
| `RL_HANDLE_KIND_SPRITE2D` | transform, tint, texture, **visible**, **pickable** | `rl_sprite2d_draw` |
| `RL_HANDLE_KIND_TEXT2D` | font, text, position, color, **visible**, **pickable** | `rl_text2d_draw` |

Defer v1: `COLOR`, `SOUND`, `MUSIC`, bare `TEXTURE`.

---

## Lifecycle rules

- **Destroy drawable handle** → **auto-remove** from every scene that holds it. `rl_scene_draw` / `rl_scene_sync` (future) skip invalid members and may log/warn — validation at present time, not only at remove.
- **Invalid / stale handle** in membership → skip in draw/pick; do not crash the loop.
- **`rl_deinit`** → destroys all scenes and resources (consistent with global deinit today).

---

## Haxe / cppia integration

Align with existing host contract (`examples/cppia/ScriptableMain`, `onTick`):

1. **Host** `onTick`: input, `rl_tick`, script `onTick` — **no** scene draw in the host.
2. **Script** (MainScript): creates scene if desired, mutates handles, `rl_scene_draw` / `rl_scene_pick` — same ownership as immediate-mode draw today.
3. **Hot reload:** `onUnload` stashes membership (handles + layers); `onLoad` rebuilds. Prefer rebuilding scene from stash; stale generations fail resolve and get skipped.

Port order: **`examples/c-simple` first**, then **`examples/nim-simple`**, then cppia MainScript.

---

## Implementation phases

1. **Tint pre-pass** — remove tint from `rl_*_draw`; update call sites and bindings.
2. **Raylib scene prototype** — `rl_scene_*` + `rl_scene_draw` + `rl_scene_pick`; port `c-simple`.
3. **Examples** — `c-simple`, `nim-simple`, cppia MainScript on scene path.
4. **Member layer updates** — `rl_scene_set_layer(scene, drawable, layer)` so gameplay can change draw order **without** `remove` + `add`; stable order within a layer unchanged; `rl_scene_draw` sorts each frame (same as before).
5. **Dirty flags** (optional) — for future backend sync; stub only until backend design exists.
6. **Pick broadphase** — scene-scoped cheap cull before narrow pick (`rl_scene_pick`): one camera + ray per query; world AABB (model) / sphere (sprite3d) matches per-member internal broadphase so narrow work is skipped when the ray misses the outer bounds.

---

## Resolved decisions (2026-05)

| Topic | Decision |
|-------|----------|
| Remove on destroy | Auto-remove; draw/pick validate/skip stale members |
| Draw scope | Single `rl_scene_draw`; internal kind bucketing for 3D vs 2D passes |
| Tint | Instance-only via setters; no tint on draw |
| Pick | `rl_scene_pick`; camera `0` → active camera |
| Scene kind id | `12`; `ASSET_TASK` → `32`; gap `13–31` |
| Who owns scene | Gameplay / script, not host |
| Backends | Deferred; separate backend-extraction design doc later |

---

## Next steps (not implemented)

- **Dirty flags** (optional) — for future backend sync; stub only until backend design exists.

---

## Implemented: scene pick broadphase

`rl_scene_pick` resolves the pick camera and **mouse ray once**, then culls each pickable member with the same outer bounds used inside `rl_pick_model` / `rl_pick_sprite3d` (world AABB from asset local bounds + instance transform; sprite billboard bounding sphere). Culled members skip narrow-phase mesh/quad tests and do not contribute to `rl_pick_*` stats for that query.

---

## Implemented: per-member layer + scene pass scheduling

`bool rl_scene_set_layer(rl_handle_t scene, rl_handle_t drawable, int layer)` updates the member’s **paint-order bucket** without remove/re-add. **`scene` + `drawable`** disambiguates when a drawable could theoretically appear in multiple scenes. Returns `false` if `drawable` is not a member of `scene`. Stable insertion order within a layer is preserved (tie-breaker after `layer` in `rl_scene_draw`).

`rl_scene_draw` now treats **layer** as grouping/z-order only. For each layer it runs:

1. opaque 3D pass
2. transparent 3D pass
3. final 2D pass after all 3D layers complete

The current transparent pass uses per-drawable camera-depth sorting with stable insertion order as the fallback tie-breaker. `Sprite3d` participates only in the transparent pass. `Model` can participate in both passes by splitting meshes/materials internally.

---

## Using this doc in Cursor

```text
@docs/design/rl_scene.md @include/rl_scene.h …
```
