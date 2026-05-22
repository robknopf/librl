#!/usr/bin/env python3
"""One-shot rename: fileio* public API -> fs* / asset* across bindings, tests, examples."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Order: longest / most specific first.
HAXE_RENAMES = [
    ("fileioEnsureGroupAsync", "assetEnsureGroupAsync"),
    ("fileioPingAssetHost", "assetPingHost"),
    ("fileioSetAssetHost", "assetSetHost"),
    ("fileioGetAssetHost", "assetGetHost"),
    ("fileioCreateTaskGroup", "assetCreateTaskGroup"),
    ("fileioEnsureAsync", "assetEnsureAsync"),
    ("fileioGetTaskPath", "assetGetTaskPath"),
    ("fileioFinishTask", "assetFinishTask"),
    ("fileioTaskIsValid", "assetTaskIsValid"),
    ("fileioTaskInvalid", "assetTaskInvalid"),
    ("fileioRestoreAsync", "fsRestoreAsync"),
    ("fileioIsInitialized", "fsIsInitialized"),
    ("fileioInitAsync", "fsInitAsync"),
    ("fileioFreeTask", "assetFreeTask"),
    ("fileioPollTask", "assetPollTask"),
    ("fileioGetBaseDir", "fsGetRootDir"),
    ("fileioDeinitAsync", "fsDeinitAsync"),
    ("fileioEnsure", "assetEnsure"),
    ("fileioAddTask", "assetAddTask"),
    ("fileioDeinit", "fsDeinit"),
    ("fileioExists", "fsExists"),
    ("fileioRemove", "fsRemove"),
    ("fileioClear", "fsClear"),
    ("fileioWrite", "fsWrite"),
    ("fileioMkdir", "fsMkdir"),
    ("fileioRmdir", "fsRmdir"),
    ("fileioIsReady", "fsIsReady"),
    ("fileioFlush", "fsFlush"),
    ("fileioInit", "fsInit"),
    ("fileioRead", "fsRead"),
    ("fileioTick", "assetTick"),
    ("FILEIO_ADD_TASK", "ASSET_ADD_TASK"),
]

LUA_RENAMES = [
    ("fileio_ensure_group_async", "asset_ensure_group_async"),
    ("fileio_ping_asset_host", "asset_ping_host"),
    ("fileio_set_asset_host", "asset_set_host"),
    ("fileio_get_asset_host", "asset_get_host"),
    ("fileio_create_task_group", "asset_create_task_group"),
    ("fileio_ensure_async", "asset_ensure_async"),
    ("fileio_get_task_path", "asset_get_task_path"),
    ("fileio_finish_task", "asset_finish_task"),
    ("fileio_restore_async", "fs_restore_async"),
    ("fileio_is_initialized", "fs_is_initialized"),
    ("fileio_init_async", "fs_init_async"),
    ("fileio_free_task", "asset_free_task"),
    ("fileio_poll_task", "asset_poll_task"),
    ("fileio_get_base_dir", "fs_get_root_dir"),
    ("fileio_deinit_async", "fs_deinit_async"),
    ("fileio_ensure", "asset_ensure"),
    ("fileio_add_task", "asset_add_task"),
    ("fileio_deinit", "fs_deinit"),
    ("fileio_exists", "fs_exists"),
    ("fileio_remove", "fs_remove"),
    ("fileio_clear", "fs_clear"),
    ("fileio_write", "fs_write"),
    ("fileio_mkdir", "fs_mkdir"),
    ("fileio_rmdir", "fs_rmdir"),
    ("fileio_is_ready", "fs_is_ready"),
    ("fileio_flush", "fs_flush"),
    ("fileio_init", "fs_init"),
    ("fileio_read", "fs_read"),
    ("fileio_tick", "asset_tick"),
    ("fileio_normalize_path", "fs_normalize_path"),
]

NIM_RENAMES = [
    ("fileioEnsureGroupAsync", "assetEnsureGroupAsync"),
    ("fileioPingAssetHost", "assetPingHost"),
    ("fileioSetAssetHost", "assetSetHost"),
    ("fileioGetAssetHost", "assetGetHost"),
    ("fileioCreateTaskGroup", "assetCreateTaskGroup"),
    ("fileioEnsureAsync", "assetEnsureAsync"),
    ("fileioGetTaskPath", "assetGetTaskPath"),
    ("fileioFinishTask", "assetFinishTask"),
    ("fileioTaskIsValid", "assetTaskIsValid"),
    ("fileioTaskInvalid", "assetTaskInvalid"),
    ("fileioRestoreAsync", "fsRestoreAsync"),
    ("fileioIsInitialized", "fsIsInitialized"),
    ("fileioInitAsync", "fsInitAsync"),
    ("fileioFreeTask", "assetFreeTask"),
    ("fileioPollTask", "assetPollTask"),
    ("fileioGetBaseDir", "fsGetRootDir"),
    ("fileioDeinitAsync", "fsDeinitAsync"),
    ("fileioEnsure", "assetEnsure"),
    ("fileioAddTask", "assetAddTask"),
    ("fileioDeinit", "fsDeinit"),
    ("fileioExists", "fsExists"),
    ("fileioRemove", "fsRemove"),
    ("fileioClear", "fsClear"),
    ("fileioWrite", "fsWrite"),
    ("fileioMkdir", "fsMkdir"),
    ("fileioRmdir", "fsRmdir"),
    ("fileioIsReady", "fsIsReady"),
    ("fileioFlush", "fsFlush"),
    ("fileioInit", "fsInit"),
    ("fileioRead", "fsRead"),
    ("fileioTick", "assetTick"),
    ("rl_fileio_finish_c", "rl_asset_finish_c"),
    ("rl_fileio_release_closure_task", "rl_asset_release_closure_task"),
    ("RLFileioClosureTask", "RLAssetClosureTask"),
]

INCLUDE_RENAMES = [
    ('#include "rl_fileio.h"', '#include "rl_fs.h"\n#include "rl_asset.h"'),
]

GLOBS = {
    "haxe": [
        "bindings/haxe/**/*.hx",
        "examples/**/*.hx",
        "tests/bindings/haxe/**/*.hx",
    ],
    "lua": [
        "examples/**/*.lua",
        "tests/bindings/lua/**/*.lua",
        "tests/bindings/lua/**/*.c",
    ],
    "nim": [
        "bindings/nim/**/*.nim",
        "examples/**/*.nim",
    ],
    "include": [
        "examples/**/*.c",
        "examples/**/*.h",
    ],
}


def apply_renames(text: str, pairs: list[tuple[str, str]]) -> str:
    for old, new in pairs:
        text = text.replace(old, new)
    return text


def iter_files(patterns: list[str]) -> list[Path]:
    out: list[Path] = []
    for pat in patterns:
        out.extend(ROOT.glob(pat))
    return sorted(set(out))


def main() -> int:
    counts = {"haxe": 0, "lua": 0, "nim": 0, "include": 0}

    for path in iter_files(GLOBS["haxe"]):
        old = path.read_text(encoding="utf-8")
        new = apply_renames(old, HAXE_RENAMES)
        if new != old:
            path.write_text(new, encoding="utf-8")
            counts["haxe"] += 1

    for path in iter_files(GLOBS["lua"]):
        old = path.read_text(encoding="utf-8")
        new = apply_renames(old, LUA_RENAMES)
        if new != old:
            path.write_text(new, encoding="utf-8")
            counts["lua"] += 1

    for path in iter_files(GLOBS["nim"]):
        old = path.read_text(encoding="utf-8")
        new = apply_renames(old, NIM_RENAMES)
        if new != old:
            path.write_text(new, encoding="utf-8")
            counts["nim"] += 1

    for path in iter_files(GLOBS["include"]):
        old = path.read_text(encoding="utf-8")
        new = apply_renames(old, INCLUDE_RENAMES)
        if new != old:
            path.write_text(new, encoding="utf-8")
            counts["include"] += 1

    print("Updated files:", counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
