#!/usr/bin/env python3
"""Measure web/desktop example artifact sizes and emit comparison markdown."""

from __future__ import annotations

import argparse
import gzip
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "docs" / "WEB_SIZES.md"


@dataclass(frozen=True)
class Bundle:
    name: str
    paths: tuple[str, ...]
    note: str = ""


@dataclass(frozen=True)
class Measured:
    bundle: Bundle
    files: tuple[tuple[str, int, int, int | None], ...]  # rel, raw, gzip, brotli
    raw: int
    gzip: int
    brotli: int | None


def fmt_bytes(n: int) -> str:
    if n >= 1024 * 1024:
        return f"{n / 1024 / 1024:.2f} MB"
    if n >= 1024:
        return f"{n / 1024:.1f} KB"
    return f"{n} B"


def brotli_size(data: bytes) -> int | None:
    if shutil.which("brotli") is None:
        return None
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp.write(data)
        inp = Path(tmp.name)
    out = inp.with_suffix(inp.suffix + ".br")
    try:
        subprocess.run(
            ["brotli", "-q", "11", "-o", str(out), str(inp)],
            check=True,
            capture_output=True,
        )
        return out.stat().st_size
    finally:
        inp.unlink(missing_ok=True)
        out.unlink(missing_ok=True)


def measure_file(rel: str, use_brotli: bool) -> tuple[str, int, int, int | None]:
    path = ROOT / rel
    data = path.read_bytes()
    raw = len(data)
    gz = len(gzip.compress(data, compresslevel=9))
    br = brotli_size(data) if use_brotli else None
    return rel, raw, gz, br


def measure_bundle(bundle: Bundle, use_brotli: bool) -> Measured | None:
    missing = [p for p in bundle.paths if not (ROOT / p).exists()]
    if missing:
        print(f"warning: skipping {bundle.name}; missing: {', '.join(missing)}", file=sys.stderr)
        return None

    files = tuple(measure_file(p, use_brotli) for p in bundle.paths)
    raw = sum(f[1] for f in files)
    gz = sum(f[2] for f in files)
    br_values = [f[3] for f in files]
    brotli_total = sum(br_values) if use_brotli and all(v is not None for v in br_values) else None
    return Measured(bundle=bundle, files=files, raw=raw, gzip=gz, brotli=brotli_total)


def ratio(value: int, base: int) -> str:
    if base <= 0:
        return "—"
    return f"{value / base:.2f}×"


def md_table(headers: list[str], rows: list[list[str]]) -> str:
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join("---" for _ in headers) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


WEB_BUNDLES = [
    Bundle("C wasm (c-simple)", ("examples/c-simple/out/main.js", "examples/c-simple/out/main.wasm")),
    Bundle("Nim wasm", ("examples/nim-simple/out/wasm/main.js", "examples/nim-simple/out/wasm/main.wasm")),
    Bundle("C-lua wasm", ("examples/c-lua/out/main.js", "examples/c-lua/out/main.wasm")),
    Bundle(
        "C-lua wasm + lua scripts",
        (
            "examples/c-lua/out/main.js",
            "examples/c-lua/out/main.wasm",
            "examples/www/public/assets/scripts/lua/main.lua",
            "examples/www/public/assets/scripts/lua/runtime_wrapper.lua",
            "examples/www/public/assets/scripts/lua/lua_demo.lua",
            "examples/www/public/assets/scripts/lua/input_mapping.lua",
            "examples/www/public/assets/scripts/lua/resource_async.lua",
            "examples/www/public/assets/scripts/lua/shadow.lua",
            "examples/www/public/assets/scripts/lua/camera3d.lua",
            "examples/www/public/assets/scripts/lua/sound.lua",
            "examples/www/public/assets/scripts/lua/music.lua",
            "examples/www/public/assets/scripts/lua/model.lua",
            "examples/www/public/assets/scripts/lua/font.lua",
            "examples/www/public/assets/scripts/lua/texture.lua",
            "examples/www/public/assets/scripts/lua/sprite3d.lua",
            "examples/www/public/assets/scripts/lua/sprite2d.lua",
            "examples/www/public/assets/scripts/lua/color.lua",
        ),
        note="Initial load; gameplay scripts fetched at runtime",
    ),
    Bundle("Haxe wasm", ("examples/haxe-simple/out/wasm/Main.js", "examples/haxe-simple/out/wasm/Main.wasm")),
    Bundle(
        "Shared core (librl + rl.js)",
        ("lib/librl.js", "lib/librl.wasm", "bindings/js/dist/rl.js"),
        note="Used by all *+JS paths",
    ),
    Bundle(
        "Haxe+JS",
        (
            "lib/librl.js",
            "lib/librl.wasm",
            "bindings/js/dist/rl.js",
            "examples/www/public/assets/scripts/haxe/js/main.js",
        ),
    ),
    Bundle(
        "Nim+JS",
        (
            "lib/librl.js",
            "lib/librl.wasm",
            "bindings/js/dist/rl.js",
            "examples/nim-simple/out/js/main.js",
        ),
    ),
    Bundle(
        "Pure JS example",
        ("lib/librl.js", "lib/librl.wasm", "bindings/js/dist/rl.js", "examples/js/js_example.js"),
    ),
    Bundle(
        "Cppia host (initial)",
        (
            "examples/cppia/out/wasm/ScriptableMain.js",
            "examples/cppia/out/wasm/ScriptableMain.wasm",
            "examples/www/public/assets/scripts/haxe/MainScript.cppia",
        ),
    ),
    Bundle(
        "Cppia script only (HCR)",
        ("examples/www/public/assets/scripts/haxe/MainScript.cppia",),
        note="Hot-reload payload after host is cached",
    ),
]

APP_LAYER_BUNDLES = [
    Bundle("Haxe JS app", ("examples/www/public/assets/scripts/haxe/js/main.js",), note="Excludes shared core"),
    Bundle("Nim JS app", ("examples/nim-simple/out/js/main.js",), note="Excludes shared core"),
    Bundle("Pure JS app", ("examples/js/js_example.js",), note="Excludes shared core"),
]

DESKTOP_BUNDLES = [
    Bundle("C desktop", ("examples/c-simple/out/main",)),
    Bundle("Nim desktop + HCR DLLs", ("examples/nim-simple/out/desktop/main", "examples/nim-simple/out/libnimhcr.so", "examples/nim-simple/out/libnimrtl.so")),
    Bundle("Haxe desktop", ("examples/haxe-simple/out/desktop/Main",)),
    Bundle("C-lua desktop", ("examples/c-lua/out/main",)),
    Bundle("Cppia desktop host", ("examples/cppia/out/desktop/ScriptableMain",)),
]


def render_markdown(web: list[Measured], apps: list[Measured], desktop: list[Measured], use_brotli: bool) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        "# Web and desktop artifact sizes",
        "",
        "> Generated by `python3 tools/measure_web_sizes.py`. Re-run after release builds.",
        "",
        f"Generated: {now}",
        "",
        "Sizes use per-file compression sums (how a browser fetches separate artifacts).",
        "Build artifacts are read from `out/` and `lib/` (same bytes staged under `examples/www/dist/`).",
        "",
        "Build first:",
        "",
        "```bash",
        "make wasm",
        "make -C examples wasm js cppia",
        "npm run build:cppia:script",
        "```",
        "",
    ]

    base_gzip = next((m.gzip for m in web if m.bundle.name.startswith("C wasm")), None)

    headers = ["Offering", "Raw", "gzip", "vs C wasm"]
    if use_brotli:
        headers.insert(3, "brotli")
    rows: list[list[str]] = []
    for m in web:
        row = [m.bundle.name, fmt_bytes(m.raw), fmt_bytes(m.gzip)]
        if use_brotli:
            row.append(fmt_bytes(m.brotli) if m.brotli is not None else "—")
        row.append(ratio(m.gzip, base_gzip) if base_gzip else "—")
        rows.append(row)
    lines.extend(["## Web offerings", "", md_table(headers, rows), ""])

    for m in web:
        lines.extend([f"### {m.bundle.name}", ""])
        if m.bundle.note:
            lines.append(f"{m.bundle.note}.")
            lines.append("")
        file_headers = ["File", "Raw", "gzip"]
        if use_brotli:
            file_headers.append("brotli")
        file_rows = []
        for rel, raw, gz, br in m.files:
            row = [f"`{rel}`", fmt_bytes(raw), fmt_bytes(gz)]
            if use_brotli:
                row.append(fmt_bytes(br) if br is not None else "—")
            file_rows.append(row)
        lines.append(md_table(file_headers, file_rows))
        lines.append("")

    if apps:
        headers = ["App layer", "Raw", "gzip"]
        if use_brotli:
            headers.append("brotli")
        rows = []
        for m in apps:
            row = [m.bundle.name, fmt_bytes(m.raw), fmt_bytes(m.gzip)]
            if use_brotli:
                row.append(fmt_bytes(m.brotli) if m.brotli is not None else "—")
            rows.append(row)
        lines.extend(["## JS app layer only", "", "After shared core is cached.", "", md_table(headers, rows), ""])

    if desktop:
        headers = ["Desktop build", "Raw", "gzip"]
        if use_brotli:
            headers.append("brotli")
        rows = []
        for m in desktop:
            row = [m.bundle.name, fmt_bytes(m.raw), fmt_bytes(m.gzip)]
            if use_brotli:
                row.append(fmt_bytes(m.brotli) if m.brotli is not None else "—")
            rows.append(row)
        lines.extend(["## Desktop (reference)", "", md_table(headers, rows), ""])

    lines.extend(
        [
            "## Notes",
            "",
            "- **C/Nim wasm** link `librl.wasm.a` into one module; smallest monolithic web path.",
            "- **\\*+JS paths** load shared `lib/librl.wasm` plus a thin language frontend in JS.",
            "- **Haxe wasm** pays a large hxcpp-in-wasm runtime tax versus Haxe→JS.",
            "- **C-lua wasm** adds a statically linked Lua VM; gameplay `.lua` files are fetched separately.",
            "- **Cppia host** is built for hot reload; initial load is much larger than plain Haxe wasm.",
            "- Exact numbers depend on toolchain and build flags; use for relative comparison only.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Write markdown report (default: {DEFAULT_OUTPUT.relative_to(ROOT)})",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print markdown to stdout instead of writing --output",
    )
    parser.add_argument(
        "--no-brotli",
        action="store_true",
        help="Skip brotli measurements even if the brotli CLI is available",
    )
    args = parser.parse_args()

    use_brotli = not args.no_brotli and shutil.which("brotli") is not None
    if not args.no_brotli and not use_brotli:
        print("warning: brotli CLI not found; gzip-only report", file=sys.stderr)

    web = [m for b in WEB_BUNDLES if (m := measure_bundle(b, use_brotli)) is not None]
    apps = [m for b in APP_LAYER_BUNDLES if (m := measure_bundle(b, use_brotli)) is not None]
    desktop = [m for b in DESKTOP_BUNDLES if (m := measure_bundle(b, use_brotli)) is not None]

    if not web:
        print("error: no web artifacts found; build examples first", file=sys.stderr)
        return 1

    markdown = render_markdown(web, apps, desktop, use_brotli)

    if args.stdout:
        print(markdown)
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(markdown, encoding="utf-8")
        print(f"wrote {args.output.relative_to(ROOT)}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
