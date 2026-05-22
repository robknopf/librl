#!/usr/bin/env node
/**
 * Init API smoke in Node: preconditions and init pipeline up to DOM/window/GLFW.
 *
 * Full init → tick → deinit requires a browser (canvas + window + document). See
 * tests/headless/idbfs_probe_rl.html for a browser integration probe.
 */
import {
    assertEq,
    assertJspi,
    assertTrue,
    bootRl,
    importRl,
    librlJs,
    bootEnv,
} from './helpers.mjs';

assertJspi();

const { rl: RL } = await importRl();

try {
    RL.initAsync({ windowWidth: 64, windowHeight: 64, windowTitle: 'smoke' });
    throw new Error('initAsync before boot should throw');
} catch (err) {
    assertTrue(
        String(err.message || err).includes('Module must be booted'),
        'initAsync before boot error message',
    );
}

let initError = null;
try {
    await RL.init({
        windowWidth: 64,
        windowHeight: 64,
        windowTitle: 'smoke-test',
        windowFlags: RL.FLAG_WINDOW_HIDDEN,
        modulePath: librlJs,
        env: bootEnv(),
    });
} catch (err) {
    initError = err;
}

assertTrue(initError !== null, 'init in Node should fail without DOM');
assertDomBoundaryError(initError, 'await rl.init()');
assertEq(RL.isInitialized(), false, 'isInitialized after failed init');

await bootRl(RL);

let initAsyncError = null;
try {
    RL.initAsync({
        windowWidth: 64,
        windowHeight: 64,
        windowTitle: 'smoke-test',
        windowFlags: RL.FLAG_WINDOW_HIDDEN,
    });
} catch (err) {
    initAsyncError = err;
}

assertTrue(initAsyncError !== null, 'initAsync in Node should fail without DOM');
assertDomBoundaryError(initAsyncError, 'rl.initAsync()');
assertEq(RL.isInitialized(), false, 'isInitialized after failed initAsync');

function assertDomBoundaryError(err, label) {
    const msg = String(err?.message || err);
    assertTrue(
        err instanceof ReferenceError && (msg.includes('window') || msg.includes('document')),
        `${label} fails at DOM/window boundary (expected in Node): ${msg}`,
    );
}

console.log('init smoke passed (Node: DOM boundary verified; browser init deferred)');
