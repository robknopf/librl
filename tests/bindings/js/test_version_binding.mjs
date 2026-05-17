#!/usr/bin/env node
/**
 * rl.js binding: built stamp matches runtime after boot; validateVersion succeeds.
 */
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
} from '../../../bindings/js/gen/rl_version.js';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const bindingsRl = path.join(root, 'bindings/js/rl.js');
const librlJs = path.join(root, 'lib/librl.js');

const { rl: RL } = await import(bindingsRl);

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

assertEq(RL.versionMajor(), RL_BINDING_BUILT_MAJOR, 'versionMajor vs binding stamp');
assertEq(RL.versionMinor(), RL_BINDING_BUILT_MINOR, 'versionMinor vs binding stamp');
assertEq(RL.versionPatch(), RL_BINDING_BUILT_PATCH, 'versionPatch vs binding stamp');
assertEq(RL.validateVersion(), 0, 'validateVersion');

const major = RL.versionMajor();
const minor = RL.versionMinor();
const patch = RL.versionPatch();
assertEq(RL.validateVersionAgainst(major, minor, patch + 1), 1, 'validateVersionAgainst patch drift');
assertEq(RL.validateVersionAgainst(major + 1, minor, patch), -1, 'validateVersionAgainst major mismatch');

process.exit(0);
