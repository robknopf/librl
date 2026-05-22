#!/usr/bin/env node
/**
 * Namespace shape smoke after boot: sections exist and expose expected callables.
 */
import {
    assertJspi,
    assertTrue,
    assertType,
    bootRl,
    importRl,
} from './helpers.mjs';

assertJspi();

const { rl: RL } = await importRl();
await bootRl(RL);

const namespaces = [
    'fs', 'asset', 'event', 'window', 'render', 'camera3d', 'shape', 'debug',
    'text', 'texture', 'input', 'color', 'font', 'model', 'pick', 'music',
    'sound', 'sprite3d', 'sprite2d', 'text2d', 'logger', 'helpers',
];

for (const name of namespaces) {
    assertType(RL[name], 'object', `RL.${name}`);
}

const callableChecks = [
    ['fs', 'isReady'],
    ['fs', 'getRootDir'],
    ['fs', 'normalizePath'],
    ['asset', 'getHost'],
    ['asset', 'pollTask'],
    ['event', 'on'],
    ['window', 'getScreenSize'],
    ['input', 'getKeyboardState'],
    ['color', 'create'],
    ['helpers', 'taskIsValid'],
    ['helpers', 'getPickStats'],
    ['logger', 'setLevel'],
];

for (const [ns, method] of callableChecks) {
    assertType(RL[ns][method], 'function', `RL.${ns}.${method}`);
}

assertType(RL.fs.isReady(), 'boolean', 'RL.fs.isReady()');
assertType(RL.fs.getRootDir(), 'string', 'RL.fs.getRootDir()');
assertEqPath(RL.fs.normalizePath('/cache/foo'), '/cache/foo', 'normalizePath passthrough');

assertType(RL.helpers.taskIsValid(0), 'boolean', 'RL.helpers.taskIsValid(0)');

const stats = RL.helpers.getPickStats();
assertType(stats.broadphaseTests, 'number', 'pickStats.broadphaseTests');
assertType(stats.narrowphaseHits, 'number', 'pickStats.narrowphaseHits');

assertType(RL.color.WHITE, 'number', 'color.WHITE patched after boot');
assertType(RL.color.BLACK, 'number', 'color.BLACK patched after boot');
assertTrue(RL.color.WHITE !== 0, 'color.WHITE is non-zero after boot');

function assertEqPath(actual, expected, label) {
    if (actual !== expected) {
        throw new Error(`${label}: expected ${expected}, got ${actual}`);
    }
}

console.log('namespace smoke passed');
