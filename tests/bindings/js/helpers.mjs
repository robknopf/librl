#!/usr/bin/env node
/** Shared helpers for tests/bindings/js. */

import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = fileURLToPath(new URL('../../..', import.meta.url));
export const bindingsRl = path.join(root, 'bindings/js/dist/rl.js');
export const librlJs = path.join(root, 'lib/librl.js');

export function assertJspi() {
    if (typeof WebAssembly?.Suspending !== 'function') {
        throw new Error('Need Node >= 25 with JSPI (WebAssembly.Suspending)');
    }
}

export function assertEq(actual, expected, label) {
    if (actual !== expected) {
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
    }
}

export function assertTrue(value, label) {
    if (!value) {
        throw new Error(`${label}: expected truthy, got ${value}`);
    }
}

export function assertType(value, type, label) {
    if (typeof value !== type) {
        throw new Error(`${label}: expected ${type}, got ${typeof value}`);
    }
}

/** Minimal canvas stub for Emscripten Module.canvas (Node has no DOM). */
export function canvasStub() {
    return {
        id: 'renderCanvas',
        width: 64,
        height: 64,
        clientWidth: 64,
        clientHeight: 64,
        style: {},
    };
}

export function bootEnv(extra = {}) {
    return {
        locateFile: (p) => path.join(root, 'lib', p),
        canvas: canvasStub(),
        ...extra,
    };
}

export async function importRl() {
    return import(bindingsRl);
}

export async function bootRl(RL, opts = {}) {
    const rc = await RL.boot({
        modulePath: librlJs,
        env: bootEnv(opts.env),
        ...opts,
    });
    assertEq(rc, RL.BOOT_OK, 'RL.boot');
    return rc;
}
