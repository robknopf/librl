import { defineConfig } from "vite";
import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import os from "os";

dotenv.config({
  quiet:true
});
const homeDir = os.homedir();

function getSSLKeysPath(): { certPath: string; privKeyPath: string } | null {
  let certsDir = (process.env.CERTS_DIR || path.join(homeDir, "keys")).trim();
  if (!fs.existsSync(certsDir)) {
    console.warn(`Certificates directory not found: ${certsDir}`);
    certsDir = "";
  }

  let hostname = (process.env.HOSTNAME || os.hostname()).trim();

  let privKeyPath = path.join(certsDir, hostname, "privkey.pem");
  if (!fs.existsSync(privKeyPath)) {
    console.warn(`Private key not found: ${privKeyPath}`);
    return null;
  }
  let certPath = path.join(certsDir, hostname, "cert.pem");
  if (!fs.existsSync(certPath)) {
    console.warn(`Certificate not found: ${certPath}`);
    return null;
  }
  return {
    certPath,
    privKeyPath,
  };
}

const sslKeysPaths = getSSLKeysPath();
console.log(`Will use ${sslKeysPaths ? "SSL" : "non-SSL"} connection`);

function contentTypeFor(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case ".html":
      return "text/html; charset=utf-8";
    case ".js":
    case ".mjs":
      return "application/javascript; charset=utf-8";
    case ".css":
      return "text/css; charset=utf-8";
    case ".json":
      return "application/json; charset=utf-8";
    case ".svg":
      return "image/svg+xml";
    case ".png":
      return "image/png";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".wasm":
      return "application/wasm";
    default:
      return "application/octet-stream";
  }
}

export default defineConfig({
  publicDir: "public",
  root:"./examples/www",
  base:'',
  assetsInclude: ["**/*.glb", "**/*.gltf"],
  build: {
    assetsDir: "bundles",
  },
  appType: "mpa", // just so we get a 404 if we try to fetch something that doesn't exist (vs getting index.html again for a SPA)
  define: {
    CONFIG_ENV: JSON.stringify(process.env.CONFIG_ENV),
  },
  resolve: {
    alias: {
      "/examples": path.resolve(__dirname, "examples"),
      "/lib": path.resolve(__dirname, "lib"),
    },
  },
  plugins: [
    {
      name: "examples-mount",
      configureServer(server) {
        const mountPrefix = "/examples/";
        const examplesRoot = path.resolve(__dirname, "examples");

        server.middlewares.use((req, res, next) => {
          const reqUrl = req.url || "";
          const cleanUrl = reqUrl.split("?")[0].split("#")[0];
          if (!cleanUrl.startsWith(mountPrefix)) {
            next();
            return;
          }

          const relativePath = decodeURIComponent(cleanUrl.slice(mountPrefix.length));
          const fullPath = path.resolve(examplesRoot, relativePath);

          // Prevent path traversal outside the examples directory.
          if (!fullPath.startsWith(examplesRoot + path.sep)) {
            res.statusCode = 403;
            res.end("Forbidden");
            return;
          }

          if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
            next();
            return;
          }

          res.setHeader("Content-Type", contentTypeFor(fullPath));
          fs.createReadStream(fullPath).pipe(res);
        });
      },
    },
  ],
  server: {
    host: "0.0.0.0",
    port: 4444,
    strictPort: true,

    open: false,
    https: sslKeysPaths
      ? {
          key: fs.readFileSync(sslKeysPaths.privKeyPath),
          cert: fs.readFileSync(sslKeysPaths.certPath),
        }
      : undefined,
    fs: {
      allow: [
        // default roots plus your workspace package
        path.resolve(__dirname),
        path.resolve(__dirname, "../../packages/wg-core"),
        path.resolve(__dirname, "../../packages/wg-renderer"),
      ],
    },
  },
});
