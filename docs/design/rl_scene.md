# rl_scene design

Design notes for a **retained-mode scene layer** on top of librl’s handle-based resources. This document captures direction from architecture discussion (Raylib today, optional Defold-style backends later, Haxe/cppia gameplay). **Not implemented yet** — use this as the contract when prototyping.

**Related:** [API.md](../API.md), [rl_handle.h](../../include/rl_handle.h), [ROADMAP.md](../ROADMAP.md) (Research), [MAINTAINER.md](../MAINTAINER.md) (scripting / per-frame contract), `examples/cppia/` (Haxe host + cppia reload).

---

## Problem

Today, drawable resources are **retained instances** (transform, tint, texture/asset on the handle), but **presentation is immediate-mode**: gameplay calls `rl_model_draw`, `rl_sprite3d_draw`, etc. each frame.

That fits Raylib, but it:

- Scatters draw calls across script code.
- Makes a second backend (e.g. Defold native extension syncing game objects) awkward.
- Duplicates “what is in the world” vs “what we draw this frame.”

`rl_scene` is a **membership list + flush/sync** layer: scripts mutate handles and scene membership; the backend presents once per frame.

---

## Goals

| Goal | Notes |
|------|--------|
| **Same gameplay API** across Raylib and future backends | Create/destroy handles, `rl_*_set_*` on instances, scene add/remove. |
| **Raylib path** | `rl_scene_draw` → iterate members → existing draw implementations (batch immediate mode). |
| **Defold path** (future) | `rl_scene_sync` → create/update/delete engine objects from dirty handles; no `Draw*` in script. |
| **Haxe / cppia** | Script mutates handles + scene; host/extension calls draw/sync. |
| **Pick / culling** (later) | Scene membership is a natural broadphase set. |

## Non-goals (initial prototype)

- Replacing Defold collections, messages, or GUI as the level editor.
- A full scene graph (parent/child transforms) — only ordered membership + per-handle transforms unless we add hierarchy later.
- Changing handle wire format again without an explicit API review.

---

## Handles (current baseline)

`rl_handle_t` is 32-bit, **MSB → LSB: kind (6) | generation (10) | index (16)**. See `include/rl_handle.h` and `src/internal/rl_handle_pool.h`.

- Each subsystem pool stamps a fixed `rl_handle_kind_t` at init.
- `rl_handle_get_kind()` decodes the high bits; wrong-kind handles do not resolve in another pool.
- **Scene dispatch** can branch on `rl_handle_get_kind(handle)` without a separate registry.

Builtin constants (colors, default camera/font) use the same encoding; numeric handle values are **not** stable across the pre-kind era.

---

## Layering

```
┌─────────────────────────────────────────┐
│  Haxe / cppia gameplay                  │
│  create handles, set props, scene add/  │
│  remove, optional onLoad/onUnload stash │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│  librl core                               │
│  handle pools + instance state            │
│  rl_scene (membership, order, camera)     │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
  rl_scene_draw()     rl_scene_sync()
  (Raylib)            (Defold / other)
  immediate batch     GO / factory map
```

**Gameplay** should not call `rl_*_draw` in the normal path once scene is adopted; keep draw APIs as **escape hatches** (debug, one-offs).

---

## Proposed C API (sketch)

Scene itself is a handle (`RL_HANDLE_KIND_SCENE` — reserve a kind id when implementing).

```c
rl_handle_t rl_scene_create(void);
void        rl_scene_destroy(rl_handle_t scene);

bool rl_scene_add(rl_handle_t scene, rl_handle_t drawable, int layer);
bool rl_scene_remove(rl_handle_t scene, rl_handle_t drawable);
void rl_scene_clear(rl_handle_t scene);

void rl_scene_set_active_camera(rl_handle_t scene, rl_handle_t camera);

void rl_scene_draw(rl_handle_t scene);   /* Raylib: flush to screen */
void rl_scene_sync(rl_handle_t scene);   /* Defold: sync engine objects; no-op on Raylib */
```

**Membership record** (internal): drawable handle, kind (redundant but useful for validation), layer, stable sort key / insertion order.

**Draw order:** layers ascending; stable order within layer (transparency-sensitive).

**Camera:** scene-level active camera handle; pick and draw should agree on the same camera for that scene.

---

## Drawable kinds (v1)

Initial scene members (dispatch targets):

| Kind | Instance state (already on handle) | Present |
|------|-----------------------------------|---------|
| `RL_HANDLE_KIND_MODEL` | transform, tint, animation | `rl_model_draw` / Defold model |
| `RL_HANDLE_KIND_SPRITE3D` | transform, tint, texture | billboard path |
| `RL_HANDLE_KIND_SPRITE2D` | transform, tint, texture | 2D sprite |
| `RL_HANDLE_KIND_TEXT2D` | font, text, position, … | text draw |

Defer or keep out of v1: `COLOR` (not drawn), `SOUND` / `MUSIC` (audio graph, not scene draw), `TEXTURE` alone (unless drawn as quad helper).

---

## Raylib backend (`rl_scene_draw`)

1. Resolve scene; get active camera → `rl_camera3d_set_active` (or equivalent).
2. `rl_render_begin` / mode 3d as today.
3. For each member in order: `switch (rl_handle_get_kind(h))` → call existing draw path.
4. `rl_render_end`.

Optional later: frustum cull using scene membership (see ROADMAP picking notes).

**Relation to remote frame buffer:** `examples/remote/include/rl_frame_command.h` records **per-frame commands**; scene is **stable membership** until add/remove. Different concepts; do not conflate.

---

## Defold backend (`rl_scene_sync`) — future

- Maintain **handle → engine id** map in the extension (not in `rl_handle_t`).
- On dirty transform/tint/asset: update GO / factory instance.
- On remove: delete GO; on handle destroy: remove from scene automatically.
- Extension `update` calls `rl_scene_sync` after script tick; Defold renders the world.

Script stays handle-centric; cppia reload stashes scene membership, not Defold ids.

---

## Haxe / cppia integration

Align with existing host contract (`examples/cppia/ScriptableMain`, `_rt_*` / `onTick`):

1. **Host** `onTick`: input, `rl_tick`, script `onTick`, then **`rl_scene_draw(active_scene)`** (Raylib) or **`rl_scene_sync`** (Defold).
2. **Script** creates resources, sets transforms, `scene.add(modelHandle)`, moves via `rl_model_set_transform`, etc.
3. **Hot reload:** `onUnload` returns stash (e.g. list of `{ kind, handle }` or opaque scene handle if scenes survive reload). `onLoad` rebuilds membership. Handles remain valid only if generation still matches; prefer rebuilding scene from stash after reload.

Do not use Lua as the gameplay springboard for this path; Lua remains reference / thin-host only per scripting strategy in ROADMAP.

---

## Lifecycle rules

- **Destroy handle** → auto-remove from every scene that holds it (or assert if caller must remove first — pick one policy and document).
- **Invalid / stale handle** → skip or warn in draw/sync; do not crash the loop.
- **`rl_deinit`** → destroys all scenes and resources (consistent with global deinit today).

---

## Implementation phases

1. **Raylib-only prototype** — `rl_scene_*` + `rl_scene_draw`; port one example (`c-simple` or `examples/cppia` MainScript) to scene-only rendering.
2. **Dirty flags** — mark instances dirty on `set_transform` / `set_tint`; scene tracks dirty members for future sync.
3. **Pick broadphase** — optional `rl_pick_*` against scene members.
4. **Defold extension** — `rl_scene_sync` stub on Raylib (no-op), real impl in native extension; one drawable kind end-to-end first.

---

## Open questions

- Scene handle kind id and max scenes per runtime.
- Whether `rl_scene_remove(scene, h)` requires matching kind when index collisions across pools are impossible (same numeric handle, different kind) — `rl_handle_get_kind` makes remove unambiguous.
- Text2d / GUI: same scene or parallel “UI layer” API.
- Audio: scene membership vs direct play calls.

---

## Using this doc in Cursor

In the IDE, reference this file when starting scene work:

```text
@docs/design/rl_scene.md @include/rl_handle.h Implement phase 1 (Raylib rl_scene_draw only)…
```

Optionally add a one-line pointer in `.cursor/rules` or ROADMAP Research so agents discover it without pasting the cloud thread.
