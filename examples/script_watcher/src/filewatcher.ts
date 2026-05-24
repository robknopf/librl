import { watch } from "node:fs";
import * as path from "path";

/**
 * Watches a directory tree for changes to files matching a configurable set
 * of extensions and notifies via callback.
 *
 * Env (read by callers; see server.ts):
 * - `RL_REMOTE_PUBLIC_ROOT` — absolute path to `public/` (used to turn
 *   absolute paths into loader paths like `assets/...`).
 * - `RL_REMOTE_WATCH_ROOT` — absolute path of directory to watch recursively.
 * - `RL_REMOTE_WATCH_EXTS` — comma-separated extensions (e.g. `.cppia,.wasm`).
 * - `RL_REMOTE_WATCH_DEBOUNCE_MS` — debounce window (default 150).
 *
 * Requires `fs.watch(..., { recursive: true })` support (Node 19+ / current Bun on Linux).
 */
export interface FileWatchOptions {
  /** Project `public/` folder; asset paths are posix paths relative to this. */
  publicRoot: string;
  /** Root directory to watch (recursive). */
  watchRoot: string;
  /** File extensions to react to. Include the leading dot, e.g. `[".cppia", ".wasm"]`. */
  extensions: string[];
  debounceMs?: number;
  onFileChanged: (assetPath: string, ext: string) => void;
}

/**
 * Per-client watch request: directory `dir` relative to `public/`, file `ext`,
 * and optional `recursive` tree watch.
 */
export interface WatchEntry {
  /** Directory relative to `public/` (e.g. `assets/scripts/haxe`). */
  dir: string;
  /** File extension filter including leading dot (e.g. `.js`). */
  ext: string;
  recursive?: boolean;
}

export interface PerClientWatchOptions {
  publicRoot: string;
  entries: WatchEntry[];
  debounceMs?: number;
  onFileChanged: (assetPath: string, ext: string) => void;
}

interface ResolvedWatch {
  watchDir: string;
  ext: string;
  recursive: boolean;
}

function normalizeExt(ext: string): string {
  const trimmed = ext.trim().toLowerCase();
  return trimmed.startsWith(".") ? trimmed : `.${trimmed}`;
}

function normalizeExtensions(exts: string[]): string[] {
  const out: string[] = [];
  for (const raw of exts) {
    const trimmed = raw.trim().toLowerCase();
    if (trimmed.length === 0) continue;
    out.push(trimmed.startsWith(".") ? trimmed : `.${trimmed}`);
  }
  return out;
}

function matchExtension(file: string, exts: string[]): string | null {
  const lower = file.toLowerCase();
  for (const ext of exts) {
    if (lower.endsWith(ext)) return ext;
  }
  return null;
}

function toAssetPath(publicRoot: string, absoluteFile: string): string | null {
  const rel = path.relative(publicRoot, path.resolve(absoluteFile));
  if (rel.startsWith("..")) {
    console.warn(
      `[watch] ignored path outside public root: ${absoluteFile} (publicRoot=${publicRoot})`,
    );
    return null;
  }
  return rel.split(path.sep).join("/");
}

function resolveWatchDir(entry: WatchEntry, publicRoot: string): string {
  return path.isAbsolute(entry.dir)
    ? entry.dir
    : path.resolve(publicRoot, entry.dir);
}

function resolveWatchEntry(
  entry: WatchEntry,
  publicRoot: string,
): ResolvedWatch | null {
  if (!entry.dir) {
    console.warn("[watch] watch entry missing dir");
    return null;
  }
  if (!entry.ext) {
    console.warn("[watch] watch entry missing ext");
    return null;
  }
  return {
    watchDir: resolveWatchDir(entry, publicRoot),
    ext: normalizeExt(entry.ext),
    recursive: entry.recursive ?? false,
  };
}

export function startFileWatcher(options: FileWatchOptions): () => void {
  const debounceMs = options.debounceMs ?? 150;
  const extensions = normalizeExtensions(options.extensions);
  if (extensions.length === 0) {
    console.warn(
      "[watch] startFileWatcher called with no extensions; nothing will be reported.",
    );
  }

  let timer: ReturnType<typeof setTimeout> | null = null;
  const pending = new Set<string>();

  function flush() {
    timer = null;
    for (const abs of pending) {
      const ext = matchExtension(abs, extensions);
      if (ext == null) continue;
      const assetPath = toAssetPath(options.publicRoot, abs);
      if (assetPath != null) {
        options.onFileChanged(assetPath, ext);
      }
    }
    pending.clear();
  }

  function schedule(absPath: string) {
    pending.add(path.resolve(absPath));
    if (timer != null) {
      clearTimeout(timer);
    }
    timer = setTimeout(flush, debounceMs);
  }

  const watcher = watch(
    options.watchRoot,
    { recursive: true },
    (event, filename) => {
      if (!filename) {
        return;
      }
      const name = String(filename);
      const full = path.resolve(options.watchRoot, name);
      if (matchExtension(full, extensions) == null) {
        return;
      }
      if (event !== "change" && event !== "rename") {
        return;
      }
      schedule(full);
    },
  );

  watcher.on("error", (err: Error) => {
    console.error("[watch] fs.watch error:", err);
  });

  console.log(
    `[watch] Watching [${extensions.join(", ")}] under ${options.watchRoot} → asset base ${options.publicRoot}`,
  );

  return () => {
    watcher.close();
    if (timer != null) {
      clearTimeout(timer);
    }
  };
}

export function startPerClientWatcher(options: PerClientWatchOptions): () => void {
  const debounceMs = options.debounceMs ?? 150;
  const pending = new Set<{ abs: string; spec: ResolvedWatch }>();
  let timer: ReturnType<typeof setTimeout> | null = null;

  const specs = options.entries
    .map((entry) => resolveWatchEntry(entry, options.publicRoot))
    .filter((spec): spec is ResolvedWatch => spec != null);

  function flush() {
    timer = null;
    for (const item of pending) {
      if (!item.abs.toLowerCase().endsWith(item.spec.ext)) {
        continue;
      }
      const assetPath = toAssetPath(options.publicRoot, item.abs);
      if (assetPath != null) {
        options.onFileChanged(assetPath, item.spec.ext);
      }
    }
    pending.clear();
  }

  function schedule(absPath: string, spec: ResolvedWatch) {
    pending.add({ abs: absPath, spec });
    if (timer != null) clearTimeout(timer);
    timer = setTimeout(flush, debounceMs);
  }

  const stoppers: Array<() => void> = [];

  for (const spec of specs) {
    try {
      const watcher = watch(
        spec.watchDir,
        { recursive: spec.recursive },
        (event, filename) => {
          if (!filename) return;
          const full = path.resolve(spec.watchDir, String(filename));
          if (!full.toLowerCase().endsWith(spec.ext)) return;
          if (event !== "change" && event !== "rename") return;
          schedule(full, spec);
        },
      );
      watcher.on("error", (err: Error) => {
        console.error(`[watch] fs.watch error on ${spec.watchDir}:`, err);
      });
      stoppers.push(() => watcher.close());
      console.log(
        `[watch] client watching ${spec.watchDir} [${spec.ext}] (recursive=${spec.recursive})`,
      );
    } catch (err) {
      console.error(`[watch] failed to watch ${spec.watchDir}:`, err);
    }
  }

  return () => {
    for (const stop of stoppers) stop();
    if (timer != null) clearTimeout(timer);
  };
}

/** Default `examples/www/public` when running from `script_watcher/src`. */
export function defaultPublicRoot(): string {
  return path.resolve(import.meta.dir, "../../www/public");
}

/** Default watch root: the project's `public/assets` tree. */
export function defaultWatchRoot(publicRoot: string): string {
  return path.join(publicRoot, "assets");
}

/** Parse a comma-separated `RL_REMOTE_WATCH_EXTS` value, falling back to a default. */
export function parseExtensionsEnv(
  raw: string | undefined,
  fallback: string[],
): string[] {
  if (raw == null || raw.trim().length === 0) {
    return fallback;
  }
  return raw.split(",");
}
