# RL Loader Sync Fetch Plan

This note captures how `librl` should adopt the new `wgutils` sync fetch APIs, especially `fetch_url_sync()` and `fetch_url_with_path_sync()`.

## Current State

`rl_loader` is still fundamentally poll-based.

Today it coordinates two separate async concerns:

- IDBFS restore readiness through `fileio_restore_async()` and `fileio_sync_poll()` / `fileio_sync_finish()`
- network fetch completion through `fetch_url_with_path_async()` and `fetch_url_poll()` / `fetch_url_finish()`

That means the loader state machine is currently doing two jobs:

- waiting for local filesystem/cache readiness
- waiting for network fetches to complete

The new sync fetch path only solves the second problem.

## Goal

Use `fetch_url_with_path_sync()` inside `rl_loader` to simplify fetch-related loader states without throwing away the task model that still matters for filesystem restore and batch orchestration.

## Non-Goal

Do not rewrite the whole loader around a fully synchronous lifecycle right away.

In particular:

- keep the restore barrier async for now
- do not replace batch task orchestration unless there is a clear benefit
- do not add spin-loop wrappers around existing async APIs

## Why `rl_loader` Is The Right Place

The current fetch state machine is centered in `rl_loader`:

- `rl_loader_start_fetch()`
- `rl_loader_poll_task()`
- `RL_LOADER_PREPARE_STATE_FETCHING_ROOT`
- `RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY`

That makes `rl_loader` the natural integration point for the new sync helper.

## Proposed Refactor

### 1. Keep restore polling intact

The restore barrier should remain as-is for the first pass:

- `rl_loader_restore_barrier_poll()`
- `fileio_restore_async()`
- `fileio_sync_poll()`
- `fileio_sync_finish()`

Reason:

- JSPI fetch does not solve IDBFS restore readiness
- this keeps the initial change set narrow

### 2. Introduce a sync fetch helper inside `rl_loader`

Add an internal helper that performs one fetch immediately and returns a completed result:

- likely `rl_loader_fetch_now(...)`
- or similar naming that makes the synchronous behavior explicit

This helper should:

- resolve `host + relative path`
- call `fetch_url_with_path_sync()`
- forward the result into existing completion logic

### 3. Reuse the existing fetch completion path

Avoid duplicating post-fetch behavior.

The sync helper should still route through the existing write/cache handling:

- write fetched bytes to local cache storage
- update in-memory cache when appropriate
- preserve current error handling semantics

That likely means reusing or slightly reshaping:

- `rl_loader_handle_fetch_completion()`

### 4. Convert single-asset import flow first

Current shape:

- if file exists locally, complete immediately
- otherwise enter `FETCHING_ROOT`
- later poll fetch until completion

Target shape:

- if file exists locally, complete immediately
- otherwise run `fetch_url_with_path_sync()`
- immediately write/cache result
- complete task in the same poll tick once restore is ready

This is the safest first migration because it avoids glTF dependency behavior initially.

### 5. Convert glTF root fetch next

For `.gltf` root files:

- fetch root synchronously when missing
- parse immediately once fetched
- continue dependency discovery without a fetch wait state

This should remove the need for the root fetch to be split across multiple task polls.

### 6. Convert dependency fetches after root parsing

Once dependency paths are known:

- skip local files as today
- synchronously fetch missing dependency files one at a time
- write/cache each one immediately

This should eliminate:

- `RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY`

or reduce it to transitional scaffolding during refactor.

### 7. Keep batch imports task-based

Batch import tasks still provide value:

- one caller-visible unit of work
- one child asset at a time
- natural place for status/progress reporting

So `RL_LOADER_TASK_KIND_IMPORT_ASSETS` can remain, even if each child asset becomes mostly synchronous once restore is ready.

### 8. Remove dead async fetch state once migration is complete

After the refactor, reevaluate whether these are still needed:

- `fetch_url_op_t *fetch_op` in `rl_loader_task_t`
- `RL_LOADER_PREPARE_STATE_FETCHING_ROOT`
- `RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY`
- fetch-specific branches in `rl_loader_poll_task()`

The desired end state is a smaller task structure and fewer fetch-related branches.

## JSPI / WASM Requirements

If `rl_loader` uses sync fetch on wasm, any wasm target that can reach that path must be linked with:

- `-s JSPI=1`

And any exported function that can reach that path must be included in:

- `-s JSPI_EXPORTS=[...]`

This needs to be checked at the `librl` build boundary, not only in `wgutils`.

In practice, this means we must audit:

- wasm example builds
- wasm library exports
- any bindings or runners that can trigger loader-based imports

## Rollout Strategy

Recommended order:

1. Add an internal sync fetch helper to `rl_loader`.
2. Convert single-file import path.
3. Convert `.gltf` root fetch path.
4. Convert dependency fetch path.
5. Remove dead async fetch task state and fields.
6. Audit wasm JSPI export requirements.
7. Re-run desktop and wasm loader tests.

## Test Plan

### Desktop

Verify:

- single asset import still works
- `.gltf` root fetch still works
- `.gltf` dependency fetch still works
- batch imports still work
- cache hits still short-circuit correctly

### WASM

Verify:

- JSPI-enabled loader import path works end to end
- restore barrier behavior remains correct
- cache restore + network fallback still behaves correctly
- existing wasm smoke tests still pass

### Regression Focus

Pay attention to:

- memory cache behavior for `.glb`, `.gltf`, `.png`, font assets
- path resolution for dependency URIs
- behavior when fetch fails after restore succeeds
- behavior when restore times out and loader falls back to network

## Open Questions

These should be answered during implementation:

1. Should sync fetch be used unconditionally in `rl_loader`, or only in JSPI-enabled wasm targets?
2. Should desktop also use the sync helper in `rl_loader`, for symmetry?
3. Do we want to preserve any incremental/progress reporting semantics before removing fetch states?
4. Are any public APIs or bindings relying on the current fetch-op-driven task timing?

## Expected Outcome

If this plan is followed, `rl_loader` should end up with:

- a simpler fetch path
- fewer task states
- less fetch-op lifecycle plumbing
- preserved restore/task orchestration where it still matters

That gives us the benefit of `fetch_url_with_path_sync()` without overcorrecting and rewriting the whole loader model at once.
