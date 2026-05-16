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

export interface WatchEntry {
  dir: string;
  ext: string;
  recursive: boolean;
}

export interface PerClientWatchOptions {
  /** Project `public/` folder; asset paths are posix paths relative to this. */
  publicRoot: string;
  entries: WatchEntry[];
  debounceMs?: number;
  onFileChanged: (assetPath: string, ext: string) => void;
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
  const pending = new Set<string>();
  let timer: ReturnType<typeof setTimeout> | null = null;

  function flush() {
    timer = null;
    for (const abs of pending) {
      const lower = abs.toLowerCase();
      // find the first matching entry ext
      for (const entry of options.entries) {
        const ext = entry.ext.startsWith(".") ? entry.ext.toLowerCase() : `.${entry.ext.toLowerCase()}`;
        if (lower.endsWith(ext)) {
          const assetPath = toAssetPath(options.publicRoot, abs);
          if (assetPath != null) {
            options.onFileChanged(assetPath, ext);
          }
          break;
        }
      }
    }
    pending.clear();
  }

  function schedule(absPath: string) {
    pending.add(absPath);
    if (timer != null) clearTimeout(timer);
    timer = setTimeout(flush, debounceMs);
  }

  const stoppers: Array<() => void> = [];

  for (const entry of options.entries) {
    const ext = entry.ext.startsWith(".") ? entry.ext.toLowerCase() : `.${entry.ext.toLowerCase()}`;
    const watchDir = path.isAbsolute(entry.dir)
      ? entry.dir
      : path.resolve(options.publicRoot, entry.dir);

    try {
      const watcher = watch(
        watchDir,
        { recursive: entry.recursive },
        (event, filename) => {
          if (!filename) return;
          const full = path.resolve(watchDir, String(filename));
          if (!full.toLowerCase().endsWith(ext)) return;
          if (event !== "change" && event !== "rename") return;
          schedule(full);
        },
      );
      watcher.on("error", (err: Error) => {
        console.error(`[watch] fs.watch error on ${watchDir}:`, err);
      });
      stoppers.push(() => watcher.close());
      console.log(`[watch] client watching [${ext}] under ${watchDir} (recursive=${entry.recursive})`);
    } catch (err) {
      console.error(`[watch] failed to watch ${watchDir}:`, err);
    }
  }

  return () => {
    for (const stop of stoppers) stop();
    if (timer != null) clearTimeout(timer);
  };
}

/** Default `nimrltest/public` when running from `reload_server/src`. */
export function defaultPublicRoot(): string {
  // import.meta.dir = .../nimrltest/reload_server/src → up 2 → nimrltest/, then public/
  return path.resolve(import.meta.dir, "../../../www/public");
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
