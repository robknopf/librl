#!/usr/bin/env python3
"""Generate per-binding 'built against librl' version stamps from include/rl_version.h."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DEFINE_RE = re.compile(r"^#define\s+(RL_VERSION_MAJOR|RL_VERSION_MINOR|RL_VERSION_PATCH)\s+(\S+)", re.M)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def parse_version_header(header_path: Path) -> tuple[int, int, int]:
    text = header_path.read_text(encoding="utf-8")
    found: dict[str, int] = {}
    for name, value in DEFINE_RE.findall(text):
        found[name] = int(value, 0)
    missing = [key for key in ("RL_VERSION_MAJOR", "RL_VERSION_MINOR", "RL_VERSION_PATCH") if key not in found]
    if missing:
        raise ValueError(f"could not parse {', '.join(missing)} from {header_path}")
    return found["RL_VERSION_MAJOR"], found["RL_VERSION_MINOR"], found["RL_VERSION_PATCH"]


def c_block_comment(source: str) -> str:
    return "\n".join(
        (
            "/* GENERATED — DO NOT EDIT",
            " * librl binding version stamp",
            f" * from: {source}",
            " */",
        )
    )


def nim_comment(source: str) -> str:
    return "\n".join(
        (
            "## GENERATED — DO NOT EDIT",
            "## librl binding version stamp",
            f"## from: {source}",
        )
    )


def version_core(major: int, minor: int, patch: int) -> str:
    return f"{major}.{minor}.{patch}"


def write_lua_header(path: Path, major: int, minor: int, patch: int) -> None:
    version = version_core(major, minor, patch)
    body = f"""{c_block_comment("include/rl_version.h")}

#ifndef RL_LUA_VERSION_H
#define RL_LUA_VERSION_H

#define RL_BINDING_BUILT_MAJOR {major}
#define RL_BINDING_BUILT_MINOR {minor}
#define RL_BINDING_BUILT_PATCH {patch}
#define RL_BINDING_BUILT_VERSION_STRING "{version}"

#endif /* RL_LUA_VERSION_H */
"""
    path.write_text(body, encoding="utf-8", newline="\n")


def write_js_module(path: Path, major: int, minor: int, patch: int) -> None:
    version = version_core(major, minor, patch)
    body = f"""{c_block_comment("include/rl_version.h")}

export const RL_BINDING_BUILT_MAJOR = {major};
export const RL_BINDING_BUILT_MINOR = {minor};
export const RL_BINDING_BUILT_PATCH = {patch};
export const RL_BINDING_BUILT_VERSION_STRING = "{version}";
"""
    path.write_text(body, encoding="utf-8", newline="\n")


def write_nim_module(path: Path, major: int, minor: int, patch: int) -> None:
    version = version_core(major, minor, patch)
    body = f"""{nim_comment("include/rl_version.h")}

const
  rlBindingMajor* = {major}
  rlBindingMinor* = {minor}
  rlBindingPatch* = {patch}
  rlBindingVersionString* = "{version}"
"""
    path.write_text(body, encoding="utf-8", newline="\n")


def write_haxe_module(path: Path, major: int, minor: int, patch: int) -> None:
    version = version_core(major, minor, patch)
    body = f"""{c_block_comment("include/rl_version.h")}
package rl.gen;

class RLVersion {{
\tpublic static inline var BUILT_MAJOR:Int = {major};
\tpublic static inline var BUILT_MINOR:Int = {minor};
\tpublic static inline var BUILT_PATCH:Int = {patch};
\tpublic static inline var BUILT_VERSION_STRING:String = "{version}";
}}
"""
    path.write_text(body, encoding="utf-8", newline="\n")


def generate(root: Path) -> tuple[int, int, int]:
    header_path = root / "include" / "rl_version.h"
    if not header_path.is_file():
        raise FileNotFoundError(f"missing {header_path}")

    major, minor, patch = parse_version_header(header_path)

    outputs = {
        root / "bindings/lua/gen/rl_lua_version.h": write_lua_header,
        root / "bindings/js/gen/rl_version.js": write_js_module,
        root / "bindings/nim/gen/rl_version.nim": write_nim_module,
        root / "bindings/haxe/rl/gen/RLVersion.hx": write_haxe_module,
    }
    for path, writer in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        writer(path, major, minor, patch)

    return major, minor, patch


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root",
        nargs="?",
        default=None,
        help="librl repository root (default: parent of tools/)",
    )
    args = parser.parse_args(argv)
    root = Path(args.root).resolve() if args.root else repo_root()

    try:
        major, minor, patch = generate(root)
    except (FileNotFoundError, ValueError) as exc:
        print(f"gen_binding_versions: {exc}", file=sys.stderr)
        return 1

    print(f"gen_binding_versions: wrote binding version stamps (librl {major}.{minor}.{patch})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
