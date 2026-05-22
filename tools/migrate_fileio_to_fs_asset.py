#!/usr/bin/env python3
"""One-shot migration: rl_fileio_* -> rl_fs_* / rl_asset_* across the repo."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Order matters: longest / most specific first.
REPLACEMENTS = [
    ("rl_fileio_ensure_group_from_scratch_async", "rl_asset_ensure_many_from_scratch_async"),
    ("rl_fileio_ensure_group_async", "rl_asset_ensure_many_async"),
    ("RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL", "RL_ASSET_ADD_TASK_ERR_QUEUE_FULL"),
    ("RL_FILEIO_ADD_TASK_ERR_INVALID", "RL_ASSET_ADD_TASK_ERR_INVALID"),
    ("RL_FILEIO_ADD_TASK_OK", "RL_ASSET_ADD_TASK_OK"),
    ("rl_fileio_add_task_result_t", "rl_asset_add_task_result_t"),
    ("rl_fileio_callback_fn", "rl_asset_callback_fn"),
    ("rl_fileio_get_base_dir", "rl_fs_get_root_dir"),
    ("rl_fileio_set_asset_host", "rl_asset_set_host"),
    ("rl_fileio_get_asset_host", "rl_asset_get_host"),
    ("rl_fileio_ping_asset_host", "rl_asset_ping_host"),
    ("rl_fileio_is_initialized", "rl_fs_is_initialized"),
    ("rl_fileio_deinit_async", "rl_fs_deinit_async"),
    ("rl_fileio_init_async", "rl_fs_init_async"),
    ("rl_fileio_restore_async", "rl_fs_restore_async"),
    ("rl_fileio_normalize_path", "rl_fs_normalize_path"),
    ("rl_fileio_is_ready", "rl_fs_is_ready"),
    ("rl_fileio_read_free", "rl_fs_read_free"),
    ("rl_fileio_finish_task", "rl_asset_finish_task"),
    ("rl_fileio_get_task_path", "rl_asset_get_task_path"),
    ("rl_fileio_ensure_async", "rl_asset_ensure_async"),
    ("rl_fileio_poll_task", "rl_asset_poll_task"),
    ("rl_fileio_free_task", "rl_asset_free_task"),
    ("rl_fileio_add_task", "rl_asset_add_task"),
    ("rl_fileio_exists", "rl_fs_exists"),
    ("rl_fileio_remove", "rl_fs_remove"),
    ("rl_fileio_ensure", "rl_asset_ensure"),
    ("rl_fileio_deinit", "rl_fs_deinit"),
    ("rl_fileio_write", "rl_fs_write"),
    ("rl_fileio_mkdir", "rl_fs_mkdir"),
    ("rl_fileio_rmdir", "rl_fs_rmdir"),
    ("rl_fileio_clear", "rl_fs_clear"),
    ("rl_fileio_flush", "rl_fs_flush"),
    ("rl_fileio_read", "rl_fs_read"),
    ("rl_fileio_init", "rl_fs_init"),
    ("rl_fileio_tick", "rl_asset_tick"),
    ("rl_set_asset_host", "rl_asset_set_host"),
    ("rl_get_asset_host", "rl_asset_get_host"),
    ("fileio_base_dir", "fs_root_dir"),
    ("fileioBaseDir", "fsRootDir"),
]

# Static/state names in src/rl_fs.c — applied before public API pass on that file only.
INTERNAL_REPLACEMENTS = [
    ("rl_fileio_task_t", "rl_asset_task_t"),
    ("rl_fileio_task_entries", "rl_asset_task_entries"),
    ("rl_fileio_task_pool", "rl_asset_task_pool"),
    ("rl_fileio_task_free_indices", "rl_asset_task_free_indices"),
    ("rl_fileio_task_generations", "rl_asset_task_generations"),
    ("rl_fileio_task_occupied", "rl_asset_task_occupied"),
    ("rl_fileio_task_pool_ready", "rl_asset_task_pool_ready"),
    ("rl_fileio_asset_host", "rl_asset_host_buf"),
    ("rl_fileio_memory_cache", "rl_fs_memory_cache"),
    ("rl_fileio_restore_barrier", "rl_fs_restore_barrier"),
    ("rl_fileio_restore_ready", "rl_fs_restore_ready"),
    ("rl_fileio_restore_failed", "rl_fs_restore_failed"),
    ("rl_fileio_restore_started_at", "rl_fs_restore_started_at"),
    ("rl_fileio_initialized", "rl_fs_initialized"),
    ("rl_fileio_base_dir", "rl_fs_root_dir"),
    ("RL_FILEIO_DEFAULT_BASE_DIR", "RL_FS_DEFAULT_ROOT_DIR"),
    ("RL_FILEIO_MAX_ASSET_HOST_LENGTH", "RL_ASSET_MAX_HOST_LENGTH"),
    ("rl_fileio_wait_for_fileio_sync_js", "rl_fs_wait_for_idbfs_sync_js"),
    ("ensure_group_from_scratch_task_async_ptr", "ensure_many_from_scratch_task_async_ptr"),
    ("ensure_group_from_scratch_task_async", "ensure_many_from_scratch_task_async"),
]

SKIP_DIRS = {".git", ".emcache", "node_modules", "deps", "lib", "obj"}
SKIP_SUFFIXES = {".wasm", ".o", ".a", ".png", ".jpg", ".glb", ".gltf", ".cppia", ".zip"}


def should_process(path: Path) -> bool:
    if any(part in SKIP_DIRS for part in path.parts):
        return False
    if path.suffix in SKIP_SUFFIXES:
        return False
    if path.name == "migrate_fileio_to_fs_asset.py":
        return False
    return True


def migrate_text(text: str, extra: list[tuple[str, str]] | None = None) -> str:
    pairs = REPLACEMENTS + (extra or [])
    for old, new in pairs:
        text = text.replace(old, new)
    return text


def main() -> int:
    changed = 0
    fs_c = ROOT / "src" / "rl_fs.c"
    for path in ROOT.rglob("*"):
        if not path.is_file() or not should_process(path):
            continue
        try:
            original = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        extra = INTERNAL_REPLACEMENTS if path.name == "rl_fs.c" and path.parent.name == "src" else None
        updated = migrate_text(original, extra)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            changed += 1
            print(f"updated {path.relative_to(ROOT)}")
    print(f"done: {changed} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
