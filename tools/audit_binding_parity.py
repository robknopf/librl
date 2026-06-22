#!/usr/bin/env python3
"""Audit public C API coverage across JS, Haxe, Nim, and Lua bindings."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INCLUDE_DIR = ROOT / "include"
BINDINGS_DOC = ROOT / "docs" / "BINDINGS.md"

# Scratch bridge exports map to their semantic C API (JS wraps these; not gaps).
JS_SCRATCH_BRIDGE_TO_C = {
    "rl_window_get_screen_size_to_scratch": "rl_window_get_screen_size",
    "rl_window_get_position_to_scratch": "rl_window_get_position",
    "rl_window_get_monitor_position_to_scratch": "rl_window_get_monitor_position",
    "rl_text_measure_ex_to_scratch": "rl_text_measure_ex",
    "rl_pick_model_to_scratch": "rl_pick_model",
    "rl_pick_sprite3d_to_scratch": "rl_pick_sprite3d",
    "rl_pick_shape_to_scratch": "rl_pick_shape",
    "rl_pick_text3d_to_scratch": "rl_pick_text3d",
    "rl_text3d_get_bounds_to_scratch": "rl_text3d_get_bounds",
    "rl_scene_pick_to_scratch": "rl_scene_pick",
    "rl_asset_ensure_many_from_scratch_async": "rl_asset_ensure_many_async",
}

# Logger macros in API.md — not direct binding targets.
LOGGER_MACROS = {
    "rl_logger_trace",
    "rl_logger_debug",
    "rl_logger_info",
    "rl_logger_warn",
    "rl_logger_error",
    "rl_logger_fatal",
}

# Optional FFI-only helpers; track but de-prioritize in roadmap text.
FFI_INTERNAL: set[str] = set()

FN_RE = re.compile(r"\brl_[a-z0-9_]+\s*\(")
RL_SYM_RE = re.compile(r"\brl_[a-z0-9_]+\b")
HEADER_FN_RE = re.compile(r"\b(rl_[a-z0-9_]+)\s*\([^;{}]*\)\s*;")

HAXE_IMPL_SPECIAL_TO_C = {
    "init": "rl_init_values",
    "initAsync": "rl_init_values_async",
    "isInitialized": "rl_is_initialized",
    "getPlatform": "rl_get_platform",
    "handleKind": "rl_handle_get_kind",
    "versionMajor": "rl_version_major",
    "versionMinor": "rl_version_minor",
    "versionPatch": "rl_version_patch",
    "versionLabel": "rl_version_label",
    "versionNumber": "rl_version_number",
    "versionString": "rl_version_string",
    "fsRestoreAsync": "rl_fs_restore_async",
    "fsInit": "rl_fs_init",
    "fsInitAsync": "rl_fs_init_async",
    "fsDeinit": "rl_fs_deinit",
    "fsDeinitAsync": "rl_fs_deinit_async",
    "fsIsInitialized": "rl_fs_is_initialized",
    "fsIsReady": "rl_fs_is_ready",
    "fsFlush": "rl_fs_flush",
    "assetEnsureAsync": "rl_asset_ensure_async",
    "assetEnsure": "rl_asset_ensure",
    "assetEnsureGroupAsync": "rl_asset_ensure_many_async",
    "assetPollTask": "rl_asset_poll_task",
    "assetFinishTask": "rl_asset_finish_task",
    "assetGetTaskPath": "rl_asset_get_task_path",
    "fsRead": "rl_fs_read",
    "fsWrite": "rl_fs_write",
    "fsMkdir": "rl_fs_mkdir",
    "fsRmdir": "rl_fs_rmdir",
    "assetFreeTask": "rl_asset_free_task",
    "fsExists": "rl_fs_exists",
    "assetPingHost": "rl_asset_ping_host",
    "assetSetHost": "rl_asset_set_host",
    "assetGetHost": "rl_asset_get_host",
    "fsGetRootDir": "rl_fs_get_root_dir",
    "fsNormalizePath": "rl_fs_normalize_path",
    "assetTick": "rl_asset_tick",
    "fsClear": "rl_fs_clear",
    "fsRemove": "rl_fs_remove",
    "assetAddTask": "rl_asset_add_task",
    "loggerMessage": "rl_logger_message",
    "loggerMessageSource": "rl_logger_message_source",
    "loggerSetLevel": "rl_logger_set_level",
    "sprite3dGetTransform": "rl_sprite3d_get_transform",
}

HAXE_IMPL_NO_C = {
    "boot",
    "scratchRefresh",
    "assetTaskInvalid",
    "assetTaskIsValid",
    "helpersWaitForTask",
    "helpersWaitForFsReady",
}


def should_exclude_symbol(name: str) -> str | None:
    if name in LOGGER_MACROS:
        return "logger macro, not a function export"
    if name.startswith("rl_frame_command"):
        return "examples/remote only"
    if name == "rl_fs_read_free":
        return "binding-internal ownership helper; fs_read wrappers copy/own returned bytes"
    if name in ("rl_init_values", "rl_init_values_async"):
        return "binding-internal init bridge; public bindings expose init(config) / initAsync(config)"
    if name.startswith("rl_scratch_") or "_to_scratch" in name or "_from_scratch" in name:
        return "scratch/SAB bridge"
    return None


def strip_c_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//.*", "", text)
    return text


def parse_c_api_from_headers() -> tuple[list[str], list[str]]:
    raw: set[str] = set()
    for path in sorted(INCLUDE_DIR.glob("rl*.h")):
        text = strip_c_comments(path.read_text(encoding="utf-8"))
        for m in HEADER_FN_RE.finditer(text):
            raw.add(m.group(1))

    audited: list[str] = []
    excluded: list[str] = []
    for name in sorted(raw):
        reason = should_exclude_symbol(name)
        if reason:
            excluded.append(f"{name} ({reason})")
            continue
        audited.append(name)
    return audited, excluded


def parse_js_bindings() -> set[str]:
    text = (ROOT / "bindings/js/src/rl.ts").read_text(encoding="utf-8")
    found: set[str] = set()
    for pattern in (
        r"""ccall\(\s*['"]rl_[a-z0-9_]+['"]""",
        r"""cc(?:Num|Str|Handle)\(\s*['"]rl_[a-z0-9_]+['"]""",
    ):
        for m in re.finditer(pattern, text):
            sym = re.search(r"rl_[a-z0-9_]+", m.group(0))
            if sym:
                found.add(sym.group(0))

    covered: set[str] = set()
    for sym in found:
        if sym in JS_SCRATCH_BRIDGE_TO_C:
            covered.add(JS_SCRATCH_BRIDGE_TO_C[sym])
        elif sym.startswith("rl_scratch_") or "_to_scratch" in sym or "_from_scratch" in sym:
            continue
        else:
            covered.add(sym)

    if re.search(r"""['"]rl_init_values['"]""", text):
        covered.add("rl_init_values")
    if "rl_init_values_async" in text:
        covered.add("rl_init_values_async")

    # Scratch-backed input reads — JS reads directly from scratch area (documented in BINDINGS.md).
    if re.search(r"\bgetMouseState\s*:", text):
        covered.add("rl_input_get_mouse_state")
    if re.search(r"\bgetKeyboardState\s*:", text):
        covered.add("rl_input_get_keyboard_state")
    if re.search(r"\bgetMousePosition\s*:", text):
        covered.add("rl_input_get_mouse_position")
    if re.search(r"\bgetMouseDelta\s*:", text):
        covered.add("rl_input_get_mouse_delta")
    if re.search(r"\bgetMouseWheel\s*:", text):
        covered.add("rl_input_get_mouse_wheel")
    if re.search(r"\bgetMouseButton\s*:", text):
        covered.add("rl_input_get_mouse_button")

    return covered


def parse_haxe_bindings(paths: list[Path]) -> set[str]:
    covered: set[str] = set()
    for path in paths:
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r'@:native\("rl_[a-z0-9_]+"\)', text):
            covered.add(m.group(0).split('"')[1])
        for m in RL_SYM_RE.finditer(text):
            sym = m.group(0)
            if sym.endswith("_t") or sym.endswith("_fn"):
                continue
            if should_exclude_symbol(sym):
                continue
            covered.add(sym)

    return covered


def parse_haxe_public_methods(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"public static function\s+([A-Za-z0-9_]+)(?:<[^>]+>)?\s*\(", text))


def parse_haxe_extern_native_map(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {
        method: symbol
        for symbol, method in re.findall(
            r'@:native\("((?:rl|RL)_[A-Za-z0-9_]+)"\)\s+static function\s+([A-Za-z0-9_]+)\s*\(',
            text,
        )
        if symbol.startswith("rl_")
    }


def haxe_public_method_to_c_symbol(method: str, extern_map: dict[str, str]) -> str | None:
    if method in HAXE_IMPL_NO_C:
        return None
    if method in HAXE_IMPL_SPECIAL_TO_C:
        return HAXE_IMPL_SPECIAL_TO_C[method]
    if method in extern_map:
        return extern_map[method]
    if f"{method}Native" in extern_map:
        return extern_map[f"{method}Native"]
    return None


def parse_haxe_js_bindings(js_path: Path, cpp_path: Path) -> set[str]:
    extern_map = parse_haxe_extern_native_map(cpp_path)
    js_methods = parse_haxe_public_methods(js_path)
    covered: set[str] = set()
    for method in js_methods:
        sym = haxe_public_method_to_c_symbol(method, extern_map)
        if sym is None:
            continue
        if should_exclude_symbol(sym):
            continue
        covered.add(sym)
    return covered


def parse_nim_bindings(path: Path) -> set[str]:
    covered: set[str] = set()
    text = path.read_text(encoding="utf-8")
    for m in re.finditer(r"proc (rl_[a-z0-9_]+)", text):
        sym = m.group(1)
        if sym.endswith("_raw") or sym.endswith("_impl") or sym.endswith("_c"):
            base = sym
            for suffix in ("_raw", "_impl", "_c"):
                if sym.endswith(suffix):
                    base = sym[: -len(suffix)]
                    break
            covered.add(base)
        else:
            covered.add(sym)
    for m in re.finditer(r'importc:\s*"(rl_[a-z0-9_]+)"', text):
        covered.add(m.group(1))

    if "rl_asset_finish_c" in covered:
        covered.add("rl_asset_finish_task")
    covered -= {"rl_asset_finish_c"}
    return covered


def parse_lua_bindings() -> set[str]:
    covered: set[str] = set()
    for path in (ROOT / "bindings/lua").glob("*.c"):
        text = path.read_text(encoding="utf-8")
        wrapper_calls: dict[str, set[str]] = {}
        for m in re.finditer(r"static int\s+(rl_[a-z0-9_]+_lua)\s*\(lua_State \*L\)\s*\{", text):
            wrapper = m.group(1)
            start = m.end()
            next_match = re.search(r"\n(?:static int|void rl_register_[a-z0-9_]+_bindings)\b", text[start:])
            end = len(text) if next_match is None else start + next_match.start()
            body = text[start:end]
            calls: set[str] = set()
            for call in re.finditer(r"\b(rl_[a-z0-9_]+)\s*\(", body):
                sym = call.group(1)
                if should_exclude_symbol(sym):
                    continue
                calls.add(sym)
            wrapper_calls[wrapper] = calls

        registration_pattern = re.compile(
            r'lua_pushcfunction\(L,\s*(rl_[a-z0-9_]+_lua)\s*\);\s*'
            r'lua_setfield\(L,\s*-2,\s*"([a-z0-9_]+)"\s*\);',
            re.DOTALL,
        )
        registrations = list(registration_pattern.finditer(text))
        array_pattern = re.compile(r'\{\s*"([a-z0-9_]+)"\s*,\s*(rl_[a-z0-9_]+_lua)\s*\}')
        registrations.extend(array_pattern.finditer(text))

        for m in registrations:
            if m.lastindex != 2:
                continue
            if m.re is registration_pattern:
                wrapper = m.group(1)
                field = m.group(2)
            else:
                field = m.group(1)
                wrapper = m.group(2)
            calls = wrapper_calls.get(wrapper, set())
            if len(calls) == 1:
                covered |= calls
                continue
            prefixed = f"rl_{field}"
            if prefixed in calls and not should_exclude_symbol(prefixed):
                covered.add(prefixed)
    return covered


def priority_for(sym: str) -> str:
    if sym in FFI_INTERNAL:
        return "low (FFI internal)"
    high_prefixes = (
        "rl_init",
        "rl_deinit",
        "rl_tick",
        "rl_fs_",
        "rl_asset_",
        "rl_render_",
        "rl_window_",
        "rl_input_",
    )
    if sym.startswith(high_prefixes):
        return "high"
    if sym.startswith(("rl_logger_", "rl_debug_", "rl_pick_get_", "rl_pick_reset")):
        return "low"
    if sym.startswith("rl_sprite"):
        return "medium"
    return "medium"


def notes_for(sym: str) -> str:
    notes: list[str] = []
    if sym in FFI_INTERNAL:
        notes.append("FFI helper; may stay binding-internal")
    if sym.endswith("_async"):
        notes.append("async/poll API")
    if sym.startswith("rl_logger_"):
        notes.append("bindings typically wrap via log.* / Logger helpers")
    if sym in ("rl_fs_read_free",):
        notes.append("paired with rl_fs_read")
    if sym.startswith("rl_pick_get_") or sym == "rl_pick_reset_stats":
        notes.append("telemetry; JS exposes via helpers.getPickStats()")
    if sym == "rl_sprite3d_get_transform":
        notes.append("Haxe uses fetchNative bridge; Nim/Lua may need wrapper")
    if not notes:
        notes.append(priority_for(sym))
    return "; ".join(notes)


def load_documented_omissions() -> list[str]:
    items = [
        "scratch/SAB bridge (`rl_scratch_*`, `*_to_scratch`, `*_from_scratch`) — JS/wasm only; see `docs/BINDINGS.md`",
        "`rl_asset_ensure_many_from_scratch_async` — wasm scratch path; covered by JS `ensureGroupAsync` → `rl_asset_ensure_many_async`",
        "Logger convenience macros (`rl_logger_trace`, …) — bindings expose `setLevel` / message helpers instead",
        "`rl_fs_read_free` — binding-internal ownership helper; Haxe/Lua `fs_read` copy bytes into managed values and free native buffers internally",
        "`rl_init_values` / `rl_init_values_async` — binding-internal init bridge; public bindings expose `init(config)` / `initAsync(config)`",
    ]
    return items


AUDIT_COLUMNS = (
    ("js", "JS (`bindings/js/src/rl.ts`)"),
    ("haxe_js", "Haxe JS (`bindings/haxe/rl/impl/RLImpl.js.hx`)"),
    ("haxe_cpp", "Haxe cpp (`bindings/haxe/rl/impl/RLImpl.cpp.hx`, `RLFileioImpl.cpp.hx`)"),
    ("nim_js", "Nim JS (`bindings/nim/impl/rl_js.nim`)"),
    ("nim_native", "Nim native (`bindings/nim/impl/rl_native.nim`)"),
    ("lua", "Lua (`bindings/lua/`)"),
)


def render_roadmap_block(audited: list[str], gaps: list[dict]) -> str:
    def miss(binding: str) -> list[str]:
        return [g["symbol"] for g in gaps if not g[binding]]

    lines = [
        "### Binding parity (audit snapshot)",
        "",
        "Generated by `python3 tools/audit_binding_parity.py`. "
        f"**{len(audited)}** public C functions parsed from `include/rl*.h` "
        "(excludes scratch/SAB, logger macros, `examples/remote/`).",
        "",
        "| Binding | Covered | Gaps |",
        "|---------|--------:|-----:|",
    ]
    for key, label in AUDIT_COLUMNS:
        n = len(miss(key))
        lines.append(f"| {label} | {len(audited) - n}/{len(audited)} | {n} |")

    lines.extend(
        [
            "",
            "**Intentional non-gaps:** scratch/SAB; `rl_init_values*`; `rl_frame_command*` (examples/remote); "
            "`rl_fs_read_free` (binding-internal ownership helper). "
            "See `docs/BINDINGS.md`.",
            "",
        ]
    )

    binding_order = ("nim_native", "nim_js", "haxe_cpp", "haxe_js", "lua", "js")
    labels = {
        "nim_native": "Nim native",
        "nim_js": "Nim JS",
        "haxe_cpp": "Haxe cpp",
        "haxe_js": "Haxe JS",
        "lua": "Lua",
        "js": "JS",
    }
    for binding in binding_order:
        missing = miss(binding)
        if not missing:
            continue
        lines.append(f"**{labels[binding]} — add or verify ({len(missing)}):**")
        by_sec: dict[str, list[str]] = {}
        for s in missing:
            parts = s.split("_")
            sec = parts[1] if len(parts) > 2 else "core"
            by_sec.setdefault(sec, []).append(f"`{s}`")
        for sec in sorted(by_sec):
            syms = ", ".join(sorted(by_sec[sec]))
            lines.append(f"- `{sec}`: {syms}")
        lines.append("")

    lines.extend(
        [
            "**Follow-ups:**",
            "- Re-run `python3 tools/audit_binding_parity.py` after binding changes.",
        ]
    )
    if gaps:
        lines.append("- Close remaining gaps above or document intentional omissions in `docs/BINDINGS.md`.")
    else:
        lines.append("- No open binding parity gaps.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    audited, excluded = parse_c_api_from_headers()
    js = parse_js_bindings()
    haxe_js = parse_haxe_js_bindings(
        ROOT / "bindings/haxe/rl/impl/RLImpl.js.hx",
        ROOT / "bindings/haxe/rl/impl/RLImpl.cpp.hx",
    )
    haxe_cpp = parse_haxe_bindings(
        [
            ROOT / "bindings/haxe/rl/impl/RLImpl.cpp.hx",
            ROOT / "bindings/haxe/rl/impl/RLFileioImpl.cpp.hx",
        ]
    )
    nim_js = parse_nim_bindings(ROOT / "bindings/nim/impl/rl_js.nim")
    nim_native = parse_nim_bindings(ROOT / "bindings/nim/impl/rl_native.nim")
    lua = parse_lua_bindings()

    gaps: list[dict] = []
    for sym in audited:
        row = {
            "symbol": sym,
            "js": sym in js,
            "haxe_js": sym in haxe_js,
            "haxe_cpp": sym in haxe_cpp,
            "nim_js": sym in nim_js,
            "nim_native": sym in nim_native,
            "lua": sym in lua,
            "notes": notes_for(sym),
        }
        if not all(row[key] for key, _label in AUDIT_COLUMNS):
            gaps.append(row)

    def count_missing(binding: str) -> int:
        return sum(1 for g in gaps if not g[binding])

    print("=" * 72)
    print("BINDING PARITY AUDIT")
    print("=" * 72)
    print()
    print("Summary counts")
    print(f"  C functions audited:     {len(audited)}")
    print(f"  C symbols excluded:      {len(excluded)}")
    print(f"  Gaps (any binding):      {len(gaps)}")
    print(f"  JS gaps:                 {count_missing('js')}")
    print(f"  Haxe JS gaps:            {count_missing('haxe_js')}")
    print(f"  Haxe cpp gaps:           {count_missing('haxe_cpp')}")
    print(f"  Nim JS gaps:             {count_missing('nim_js')}")
    print(f"  Nim native gaps:         {count_missing('nim_native')}")
    print(f"  Lua gaps:                {count_missing('lua')}")
    print()

    print("Gap table")
    print("C symbol | JS | Haxe JS | Haxe cpp | Nim JS | Nim native | Lua | priority/notes")
    print("---|:---:|:---:|:---:|:---:|:---:|:---:|---")
    mark = lambda ok: "✓" if ok else "—"
    for g in gaps:
        print(
            f"`{g['symbol']}` | {mark(g['js'])} | {mark(g['haxe_js'])} | {mark(g['haxe_cpp'])} | {mark(g['nim_js'])} | {mark(g['nim_native'])} | {mark(g['lua'])} | {g['notes']}"
        )

    print()
    print("Intentional omissions already documented")
    for item in load_documented_omissions():
        print(f"  - {item}")

    print()
    print("Recommended ROADMAP markdown block")
    print("-" * 72)
    print(render_roadmap_block(audited, gaps))
    return 0


if __name__ == "__main__":
    sys.exit(main())
