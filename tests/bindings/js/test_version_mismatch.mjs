#!/usr/bin/env node
/**
 * Boot rl.js with a mismatched binding stamp (gen file patched by test_version_mismatch.sh).
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../..', import.meta.url));
const bindingsRl = path.join(root, 'bindings/js/rl.js') + '?mismatch=' + Date.now();
const librlJs = path.join(root, 'lib/librl.js');

const { rl: RL } = await import(bindingsRl);

try {
    await RL.boot({
        modulePath: librlJs,
        env: {
            locateFile: (p) => path.join(root, 'lib', p),
        },
    });
    console.error('expected rl.boot() to fail on version mismatch');
    process.exit(0);
} catch (err) {
    const message = String(err && err.message ? err.message : err);
    console.error(message);
    if (!/major|mismatch|differs/i.test(message)) {
        console.error('expected version mismatch message');
        process.exit(2);
    }
    process.exit(1);
}
