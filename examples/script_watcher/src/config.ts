import * as path from "path";

export interface StaticMount {
  prefix: string;
  root: string;
}

export interface ServerConfig {
  enableTls: boolean;
  keysDir: string;
  tlsCert: string;
  tlsKey: string;
  host: string;
  port: number;
  publicRoot: string;
  siteRoot: string;
  watchDebounceMs: number;
  httpMounts: StaticMount[];
}

const DEFAULT_ENABLE_TLS = false;
const DEFAULT_PORT = 9001;
const DEFAULT_HOST = "0.0.0.0";

function parseBoolean(raw: string | undefined, defaultValue: boolean): boolean {
  if (raw == null || raw.trim().length === 0) {
    return defaultValue;
  }
  const normalized = raw.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) {
    return true;
  }
  if (["0", "false", "no", "off"].includes(normalized)) {
    return false;
  }
  throw new Error(`[ERROR] Invalid boolean env value: ${raw}`);
}

function parsePort(raw: string | undefined): number {
  if (!raw) {
    return DEFAULT_PORT;
  }
  const parsed = Number(raw);
  if (Number.isFinite(parsed) && Number.isInteger(parsed) && parsed > 0) {
    return parsed;
  }
  throw new Error(`[ERROR] Invalid port from env.RL_REMOTE_PORT: ${raw}`);
}

function parseTlsEnabled(): boolean {
  return parseBoolean(Bun.env.RL_REMOTE_ENABLE_TLS, DEFAULT_ENABLE_TLS);
}

function resolvePath(raw: string, label: string): string {
  const resolved = path.isAbsolute(raw) ? raw : path.resolve(raw);
  return resolved;
}

/** Default `examples/www/public` when running from `script_watcher/src`. */
export function defaultPublicRoot(): string {
  return path.resolve(import.meta.dir, "../../www/public");
}

/** Default `examples/www` (HTML shell + merged public URLs). */
export function defaultSiteRoot(): string {
  return path.resolve(import.meta.dir, "../../www");
}

function normalizeMountPrefix(prefix: string): string {
  let normalized = prefix.trim();
  if (!normalized.startsWith("/")) {
    normalized = `/${normalized}`;
  }
  return normalized.replace(/\/+$/, "") || "/";
}

function parseMountPairs(raw: string, label: string): StaticMount[] {
  const mounts: StaticMount[] = [];
  for (const entry of raw.split(";")) {
    const trimmed = entry.trim();
    if (trimmed.length === 0) {
      continue;
    }
    const eq = trimmed.indexOf("=");
    if (eq <= 0 || eq === trimmed.length - 1) {
      throw new Error(
        `[ERROR] Invalid ${label} mount (expected /prefix=path): ${trimmed}`,
      );
    }
    const prefix = normalizeMountPrefix(trimmed.slice(0, eq));
    const root = resolvePath(trimmed.slice(eq + 1), label);
    mounts.push({ prefix, root });
  }
  return mounts.sort((a, b) => b.prefix.length - a.prefix.length);
}

export function loadServerConfig(): ServerConfig {
  const enableTls = parseTlsEnabled();
  const keysDir = Bun.env.KEYS_DIR || "";
  const tlsCert = path.join(keysDir, "cert.pem");
  const tlsKey = path.join(keysDir, "privkey.pem");
  const host = process.env.RL_REMOTE_HOST || DEFAULT_HOST;
  const port = parsePort(process.env.RL_REMOTE_PORT || process.env.PORT);

  const publicRoot = resolvePath(
    Bun.env.RL_REMOTE_PUBLIC_ROOT ?? defaultPublicRoot(),
    "RL_REMOTE_PUBLIC_ROOT",
  );
  const siteRoot = resolvePath(
    Bun.env.RL_REMOTE_HTTP_ROOT ?? defaultSiteRoot(),
    "RL_REMOTE_HTTP_ROOT",
  );

  const watchDebounceMs = (() => {
    const v = Number.parseInt(Bun.env.RL_REMOTE_WATCH_DEBOUNCE_MS ?? "150", 10);
    return Number.isFinite(v) ? v : 150;
  })();

  const httpMounts =
    Bun.env.RL_REMOTE_HTTP_MOUNTS != null && Bun.env.RL_REMOTE_HTTP_MOUNTS.length > 0
      ? parseMountPairs(Bun.env.RL_REMOTE_HTTP_MOUNTS, "RL_REMOTE_HTTP_MOUNTS")
      : [];

  return {
    enableTls,
    keysDir,
    tlsCert,
    tlsKey,
    host,
    port,
    publicRoot,
    siteRoot,
    watchDebounceMs,
    httpMounts,
  };
}
