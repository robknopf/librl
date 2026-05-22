#!/usr/bin/env python3
"""Print the path to a Node.js binary with JSPI (WebAssembly.Suspending).

Used by wasm test Makefiles when NODE is not set explicitly.
Exit 0 and print path on success; exit 1 if none found.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


def has_jspi(node_path: str) -> bool:
    try:
        proc = subprocess.run(
            [
                node_path,
                "-e",
                "process.exit(typeof WebAssembly.Suspending === 'function' ? 0 : 1)",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return proc.returncode == 0
    except OSError:
        return False


def try_node(candidate: str) -> str | None:
    path = Path(candidate)
    if path.is_file() and os.access(path, os.X_OK) and has_jspi(str(path)):
        return str(path)
    return None


def nvm_roots() -> list[Path]:
    roots: list[Path] = []
    nvm_dir = os.environ.get("NVM_DIR")
    if nvm_dir:
        roots.append(Path(nvm_dir) / "versions" / "node")
    roots.append(Path.home() / ".nvm" / "versions" / "node")
    seen: set[Path] = set()
    out: list[Path] = []
    for root in roots:
        if root in seen:
            continue
        seen.add(root)
        if root.is_dir():
            out.append(root)
    return out


def nvm_node_candidates() -> list[str]:
    candidates: list[str] = []
    for root in nvm_roots():
        try:
            versions = sorted(
                (p.name for p in root.iterdir() if p.is_dir()),
                key=lambda v: [int(x) if x.isdigit() else x for x in v.split(".")],
                reverse=True,
            )
        except OSError:
            continue
        for ver in versions:
            node = root / ver / "bin" / "node"
            if node.is_file():
                candidates.append(str(node))
    return candidates


def main() -> int:
    env_node = os.environ.get("NODE", "").strip()
    if env_node:
        ok = try_node(env_node)
        if ok:
            print(ok)
            return 0

    for name in ("node", "nodejs"):
        found = shutil.which(name)
        if found:
            ok = try_node(found)
            if ok:
                print(ok)
                return 0

    for candidate in nvm_node_candidates():
        ok = try_node(candidate)
        if ok:
            print(ok)
            return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
