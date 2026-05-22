#!/usr/bin/env python3
"""Generate types/librl.d.ts from bindings/js/rl.js."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

KEY_LINE_RE = re.compile(r"^    ([A-Za-z_]\w*):\s*(.*)$")
CONST_VALUE_RE = re.compile(r"^(-?\d+|0x[0-9a-fA-F]+)\s*,?\s*(?://.*)?$")
COLOR_NAMES_RE = re.compile(r'_RL_COLOR_NAMES:\s*\[\s*(.*?)\s*\]', re.S)
NAMESPACE_BLOCK_RE = re.compile(r"^RL\.(\w+)\s*=\s*\{", re.M)

TOP_LEVEL_SIGNATURE_OVERRIDES: dict[str, str] = {
    "boot": "boot(opts?: RLInitOptions): Promise<number>;",
    "init": "init(opts?: RLInitOptions): Promise<number>;",
    "initAsync": "initAsync(opts?: RLInitOptions): number;",
    "deinit": "deinit(): Promise<void>;",
    "isInitialized": "isInitialized(): boolean;",
    "getPlatform": "getPlatform(): string;",
    "versionLabel": "versionLabel(): string;",
    "getVersionString": "getVersionString(): string;",
    "getVersionMajor": "getVersionMajor(): number;",
    "getVersionMinor": "getVersionMinor(): number;",
    "getVersionPatch": "getVersionPatch(): number;",
    "getVersionNumber": "getVersionNumber(): number;",
    "tick": "tick(): number;",
    "getTime": "getTime(): number;",
    "getDeltaTime": "getDeltaTime(): number;",
    "setTargetFPS": "setTargetFPS(fps: number): void;",
    "refreshScratch": "refreshScratch(): void;",
    "helpers": "helpers: RLHelpers;",
}

NAMESPACE_SIGNATURE_OVERRIDES: dict[str, dict[str, str]] = {
    "fs": {
        "init": "init(rootDir?: string): Promise<number>;",
        "initAsync": "initAsync(rootDir?: string): number;",
        "deinit": "deinit(): Promise<void>;",
        "read": "read(filename: string): Uint8Array | null;",
        "write": "write(path: string, data: ArrayBufferView): number;",
        "isReady": "isReady(): boolean;",
        "isInitialized": "isInitialized(): boolean;",
        "getRootDir": "getRootDir(): string;",
        "normalizePath": "normalizePath(path: string): string;",
        "restoreAsync": "restoreAsync(): number;",
        "exists": "exists(filename: string): boolean;",
    },
    "asset": {
        "ensure": "ensure(localPath: string, src?: string | null): Promise<number>;",
        "ensureAsync": "ensureAsync(localPath: string, src?: string | null): number;",
        "ensureGroupAsync": "ensureGroupAsync(filenames: string[]): number;",
        "pollTask": "pollTask(task: number): boolean;",
        "setHost": "setHost(assetHost: string): number;",
        "getHost": "getHost(): string;",
        "getTaskPath": "getTaskPath(task: number): string;",
        "ADD_TASK_OK": "ADD_TASK_OK: number;",
        "ADD_TASK_ERR_INVALID": "ADD_TASK_ERR_INVALID: number;",
        "ADD_TASK_ERR_QUEUE_FULL": "ADD_TASK_ERR_QUEUE_FULL: number;",
    },
    "event": {
        "emit": "emit(eventName: string, payload?: number): number;",
        "on": "on(eventName: string, callback: RLEventCallback): number;",
        "once": "once(eventName: string, callback: RLEventCallback): number;",
        "off": "off(eventName: string, callback: RLEventCallback): number;",
    },
    "window": {
        "isCloseRequested": "isCloseRequested(): boolean;",
        "getScreenSize": "getScreenSize(): RLVector2;",
        "getPosition": "getPosition(): RLVector2;",
        "getMonitorPosition": "getMonitorPosition(monitor?: number): RLVector2;",
    },
    "render": {
        "isLightingEnabled": "isLightingEnabled(): boolean;",
    },
    "camera3d": {
        "getDefault": "getDefault(): RLHandle;",
        "getActive": "getActive(): RLHandle;",
    },
    "text": {
        "measureEx": "measureEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;",
    },
    "texture": {
        "getDefault": "getDefault(): RLHandle;",
    },
    "input": {
        "getMouseState": "getMouseState(): RLMouseState;",
        "getKeyboardState": "getKeyboardState(): RLKeyboardState;",
        "getGamepads": "getGamepads(): RLGamepadState[];",
        "getGamepad": "getGamepad(id: number): RLGamepadState | null;",
        "getTouchpoints": "getTouchpoints(): RLTouchpoint[];",
        "getTouchpoint": "getTouchpoint(id: number): RLTouchpoint | null;",
        "getMousePosition": "getMousePosition(): RLVector2;",
    },
    "font": {
        "getDefault": "getDefault(): RLHandle;",
    },
    "model": {
        "isValid": "isValid(model: RLHandle): boolean;",
        "isValidStrict": "isValidStrict(model: RLHandle): boolean;",
    },
    "pick": {
        "model": "model(camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number): RLPickResult;",
        "sprite3d": "sprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number): RLPickResult;",
    },
    "music": {
        "isPlaying": "isPlaying(music: RLHandle): boolean;",
    },
    "sound": {
        "isPlaying": "isPlaying(sound: RLHandle): boolean;",
    },
    "sprite3d": {
        "getTransform": "getTransform(sprite: RLHandle): RLSprite3dTransform | null;",
    },
    "text2d": {
        "create": "create(font: RLHandle, size: number): RLHandle;",
        "setFont": "setFont(handle: RLHandle, font: RLHandle): void;",
        "setSize": "setSize(handle: RLHandle, size: number): void;",
        "setContent": "setContent(handle: RLHandle, content: string): void;",
        "setPosition": "setPosition(handle: RLHandle, x: number, y: number): void;",
        "setColor": "setColor(handle: RLHandle, color: RLHandle): void;",
        "draw": "draw(handle: RLHandle): void;",
        "destroy": "destroy(handle: RLHandle): void;",
    },
}

HELPER_SIGNATURE_OVERRIDES: dict[str, str] = {
    "waitForFsReady": "waitForFsReady(timeoutMs?: number): Promise<boolean>;",
    "taskIsValid": "taskIsValid(task: number): boolean;",
    "waitForTask": "waitForTask(task: number, pollMs?: number): Promise<number>;",
    "waitForFsRestoreAsync": "waitForFsRestoreAsync(): Promise<number>;",
    "waitForAssetEnsureAsync": "waitForAssetEnsureAsync(localPath: string, src?: string | null): Promise<number>;",
    "waitForAssetEnsureGroupAsync": "waitForAssetEnsureGroupAsync(filenames: string[]): Promise<number>;",
    "createTaskGroup": "createTaskGroup<T = unknown>(onComplete?: RLTaskGroupCallback<T> | null, onError?: RLTaskGroupCallback<T> | null, ctx?: T): RLTaskGroup<T>;",
    "getScreenWidth": "getScreenWidth(): number;",
    "getScreenHeight": "getScreenHeight(): number;",
    "getPickStats": "getPickStats(): RLPickStats;",
}

NAMESPACE_ORDER = [
    "fs",
    "asset",
    "model",
    "sprite3d",
    "sprite2d",
    "text2d",
    "texture",
    "font",
    "camera3d",
    "window",
    "input",
    "render",
    "text",
    "shape",
    "debug",
    "logger",
    "pick",
    "event",
    "color",
    "music",
    "sound",
]

SHARED_TYPES = """\
export type RLHandle = number;

export interface RLVector2 {
  x: number;
  y: number;
}

export interface RLVector3 {
  x: number;
  y: number;
  z: number;
}

export interface RLVector4 {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface RLMouseState {
  x: number;
  y: number;
  wheel: number;
  left: number;
  right: number;
  middle: number;
  buttons: Int32Array;
}

export interface RLKeyboardState {
  max_num_keys: number;
  keys: Int32Array;
  pressed_key: number;
  pressed_char: number;
  num_pressed_keys: number;
  pressed_keys: Int32Array;
  num_pressed_chars: number;
  pressed_chars: Int32Array;
}

export interface RLGamepadState {
  id: number;
  axis: Float32Array;
  buttons: Int32Array;
}

export interface RLTouchpoint {
  id: number;
  x: number;
  y: number;
}

export interface RLPickResult {
  hit: boolean;
  distance: number;
  point: RLVector3;
  normal: RLVector3;
}

export interface RLSprite3dTransform {
  positionX: number;
  positionY: number;
  positionZ: number;
  size: number;
}

export interface RLPickStats {
  broadphaseTests: number;
  broadphaseRejects: number;
  narrowphaseTests: number;
  narrowphaseHits: number;
}

export interface RLInitEnv {
  canvas?: HTMLCanvasElement | null;
  print?: (...args: unknown[]) => void;
  [key: string]: unknown;
}

export interface RLInitOptions {
  assetHost?: string;
  fsRootDir?: string;
  windowWidth?: number;
  windowHeight?: number;
  windowTitle?: string;
  windowFlags?: number;
  loaderCacheDir?: string;
  idealWidth?: number;
  idealHeight?: number;
  env?: RLInitEnv;
  [key: string]: unknown;
}

export type RLEventCallback = (payload: number) => void;
export type RLTaskGroupTaskCallback<T = unknown> = (path: string, ctx: T) => void;
export type RLTaskGroupCallback<T = unknown> = (group: RLTaskGroup<T>, ctx: T) => void;

export interface RLTaskGroup<T = unknown> {
  failedCount: number;
  completedCount: number;
  addTask(task: number, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTask(path: string, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTasks(paths: string[], onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  remainingTasks(): number;
  isDone(): boolean;
  hasFailures(): boolean;
  tick(): boolean;
  process(): number;
  failedPaths(): string[];
}
"""


def split_block(text: str, start_marker: str) -> tuple[str, str]:
    start = text.index(start_marker)
    body_start = start + len(start_marker)
    depth = 1
    i = body_start
    while i < len(text) and depth > 0:
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        i += 1
    return text[start:body_start], text[body_start : i - 1]


def parse_entries(block: str, *, public_only: bool) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    for line in block.splitlines():
        match = KEY_LINE_RE.match(line)
        if not match:
            continue
        name, rest = match.group(1), match.group(2)
        if public_only and name.startswith("_"):
            continue
        if CONST_VALUE_RE.match(rest):
            entries.append((name, "const"))
            continue
        if rest.startswith("async") or " async " in f" {rest} ":
            entries.append((name, "async"))
            continue
        entries.append((name, "method"))
    return entries


def parse_color_names(text: str) -> list[str]:
    match = COLOR_NAMES_RE.search(text)
    if not match:
        return []
    raw = match.group(1)
    return [part.strip().strip('"').strip("'") for part in raw.split(",") if part.strip()]


def default_signature(name: str, kind: str) -> str:
    if kind == "const":
        return f"{name}: number;"
    if kind == "async":
        return f"{name}(...args: unknown[]): Promise<unknown>;"
    return f"{name}(...args: unknown[]): unknown;"


def emit_interface(name: str, entries: list[tuple[str, str]], overrides: dict[str, str], extra_constants: list[str]) -> str:
    lines = [f"export interface {name} {{"]
    seen: set[str] = set()

    for entry_name, kind in entries:
        if entry_name in seen:
            continue
        seen.add(entry_name)
        sig = overrides.get(entry_name, default_signature(entry_name, kind))
        lines.append(f"  {sig}")

    for const_name in extra_constants:
        if const_name in seen:
            continue
        seen.add(const_name)
        lines.append(f"  {const_name}: number;")

    lines.append("}")
    return "\n".join(lines)


def interface_name(namespace: str) -> str:
    if namespace == "fs":
        return "RLFs"
    return "RL" + namespace[:1].upper() + namespace[1:]


def generate(root: Path) -> None:
    rl_js_path = root / "bindings" / "js" / "rl.js"
    out_path = root / "types" / "librl.d.ts"
    text = rl_js_path.read_text(encoding="utf-8")

    _, rl_body = split_block(text, "const RL = {")
    _, helpers_body = split_block(text, "RL.helpers = {")

    rl_entries = parse_entries(rl_body, public_only=True)
    helper_entries = parse_entries(helpers_body, public_only=False)
    if not any(name == "helpers" for name, _ in rl_entries):
        rl_entries.append(("helpers", "method"))

    namespace_blocks: dict[str, str] = {}
    for match in NAMESPACE_BLOCK_RE.finditer(text):
        ns = match.group(1)
        if ns == "helpers":
            continue
        marker = f"RL.{ns} = {{"
        _, body = split_block(text, marker)
        namespace_blocks[ns] = body

    color_names = parse_color_names(text)
    color_constants = [f"COLOR_{name}" for name in color_names]

    helpers_iface = emit_interface("RLHelpers", helper_entries, HELPER_SIGNATURE_OVERRIDES, [])

    namespace_ifaces: list[str] = []
    namespace_props: list[str] = []
    for ns in NAMESPACE_ORDER:
        if ns not in namespace_blocks:
            continue
        entries = parse_entries(namespace_blocks[ns], public_only=False)
        overrides = NAMESPACE_SIGNATURE_OVERRIDES.get(ns, {})
        namespace_ifaces.append(
            emit_interface(interface_name(ns), entries, overrides, [])
        )
        namespace_props.append(f"  {ns}: {interface_name(ns)};")

    rl_iface_lines = ["export interface RLApi {"]
    seen: set[str] = set()
    for entry_name, kind in rl_entries:
        if entry_name in seen:
            continue
        seen.add(entry_name)
        sig = TOP_LEVEL_SIGNATURE_OVERRIDES.get(entry_name, default_signature(entry_name, kind))
        rl_iface_lines.append(f"  {sig}")

    for const_name in color_constants:
        if const_name in seen:
            continue
        seen.add(const_name)
        rl_iface_lines.append(f"  {const_name}: number;")

    for prop in namespace_props:
        rl_iface_lines.append(prop)

    rl_iface_lines.append("}")
    rl_iface = "\n".join(rl_iface_lines)

    header = (
        "/* GENERATED — DO NOT EDIT\n"
        " * librl TypeScript declarations\n"
        " * from: bindings/js/rl.js (via tools/gen_librl_dts.py)\n"
        " */\n"
    )

    body = "\n".join(
        (
            header,
            SHARED_TYPES,
            helpers_iface,
            "",
            *namespace_ifaces,
            "",
            rl_iface,
            "",
            "export const rl: RLApi;",
            "",
        )
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(body, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root",
        nargs="?",
        default=str(Path(__file__).resolve().parent.parent),
        help="repository root",
    )
    args = parser.parse_args()
    root = Path(args.root).resolve()
    try:
        generate(root)
    except Exception as exc:  # noqa: BLE001 — CLI entrypoint
        print(f"gen_librl_dts: {exc}", file=sys.stderr)
        return 1
    print(f"generated {root / 'types' / 'librl.d.ts'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
