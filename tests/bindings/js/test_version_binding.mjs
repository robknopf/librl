#!/usr/bin/env node
/**
 * rl.js binding: built stamp matches runtime after boot; validateVersion succeeds.
 */
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const bindingsRl = path.join(root, 'bindings/js/dist/rl.js');
const librlJs = path.join(root, 'lib/librl.js');

const {
    rl: RL,
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
} = await import(bindingsRl);

await RL.boot({
    modulePath: librlJs,
    env: {
        locateFile: (p) => path.join(root, 'lib', p),
    },
});

function assertEq(actual, expected, label) {
    if (actual !== expected) {
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
    }
}

assertEq(RL.getVersionMajor(), RL_BINDING_BUILT_MAJOR, 'getVersionMajor vs binding stamp');
assertEq(RL.getVersionMinor(), RL_BINDING_BUILT_MINOR, 'getVersionMinor vs binding stamp');
assertEq(RL.getVersionPatch(), RL_BINDING_BUILT_PATCH, 'getVersionPatch vs binding stamp');

process.exit(0);
