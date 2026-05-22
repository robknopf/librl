#!/usr/bin/env node
/**
 * Boot-only smoke: version getters, platform, constants, idempotent boot.
 */
import {
    assertEq,
    assertJspi,
    assertTrue,
    assertType,
    bootEnv,
    bootRl,
    importRl,
    librlJs,
} from './helpers.mjs';

assertJspi();

const {
    rl: RL,
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
} = await importRl();

assertEq(
    await RL.boot({ modulePath: '/nonexistent/librl.js' }),
    RL.BOOT_ERR_LOADER,
    'boot with bad modulePath',
);

const rc = await bootRl(RL);
assertEq(rc, RL.BOOT_OK, 'first boot');

assertEq(await RL.boot({ modulePath: librlJs, env: bootEnv() }), RL.BOOT_OK, 'second boot is idempotent');

assertEq(RL.isInitialized(), false, 'isInitialized before init');
assertType(RL.getPlatform(), 'string', 'getPlatform');
assertTrue(RL.getPlatform().length > 0, 'getPlatform non-empty');

assertEq(RL.getVersionMajor(), RL_BINDING_BUILT_MAJOR, 'getVersionMajor');
assertEq(RL.getVersionMinor(), RL_BINDING_BUILT_MINOR, 'getVersionMinor');
assertEq(RL.getVersionPatch(), RL_BINDING_BUILT_PATCH, 'getVersionPatch');
assertType(RL.getVersionString(), 'string', 'getVersionString');
assertTrue(RL.getVersionString().includes('.'), 'getVersionString looks like semver');
assertType(RL.versionLabel(), 'string', 'versionLabel');
assertTrue(RL.getVersionNumber() > 0, 'getVersionNumber');

assertEq(RL.INIT_OK, 0, 'INIT_OK');
assertEq(RL.BOOT_OK, 0, 'BOOT_OK');
assertEq(RL.TICK_RUNNING, 0, 'TICK_RUNNING');
assertTrue(RL.FLAG_MSAA_4X_HINT > 0, 'FLAG_MSAA_4X_HINT');
assertTrue(RL.LOGGER_LEVEL_INFO > 0, 'LOGGER_LEVEL_INFO');

console.log('boot smoke passed');
