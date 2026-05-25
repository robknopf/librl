import { existsSync, statSync } from "fs";
import * as path from "path";
import type { StaticMount } from "./config";

export interface StaticServeOptions {
  publicRoot: string;
  siteRoot: string;
  mounts: StaticMount[];
}

function resolveSafeFile(root: string, relativePath: string): string | null {
  const rel = relativePath.replace(/^\/+/, "");
  if (rel.includes("\0")) {
    return null;
  }
  const segments = rel.split(/[/\\]/);
  if (segments.some((segment) => segment === "..")) {
    return null;
  }

  const candidate = path.resolve(root, rel);
  const normalizedRoot = path.resolve(root);
  if (
    !(
      candidate === normalizedRoot ||
      candidate.startsWith(normalizedRoot + path.sep)
    )
  ) {
    return null;
  }
  return candidate;
}

async function fileResponse(
  filePath: string,
  headOnly: boolean,
): Promise<Response | null> {
  const file = Bun.file(filePath);
  if (!(await file.exists())) {
    return null;
  }

  const stat = statSync(filePath);
  if (!stat.isFile()) {
    return null;
  }

  const headers = {
    "Content-Type": file.type || "application/octet-stream",
    "Cache-Control": "no-store",
  };

  if (headOnly) {
    return new Response(null, {
      status: 200,
      headers: {
        ...headers,
        "Content-Length": String(stat.size),
      },
    });
  }

  return new Response(file, { headers });
}

async function tryServeFromRoot(
  root: string,
  relativePath: string,
  headOnly: boolean,
): Promise<Response | null> {
  const filePath = resolveSafeFile(root, relativePath);
  if (!filePath || !existsSync(filePath)) {
    return null;
  }
  return fileResponse(filePath, headOnly);
}

function pathnameToRelative(pathname: string): string {
  const trimmed = pathname.replace(/\/+$/, "");
  if (trimmed.length === 0 || trimmed === "/") {
    return "index.html";
  }
  return trimmed.replace(/^\/+/, "");
}

export async function serveStaticRequest(
  req: Request,
  url: URL,
  options: StaticServeOptions,
): Promise<Response> {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { Allow: "GET, HEAD" },
    });
  }

  const headOnly = req.method === "HEAD";
  const relativePath = pathnameToRelative(url.pathname);

  for (const mount of options.mounts) {
    const prefix = mount.prefix;
    if (url.pathname === prefix || url.pathname.startsWith(`${prefix}/`)) {
      const rest =
        url.pathname.length === prefix.length
          ? "index.html"
          : url.pathname.slice(prefix.length + 1);
      const response = await tryServeFromRoot(mount.root, rest, headOnly);
      if (response) {
        return response;
      }
      break;
    }
  }

  // Match Vite: files under public/ shadow the site root at the same URL.
  for (const root of [options.publicRoot, options.siteRoot]) {
    const response = await tryServeFromRoot(root, relativePath, headOnly);
    if (response) {
      return response;
    }
  }

  return new Response("Not Found", { status: 404 });
}
