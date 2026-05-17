#!/usr/bin/env node
/**
 * Query librl version from wasm and compare in the test harness (bindings do the same locally).
 */
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const librlJs = path.join(root, 'lib/librl.js');

function compareBindingVersion(builtMajor, builtMinor, builtPatch, runtimeMajor, runtimeMinor, runtimePatch) {
    if (runtimeMajor !== builtMajor) {
        return -1;
    }
    if (runtimeMinor !== builtMinor) {
        return -2;
    }
    if (runtimePatch !== builtPatch) {
        return 1;
    }
    return 0;
}

const factory = (await import(librlJs)).default;
const Module = await factory({
    locateFile: (p) => path.join(root, 'lib', p),
});

const major = Module.ccall('rl_version_major', 'number', [], []);
const minor = Module.ccall('rl_version_minor', 'number', [], []);
const patch = Module.ccall('rl_version_patch', 'number', [], []);

function assertEq(actual, expected, label) {
    if (actual !== expected) {
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
    }
}

assertEq(compareBindingVersion(major, minor, patch, major, minor, patch), 0, 'exact match');
assertEq(compareBindingVersion(major, minor, patch + 1, major, minor, patch), 1, 'patch drift');
assertEq(compareBindingVersion(major, minor + 1, patch, major, minor, patch), -2, 'minor mismatch');
assertEq(compareBindingVersion(major + 1, minor, patch, major, minor, patch), -1, 'major mismatch');

process.exit(0);
