import { defineConfig } from "vite";
import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import os from "os";
import ViteRestart from "vite-plugin-restart";

dotenv.config({
  quiet: true,
});
const homeDir = os.homedir();

const enableSSLDefault = true;

const enableSSL = enableSSLDefault || process.env.ENABLE_SSL === "1" || process.env.ENABLE_SSL === "true";

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

const sslKeysPaths = enableSSL ? getSSLKeysPath() : null;
console.log(`Will use ${sslKeysPaths ? "SSL" : "non-SSL"} connection`);

export default defineConfig({
  publicDir: "public",
  root: "./examples/www",
  base: "./",
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
      "/bindings": path.resolve(__dirname, "bindings"),
      "/lib": path.resolve(__dirname, "lib"),
    },
  },
  plugins: [
    ViteRestart({
      reload: [
        '../nim/out/wasm/**/*.wasm',
        '../nim/out/wasm/**/*.js',
      ],
      "contentCheck": true,
      "delay": 2000
    }),
    {
      name: "examples-mount",
      configureServer(server) {
        const examplesRoot = path.resolve(__dirname, "examples");
        const bindingsRoot = path.resolve(__dirname, "bindings");
        const libRoot = path.resolve(__dirname, "lib");

        // Ensure files outside `root` that are imported via aliases or custom mounts
        // are watched for HMR/full-reload updates.
        server.watcher.add(path.join(examplesRoot, "**/*"));
        server.watcher.add(path.join(bindingsRoot, "**/*"));
        server.watcher.add(path.join(libRoot, "**/*"));

        const mountExternalDir = (mountPrefix: string, dirRoot: string) => (req, _res, next) => {
          const reqUrl = req.url || "";
          const [cleanUrl, query = ""] = reqUrl.split("?");
          if (!cleanUrl.startsWith(mountPrefix)) {
            next();
            return;
          }

          const relativePath = decodeURIComponent(
            cleanUrl.slice(mountPrefix.length),
          );
          const fullPath = path.resolve(dirRoot, relativePath);

          // Prevent path traversal outside the mounted directory.
          if (
            !(
              fullPath === dirRoot ||
              fullPath.startsWith(dirRoot + path.sep)
            )
          ) {
            return;
          }

          req.url = `/@fs/${fullPath.replace(/\\/g, "/")}${query ? `?${query}` : ""}`;
          next();
        };

        server.middlewares.use(mountExternalDir("/examples/", examplesRoot));
        server.middlewares.use(mountExternalDir("/bindings/", bindingsRoot));
      },
    },
  ],
  server: {
    host: "0.0.0.0",
    port: 4444,
    strictPort: true,
    cors: true,
    headers: {
      "access-control-allow-origin": "*",
    },
    open: false,
    https: sslKeysPaths
      ? {
          key: fs.readFileSync(sslKeysPaths.privKeyPath),
          cert: fs.readFileSync(sslKeysPaths.certPath),
        }
      : undefined,
    fs: {
      strict: true,
      allow: [
        // default roots plus your workspace package
        path.resolve(__dirname),
        path.resolve(__dirname, "../../packages/wg-core"),
        path.resolve(__dirname, "../../packages/wg-renderer"),
      ],
    },
  },
});
