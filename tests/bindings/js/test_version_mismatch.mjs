#!/usr/bin/env node
/**
 * Version policy via RL.boot(): major/minor mismatch → BOOT_ERR_VERSION_MISMATCH;
 * patch drift → BOOT_OK.
 *
 * Driver mode patches bindings/js/gen/rl_version.ts, rebundles, and spawns
 * per case (ESM caches static imports within a process). Restores gen on exit.
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const genTsPath = path.join(root, 'bindings/js/gen/rl_version.ts');
const librlJs = path.join(root, 'lib/librl.js');
const bindingsRlBase = path.join(root, 'bindings/js/dist/rl.js');
const selfPath = fileURLToPath(import.meta.url);

function assertJspi() {
    if (typeof WebAssembly?.Suspending !== 'function') {
        throw new Error('test_version_mismatch: need Node >= 25 with JSPI (WebAssembly.Suspending)');
    }
}

function bundleBinding() {
    const result = spawnSync('npm', ['run', 'bundle', '--prefix', 'bindings/js'], {
        cwd: root,
        stdio: 'inherit',
    });
    if (result.status !== 0) {
        throw new Error('failed to bundle bindings/js');
    }
}

function writeGen(major, minor, patch) {
    fs.writeFileSync(
        genTsPath,
        `/* GENERATED — DO NOT EDIT (test override) */
export const RL_BINDING_BUILT_MAJOR = ${major};
export const RL_BINDING_BUILT_MINOR = ${minor};
export const RL_BINDING_BUILT_PATCH = ${patch};
export const RL_BINDING_BUILT_VERSION_STRING = "${major}.${minor}.${patch}";
`,
        'utf8',
    );
    bundleBinding();
}

async function workerMain(mode) {
    assertJspi();
    const bindingsRl = `${bindingsRlBase}?worker=${Date.now()}`;
    const { rl: RL } = await import(bindingsRl);
    const rc = await RL.boot({
        modulePath: librlJs,
        env: {
            locateFile: (p) => path.join(root, 'lib', p),
        },
    });

    if (mode === 'mismatch' && rc === RL.BOOT_ERR_VERSION_MISMATCH) {
        process.exit(0);
    }
    if (mode === 'ok' && rc === RL.BOOT_OK) {
        process.exit(0);
    }

    console.error(`worker: expected ${mode}, boot() returned ${rc}`);
    process.exit(1);
}

function runWorker(mode) {
    const result = spawnSync(process.execPath, [selfPath, '--worker', mode], {
        cwd: root,
        stdio: 'inherit',
    });
    if (result.status !== 0) {
        throw new Error(`worker --worker ${mode} failed with exit ${result.status ?? 'signal'}`);
    }
}

function expectVersionMismatch(label, major, minor, patch) {
    writeGen(major, minor, patch);
    runWorker('mismatch');
    console.log(`OK: ${label} — boot() returned BOOT_ERR_VERSION_MISMATCH`);
}

function expectBootOk(label, major, minor, patch) {
    writeGen(major, minor, patch);
    runWorker('ok');
    console.log(`OK: ${label} — boot() returned BOOT_OK (patch drift is non-fatal)`);
}

async function driverMain() {
    if (!fs.existsSync(genTsPath)) {
        console.error(`test_version_mismatch: missing ${genTsPath} (run make binding-version)`);
        process.exit(1);
    }

    if (!fs.existsSync(librlJs)) {
        console.error(`test_version_mismatch: missing ${librlJs} (run make wasm)`);
        process.exit(1);
    }

    assertJspi();

    const originalGen = fs.readFileSync(genTsPath, 'utf8');

    try {
        expectVersionMismatch('major mismatch (9.0.1 vs runtime)', 9, 0, 1);
        expectVersionMismatch('minor mismatch (0.9.1 vs runtime)', 0, 9, 1);
        expectBootOk('patch drift (0.0.9 vs runtime)', 0, 0, 9);
    } finally {
        fs.writeFileSync(genTsPath, originalGen, 'utf8');
        bundleBinding();
    }
}

const args = process.argv.slice(2);
if (args[0] === '--worker') {
    await workerMain(args[1]);
} else {
    await driverMain();
}
