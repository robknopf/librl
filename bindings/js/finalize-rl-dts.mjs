#!/usr/bin/env node
/** Rename tsc output dist/types.d.ts → dist/rl.d.ts (pairs with dist/rl.js). */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const emitted = path.join(here, "dist/types.d.ts");
const dest = path.join(here, "dist/rl.d.ts");

const body = fs.readFileSync(emitted, "utf8").trimEnd();
const header = `/* GENERATED — DO NOT EDIT
 * TypeScript declarations for bindings/js/dist/rl.js
 * from: bindings/js/src/types.ts (npm run build --prefix bindings/js)
 */

`;

fs.writeFileSync(dest, `${header}${body}\n`);
fs.rmSync(emitted, { force: true });
console.log(`generated ${dest}`);
