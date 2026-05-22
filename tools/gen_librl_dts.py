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

SIGNATURE_OVERRIDES: dict[str, str] = {
    "boot": "boot(opts?: RLInitOptions): Promise<number>;",
    "init": "init(opts?: RLInitOptions): Promise<number>;",
    "initAsync": "initAsync(opts?: RLInitOptions): number;",
    "deinit": "deinit(): Promise<void>;",
    "fileioInit": "fileioInit(baseDir?: string): Promise<number>;",
    "fileioInitAsync": "fileioInitAsync(baseDir?: string): number;",
    "fileioDeinit": "fileioDeinit(): Promise<number>;",
    "fileioDeinitAsync": "fileioDeinitAsync(): number;",
    "fileioEnsure": "fileioEnsure(localPath: string, src?: string | null): Promise<number>;",
    "fileioEnsureAsync": "fileioEnsureAsync(localPath: string, src?: string | null): number;",
    "fileioEnsureGroupAsync": "fileioEnsureGroupAsync(filenames: string[]): number;",
    "fileioRestoreAsync": "fileioRestoreAsync(): number;",
    "fileioRead": "fileioRead(filename: string): Uint8Array | null;",
    "fileioWrite": "fileioWrite(path: string, data: ArrayBufferView): number;",
    "fileioPollTask": "fileioPollTask(task: number): boolean;",
    "fileioExists": "fileioExists(filename: string): boolean;",
    "fileioIsReady": "fileioIsReady(): boolean;",
    "fileioIsInitialized": "fileioIsInitialized(): boolean;",
    "isInitialized": "isInitialized(): boolean;",
    "isWindowCloseRequested": "isWindowCloseRequested(): boolean;",
    "isLightingEnabled": "isLightingEnabled(): boolean;",
    "isModelValid": "isModelValid(model: RLHandle): boolean;",
    "isModelValidStrict": "isModelValidStrict(model: RLHandle): boolean;",
    "isMusicPlaying": "isMusicPlaying(music: RLHandle): boolean;",
    "isSoundPlaying": "isSoundPlaying(sound: RLHandle): boolean;",
    "fileioGetAssetHost": "fileioGetAssetHost(): string;",
    "fileioSetAssetHost": "fileioSetAssetHost(assetHost: string): number;",
    "fileioGetBaseDir": "fileioGetBaseDir(): string;",
    "fileioNormalizePath": "fileioNormalizePath(path: string): string;",
    "fileioGetTaskPath": "fileioGetTaskPath(task: number): string;",
    "getPlatform": "getPlatform(): string;",
    "getVersionLabel": "getVersionLabel(): string;",
    "getVersionString": "getVersionString(): string;",
    "getVersionMajor": "getVersionMajor(): number;",
    "getVersionMinor": "getVersionMinor(): number;",
    "getVersionPatch": "getVersionPatch(): number;",
    "getVersionNumber": "getVersionNumber(): number;",
    "getMouseState": "getMouseState(): RLMouseState;",
    "getKeyboardState": "getKeyboardState(): RLKeyboardState;",
    "getGamepads": "getGamepads(): RLGamepadState[];",
    "getGamepad": "getGamepad(id: number): RLGamepadState | null;",
    "getTouchpoints": "getTouchpoints(): RLTouchpoint[];",
    "getTouchpoint": "getTouchpoint(id: number): RLTouchpoint | null;",
    "getScreenSize": "getScreenSize(): RLVector2;",
    "getWindowPosition": "getWindowPosition(): RLVector2;",
    "getMonitorPosition": "getMonitorPosition(monitor?: number): RLVector2;",
    "getMousePosition": "getMousePosition(): RLVector2;",
    "measureTextEx": "measureTextEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;",
    "pickModel": "pickModel(camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number): RLPickResult;",
    "pickSprite3d": "pickSprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number): RLPickResult;",
    "getSprite3dTransform": "getSprite3dTransform(sprite: RLHandle): RLSprite3dTransform;",
    "emitEvent": "emitEvent(eventName: string, payload?: number): number;",
    "onEvent": "onEvent(eventName: string, callback: RLEventCallback): number;",
    "onceEvent": "onceEvent(eventName: string, callback: RLEventCallback): number;",
    "offEvent": "offEvent(eventName: string, callback: RLEventCallback): number;",
    "tick": "tick(): number;",
    "getDefaultFont": "getDefaultFont(): RLHandle;",
    "getDefaultCamera3d": "getDefaultCamera3d(): RLHandle;",
    "getDefaultTexture": "getDefaultTexture(): RLHandle;",
    "createText2d": "createText2d(font: RLHandle, size: number): RLHandle;",
    "setText2dFont": "setText2dFont(handle: RLHandle, font: RLHandle): void;",
    "setText2dSize": "setText2dSize(handle: RLHandle, size: number): void;",
    "setText2dContent": "setText2dContent(handle: RLHandle, content: string): void;",
    "setText2dPosition": "setText2dPosition(handle: RLHandle, x: number, y: number): void;",
    "setText2dColor": "setText2dColor(handle: RLHandle, color: RLHandle): void;",
    "drawText2d": "drawText2d(handle: RLHandle): void;",
    "destroyText2d": "destroyText2d(handle: RLHandle): void;",
    "getActiveCamera3d": "getActiveCamera3d(): RLHandle;",
    "helpers": "helpers: RLHelpers;",
}

HELPER_SIGNATURE_OVERRIDES: dict[str, str] = {
    "waitForFileioReady": "waitForFileioReady(timeoutMs?: number): Promise<boolean>;",
    "taskIsValid": "taskIsValid(task: number): boolean;",
    "waitForTask": "waitForTask(task: number, pollMs?: number): Promise<number>;",
    "waitForFileioRestoreAsync": "waitForFileioRestoreAsync(): Promise<number>;",
    "waitForFileioEnsureAsync": "waitForFileioEnsureAsync(localPath: string, src?: string | null): Promise<number>;",
    "waitForFileioEnsureGroupAsync": "waitForFileioEnsureGroupAsync(filenames: string[]): Promise<number>;",
    "createTaskGroup": "createTaskGroup<T = unknown>(onComplete?: RLTaskGroupCallback<T> | null, onError?: RLTaskGroupCallback<T> | null, ctx?: T): RLTaskGroup<T>;",
    "getScreenWidth": "getScreenWidth(): number;",
    "getScreenHeight": "getScreenHeight(): number;",
    "getPickStats": "getPickStats(): RLPickStats;",
}

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
  position: RLVector3;
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
  fileioBaseDir?: string;
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


def split_sections(text: str) -> tuple[str, str]:
    helpers_idx = text.index("RL.helpers = {")
    rl_part = text[:helpers_idx]
    helpers_part = text[helpers_idx:]
    rl_start = rl_part.index("const RL = {")
    rl_body = rl_part[rl_start + len("const RL = {") : rl_part.rindex("};")]
    helpers_start = helpers_part.index("RL.helpers = {")
    helpers_body = helpers_part[helpers_start + len("RL.helpers = {") : helpers_part.rindex("};")]
    return rl_body, helpers_body


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


def generate(root: Path) -> None:
    rl_js_path = root / "bindings" / "js" / "rl.js"
    out_path = root / "types" / "librl.d.ts"
    text = rl_js_path.read_text(encoding="utf-8")

    rl_body, helpers_body = split_sections(text)
    rl_entries = parse_entries(rl_body, public_only=True)
    helper_entries = parse_entries(helpers_body, public_only=False)
    if not any(name == "helpers" for name, _ in rl_entries):
        rl_entries.insert(0, ("helpers", "method"))

    color_names = parse_color_names(text)
    color_constants = [f"COLOR_{name}" for name in color_names]

    helpers_iface = emit_interface("RLHelpers", helper_entries, HELPER_SIGNATURE_OVERRIDES, [])
    rl_iface = emit_interface(
        "RLApi",
        rl_entries,
        SIGNATURE_OVERRIDES,
        color_constants,
    )

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
