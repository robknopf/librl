import {
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
    RL_BINDING_BUILT_VERSION_STRING,
} from './gen/rl_version.js';

var moduleInstance;
var moduleFactoryPromise = null;
var moduleFactoryPath = "";
var moduleOptions = {};
var scratchAreaPtr = 0;
var scratchAreaBytePtr = 0;
var scratchAreaOffsets = {};

const RL = {
    _eventDispatchPtr: 0,
    _nextEventListenerId: 1,
    _eventListenersById: new Map(),
    _eventListenerIdsByCallback: new WeakMap(),
    TICK_RUNNING: 0,
    TICK_WAITING: 1,
    TICK_FAILED: -1,
    _dispatchEventFromWasm: (payload, userData) => {
        const listener = RL._eventListenersById.get(userData >>> 0);
        if (!listener || typeof listener.callback !== "function") {
            return;
        }
        listener.callback(payload >>> 0);
    },
    _ensureEventDispatchPtr: () => {
        if (!moduleInstance || RL._eventDispatchPtr !== 0) {
            return;
        }
        RL._eventDispatchPtr = moduleInstance.addFunction(RL._dispatchEventFromWasm, "vii");
    },
    _forgetListenerById: (listenerId) => {
        const listener = RL._eventListenersById.get(listenerId);
        let callbackMap = null;
        if (!listener) {
            return;
        }
        callbackMap = RL._eventListenerIdsByCallback.get(listener.callback);
        if (callbackMap) {
            callbackMap.delete(listener.eventName);
        }
        RL._eventListenersById.delete(listenerId);
    },
    _clearListenerCacheForEvent: (eventName) => {
        const idsToDelete = [];
        RL._eventListenersById.forEach((listener, id) => {
            if (listener && listener.eventName === eventName) {
                idsToDelete.push(id);
            }
        });
        idsToDelete.forEach((id) => RL._forgetListenerById(id));
    },
    _clearRunCallbacks: () => {
        /* Reserved for symmetry with deinit; run/start/stop removed from librl. */
    },
    _installScratchHelpers: () => {
        const Module = moduleInstance;
        if (!Module) {
            return;
        }

        Module.initScratchArea = () => {
            const HEAP32 = Module.HEAP32;
            scratchAreaBytePtr = Module.ccall("rl_scratch_get_base", "number", [], []);
            scratchAreaPtr = scratchAreaBytePtr >> 2;
            const scratchAreaOffsetsPtr = Module.ccall("rl_scratch_get_offsets", "number", [], []) >> 2;

            scratchAreaOffsets = {
                vector2: HEAP32[scratchAreaOffsetsPtr],
                vector3: HEAP32[scratchAreaOffsetsPtr + 1],
                vector4: HEAP32[scratchAreaOffsetsPtr + 2],
                matrix: HEAP32[scratchAreaOffsetsPtr + 3],
                quaternion: HEAP32[scratchAreaOffsetsPtr + 4],
                color: HEAP32[scratchAreaOffsetsPtr + 5],
                rectangle: HEAP32[scratchAreaOffsetsPtr + 6],
                mouse: {
                    x: HEAP32[scratchAreaOffsetsPtr + 7],
                    y: HEAP32[scratchAreaOffsetsPtr + 8],
                    wheel: HEAP32[scratchAreaOffsetsPtr + 9],
                    buttons: HEAP32[scratchAreaOffsetsPtr + 10],
                },
                keyboard: {
                    max_num_keys: HEAP32[scratchAreaOffsetsPtr + 11],
                    keys: HEAP32[scratchAreaOffsetsPtr + 12],
                    pressed_key: HEAP32[scratchAreaOffsetsPtr + 13],
                    pressed_char: HEAP32[scratchAreaOffsetsPtr + 14],
                    num_pressed_keys: HEAP32[scratchAreaOffsetsPtr + 15],
                    pressed_keys: HEAP32[scratchAreaOffsetsPtr + 16],
                    num_pressed_chars: HEAP32[scratchAreaOffsetsPtr + 17],
                    pressed_chars: HEAP32[scratchAreaOffsetsPtr + 18],
                },
                gamepads: {
                    max_num_gamepads: HEAP32[scratchAreaOffsetsPtr + 19],
                    gamepad: HEAP32[scratchAreaOffsetsPtr + 20],
                    id: HEAP32[scratchAreaOffsetsPtr + 21],
                    axis: HEAP32[scratchAreaOffsetsPtr + 22],
                    buttons: HEAP32[scratchAreaOffsetsPtr + 23],
                    stride: HEAP32[scratchAreaOffsetsPtr + 24] >> 2,
                },
                touchpoints: {
                    count: HEAP32[scratchAreaOffsetsPtr + 25],
                    touchpoint: HEAP32[scratchAreaOffsetsPtr + 26],
                    id: HEAP32[scratchAreaOffsetsPtr + 27],
                    x: HEAP32[scratchAreaOffsetsPtr + 28],
                    y: HEAP32[scratchAreaOffsetsPtr + 29],
                    stride: HEAP32[scratchAreaOffsetsPtr + 30] >> 2,
                },
                stringTable: {
                    offsets: HEAP32[scratchAreaOffsetsPtr + 31],
                    bytes: HEAP32[scratchAreaOffsetsPtr + 32],
                    maxEntries: HEAP32[scratchAreaOffsetsPtr + 33],
                    maxBytes: HEAP32[scratchAreaOffsetsPtr + 34],
                },
            };
        };

        Module.getVector2 = () => {
            const HEAPF32 = Module.HEAPF32;
            return {
                x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector2 >> 2)],
                y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector2 >> 2) + 1],
            };
        };

        Module.getVector3 = () => {
            const HEAPF32 = Module.HEAPF32;
            return {
                x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2)],
                y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2) + 1],
                z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2) + 2],
            };
        };

        Module.getVector4 = () => {
            const HEAPF32 = Module.HEAPF32;
            return {
                x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2)],
                y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 1],
                z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 2],
                w: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 3],
            };
        };

        Module.getMatrix = () => {
            const HEAPF32 = Module.HEAPF32;
            const matrixOffset = scratchAreaPtr + (scratchAreaOffsets.matrix >> 2);
            return HEAPF32.subarray(matrixOffset, matrixOffset + 16);
        };

        Module.getQuaternion = () => {
            const HEAPF32 = Module.HEAPF32;
            return {
                x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2)],
                y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 1],
                z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 2],
                w: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 3],
            };
        };

        Module.getColor = () => {
            const HEAP32 = Module.HEAP32;
            return {
                r: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2)],
                g: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 1],
                b: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 2],
                a: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 3],
            };
        };

        Module.getRectangle = () => {
            const HEAP32 = Module.HEAP32;
            return {
                x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2)],
                y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 1],
                width: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 2],
                height: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 3],
            };
        };

        Module.getMouseState = () => {
            const HEAP32 = Module.HEAP32;
            return {
                x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.x >> 2)],
                y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.y >> 2)],
                wheel: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.wheel >> 2)],
                buttons: HEAP32.subarray(
                    scratchAreaPtr + (scratchAreaOffsets.mouse.buttons >> 2),
                    scratchAreaPtr + (scratchAreaOffsets.mouse.buttons >> 2) + 3
                ),
            };
        };

        Module.getKeyboard = () => {
            const HEAP32 = Module.HEAP32;
            return {
                max_num_keys: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.max_num_keys >> 2)],
                keys: HEAP32.subarray(
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.keys >> 2),
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.keys >> 2) +
                    HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.max_num_keys >> 2)]
                ),
                pressed_key: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_key >> 2)],
                pressed_char: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_char >> 2)],
                num_pressed_keys: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.num_pressed_keys >> 2)],
                pressed_keys: HEAP32.subarray(
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_keys >> 2),
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_keys >> 2) +
                    HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.num_pressed_keys >> 2)]
                ),
                num_pressed_chars: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.num_pressed_chars >> 2)],
                pressed_chars: HEAP32.subarray(
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_chars >> 2),
                    scratchAreaPtr + (scratchAreaOffsets.keyboard.pressed_chars >> 2) +
                    HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.num_pressed_chars >> 2)]
                ),
            };
        };

        Module.getGamepads = () => {
            const HEAP32 = Module.HEAP32;
            const HEAPF32 = Module.HEAPF32;
            const maxGamepads = HEAP32[scratchAreaPtr + (scratchAreaOffsets.gamepads.max_num_gamepads >> 2)];
            const stride = scratchAreaOffsets.gamepads.stride;
            const baseOffset = scratchAreaPtr + (scratchAreaOffsets.gamepads.gamepad >> 2);
            const gamepads = [];
            for (let i = 0; i < maxGamepads; i++) {
                const gamepadOffset = baseOffset + i * stride;
                gamepads.push({
                    id: HEAP32[gamepadOffset + (scratchAreaOffsets.gamepads.id >> 2)],
                    axis: HEAPF32.subarray(
                        gamepadOffset + (scratchAreaOffsets.gamepads.axis >> 2),
                        gamepadOffset + (scratchAreaOffsets.gamepads.axis >> 2) + 4
                    ),
                    buttons: HEAP32.subarray(
                        gamepadOffset + (scratchAreaOffsets.gamepads.buttons >> 2),
                        gamepadOffset + (scratchAreaOffsets.gamepads.buttons >> 2) + 16
                    ),
                });
            }
            return gamepads;
        };

        Module.getGamepad = (id) => {
            const HEAP32 = Module.HEAP32;
            const HEAPF32 = Module.HEAPF32;
            const maxGamepads = HEAP32[scratchAreaPtr + (scratchAreaOffsets.gamepads.max_num_gamepads >> 2)];
            const stride = scratchAreaOffsets.gamepads.stride;
            const baseOffset = scratchAreaPtr + (scratchAreaOffsets.gamepads.gamepad >> 2);
            for (let i = 0; i < maxGamepads; i++) {
                const gamepadOffset = baseOffset + i * stride;
                if (HEAP32[gamepadOffset + (scratchAreaOffsets.gamepads.id >> 2)] === id) {
                    return {
                        id: HEAP32[gamepadOffset + (scratchAreaOffsets.gamepads.id >> 2)],
                        axis: HEAPF32.subarray(
                            gamepadOffset + (scratchAreaOffsets.gamepads.axis >> 2),
                            gamepadOffset + (scratchAreaOffsets.gamepads.axis >> 2) + 4
                        ),
                        buttons: HEAP32.subarray(
                            gamepadOffset + (scratchAreaOffsets.gamepads.buttons >> 2),
                            gamepadOffset + (scratchAreaOffsets.gamepads.buttons >> 2) + 16
                        ),
                    };
                }
            }
            return null;
        };

        Module.getTouchpoints = () => {
            const HEAP32 = Module.HEAP32;
            const HEAPF32 = Module.HEAPF32;
            const count = HEAP32[scratchAreaPtr + (scratchAreaOffsets.touchpoints.count >> 2)];
            const stride = scratchAreaOffsets.touchpoints.stride;
            const baseOffset = scratchAreaPtr + (scratchAreaOffsets.touchpoints.touchpoint >> 2);
            const touchpoints = [];
            for (let i = 0; i < count; i++) {
                const touchOffset = baseOffset + i * stride;
                touchpoints.push({
                    id: HEAP32[touchOffset + (scratchAreaOffsets.touchpoints.id >> 2)],
                    x: HEAPF32[touchOffset + (scratchAreaOffsets.touchpoints.x >> 2)],
                    y: HEAPF32[touchOffset + (scratchAreaOffsets.touchpoints.y >> 2)],
                });
            }
            return touchpoints;
        };

        Module.getTouchpoint = (id) => {
            const HEAP32 = Module.HEAP32;
            const HEAPF32 = Module.HEAPF32;
            const count = HEAP32[scratchAreaPtr + (scratchAreaOffsets.touchpoints.count >> 2)];
            const stride = scratchAreaOffsets.touchpoints.stride;
            const baseOffset = scratchAreaPtr + (scratchAreaOffsets.touchpoints.touchpoint >> 2);
            for (let i = 0; i < count; i++) {
                const touchOffset = baseOffset + i * stride;
                if (HEAP32[touchOffset + (scratchAreaOffsets.touchpoints.id >> 2)] === id) {
                    return {
                        id: HEAP32[touchOffset + (scratchAreaOffsets.touchpoints.id >> 2)],
                        x: HEAPF32[touchOffset + (scratchAreaOffsets.touchpoints.x >> 2)],
                        y: HEAPF32[touchOffset + (scratchAreaOffsets.touchpoints.y >> 2)],
                    };
                }
            }
            return null;
        };

        Module.writeScratchStringTable = (strings) => {
            const HEAPU32 = Module.HEAPU32;
            const values = Array.isArray(strings) ? strings : [];
            const maxEntries = scratchAreaOffsets.stringTable.maxEntries;
            const maxBytes = scratchAreaOffsets.stringTable.maxBytes;
            const offsetsIndex = scratchAreaPtr + (scratchAreaOffsets.stringTable.offsets >> 2);
            const bytesIndex = scratchAreaBytePtr + scratchAreaOffsets.stringTable.bytes;
            let byteOffset = 0;

            if (values.length > maxEntries) {
                throw new Error(`scratch string table overflow: ${values.length} > ${maxEntries}`);
            }

            for (let i = 0; i < values.length; i++) {
                const text = String(values[i] ?? "");
                const encodedLength = Module.lengthBytesUTF8(text) + 1;
                if (byteOffset + encodedLength > maxBytes) {
                    throw new Error(`scratch string bytes overflow at index ${i}`);
                }
                HEAPU32[offsetsIndex + i] = byteOffset >>> 0;
                Module.stringToUTF8(text, bytesIndex + byteOffset, encodedLength);
                byteOffset += encodedLength;
            }

            return values.length;
        };
    },
    _mallocOrThrow: (size) => {
        const m = moduleInstance && (moduleInstance._malloc || moduleInstance.malloc);
        if (typeof m !== "function") {
            throw new Error("malloc not available in emscripten module (expected _malloc or malloc)");
        }
        const p = m(size) >>> 0;
        if (!p) {
            throw new Error("malloc failed");
        }
        return p;
    },
    _freeIfPossible: (p) => {
        if (!p) {
            return;
        }
        const f = moduleInstance && (moduleInstance._free || moduleInstance.free);
        if (typeof f === "function") {
            f(p);
        }
    },
    _stringToNewUtf8OrNull: (s) => {
        if (s == null) {
            return 0;
        }
        if (typeof s !== "string") {
            s = String(s);
        }
        if (moduleInstance.stringToNewUTF8) {
            return moduleInstance.stringToNewUTF8(s) >>> 0;
        }
        const len = (moduleInstance.lengthBytesUTF8 ? moduleInstance.lengthBytesUTF8(s) : (s.length * 4 + 1)) + 0;
        const bytes = RL._mallocOrThrow(len);
        if (moduleInstance.stringToUTF8) {
            moduleInstance.stringToUTF8(s, bytes, len);
        } else {
            throw new Error("stringToUTF8 not available; cannot encode JS strings to wasm memory");
        }
        return bytes;
    },

    _getModulePath: (opts) => {
        const modulePath = opts?.modulePath ?? moduleOptions.modulePath;
        if (modulePath) {
            return String(modulePath);
        }
        return new URL("../../lib/librl.js", import.meta.url).href;
    },
    _loadModuleFactory: async (opts) => {
        const modulePath = RL._getModulePath(opts);
        if (!moduleFactoryPromise || moduleFactoryPath !== modulePath) {
            moduleFactoryPath = modulePath;
            moduleFactoryPromise = import(/* @vite-ignore */ modulePath).then((mod) => {
                const factory = mod?.default;
                if (typeof factory !== "function") {
                    throw new Error(`raw runtime module missing default factory export: ${modulePath}`);
                }
                return factory;
            });
        }
        return await moduleFactoryPromise;
    },

    _prepareModuleOptions: (opts) => {
        opts = opts || {};
        opts.env = opts.env || {};
        moduleOptions = {
            ...moduleOptions,
            ...opts,
        };
        moduleOptions.env = {
            ...(moduleOptions.env || {}),
            ...opts.env,
        };

        if (moduleOptions.idealWidth == null && moduleOptions.windowWidth != null) {
            moduleOptions.idealWidth = moduleOptions.windowWidth;
        }
        if (moduleOptions.idealHeight == null && moduleOptions.windowHeight != null) {
            moduleOptions.idealHeight = moduleOptions.windowHeight;
        }

        if (moduleOptions.wasmPath && !moduleOptions.env.locateFile) {
            moduleOptions.env.locateFile = function (path, prefix) {
                return path === "librl.wasm" ? moduleOptions.wasmPath : prefix + path;
            };
        }

        // set up env for the Module (browser only; Node callers pass env.canvas or omit)
        if (!moduleOptions.env.canvas && typeof document !== "undefined") {
            const canvasId = moduleOptions.canvasId || "renderCanvas";
            moduleOptions.env.canvas = document.getElementById(canvasId);
        }
        if (!moduleOptions.env.print) {
            moduleOptions.env.print = (...args) => {
                console.log(...args);
            };
        }
        if (!moduleOptions.env.printErr) {
            moduleOptions.env.printErr = (...args) => {
                console.error(...args);
            };
        }
        return moduleOptions;
    },
    _prepareInitOptions: (opts) => {
        opts = opts || {};
        return {
            windowWidth: opts.windowWidth ?? moduleOptions.windowWidth ?? 0,
            windowHeight: opts.windowHeight ?? moduleOptions.windowHeight ?? 0,
            windowTitle: opts.windowTitle ?? moduleOptions.windowTitle ?? "",
            windowFlags: opts.windowFlags ?? moduleOptions.windowFlags ?? 0,
            assetHost: opts.assetHost ?? moduleOptions.assetHost ?? "",
            fsRootDir: opts.fsRootDir ?? moduleOptions.fsRootDir ?? "",
            idealWidth: moduleOptions.idealWidth ?? opts.windowWidth ?? 1024,
            idealHeight: moduleOptions.idealHeight ?? opts.windowHeight ?? 1280,
        };
    },
    _hasJspiSupport: () => {
        return typeof WebAssembly !== "undefined"
            && typeof WebAssembly.Suspending === "function"
            && typeof WebAssembly.promising === "function";
    },
    _tryLoadModuleInstance: async (opts) => {
        RL._prepareModuleOptions(opts);

        if (moduleInstance) {
            return RL.BOOT_OK;
        }

        try {
            const moduleFactory = await RL._loadModuleFactory(opts);
            moduleInstance = await moduleFactory(moduleOptions.env);
        } catch (err) {
            console.error("RL.boot failed", err);
            moduleInstance = null;
            return RL.BOOT_ERR_LOADER;
        }

        if (RL._compareVersion() < 0) {
            moduleInstance = null;
            return RL.BOOT_ERR_VERSION_MISMATCH;
        }

        RL._installScratchHelpers();
        RL._patchColorConstants();
        moduleInstance.initScratchArea();

        return RL.BOOT_OK;
    },
    _ensureModuleInstance: async (opts) => {
        const rc = await RL._tryLoadModuleInstance(opts);
        if (rc !== RL.BOOT_OK) {
            throw new Error(`RL boot failed with code ${rc}`);
        }
        return moduleInstance;
    },
    boot: async (opts = {}) => {
        if (!RL._hasJspiSupport()) {
            return RL.BOOT_ERR_LOADER;
        }

        try {
            return await RL._tryLoadModuleInstance(opts);
        } catch (err) {
            console.error("RL.boot failed", err);
            moduleInstance = null;
            return RL.BOOT_ERR_UNKNOWN;
        }
    },
    _initValuesCcallArgs: (initOptions) => [
        (initOptions.windowWidth || 0) | 0,
        (initOptions.windowHeight || 0) | 0,
        initOptions.windowTitle ?? "",
        (initOptions.windowFlags || 0) >>> 0,
        initOptions.assetHost ?? "",
        initOptions.fsRootDir ?? "",
    ],
    _callInitWithOptionsAsync: async (opts, symbolName, asyncOptions) => {
        await RL._ensureModuleInstance();
        const initOptions = RL._prepareInitOptions(opts);

        const initRc = (await moduleInstance.ccall(
            symbolName,
            "number",
            ["number", "number", "string", "number", "string", "string"],
            RL._initValuesCcallArgs(initOptions),
            asyncOptions
        )) | 0;

        if (initRc !== 0) {
            return initRc;
        }

        return 0;
    },
    _callInitWithOptionsImmediate: (opts, symbolName) => {
        const initOptions = RL._prepareInitOptions(opts);

        if (!moduleInstance) {
            throw new Error("Module must be booted before calling polling-style init APIs");
        }

        const initRc = moduleInstance.ccall(
            symbolName,
            "number",
            ["number", "number", "string", "number", "string", "string"],
            RL._initValuesCcallArgs(initOptions)
        ) | 0;

        if (initRc !== 0) {
            return initRc;
        }

        return 0;
    },
    init: async (opts) => {
        return await RL._callInitWithOptionsAsync(opts, "rl_init_values", { async: true });
    },
    initAsync: (opts) => {
        return RL._callInitWithOptionsImmediate(opts, "rl_init_values_async");
    },
    refreshScratch: () => {
        moduleInstance.ccall('rl_scratch_refresh', null, [], []);
    },
    getTime: () => {
        return moduleInstance.ccall('rl_get_time', 'number', [], []);
    },
    deinit: async () => {
        RL._eventListenersById.clear();
        RL._eventListenerIdsByCallback = new WeakMap();
        RL._clearRunCallbacks();
        if (moduleInstance && RL._eventDispatchPtr !== 0) {
            moduleInstance.removeFunction(RL._eventDispatchPtr);
            RL._eventDispatchPtr = 0;
        }
        moduleInstance.ccall('rl_deinit', null, [], [], { async: true });
    },
    isInitialized: () => {
        return moduleInstance.ccall('rl_is_initialized', 'number', [], []) !== 0;
    },
    getPlatform: () => {
        return moduleInstance.ccall('rl_get_platform', 'string', [], []);
    },
    _compareVersion: () => {
        console.info(
            `[librl] bindings version: ${RL_BINDING_BUILT_MAJOR}, ${RL_BINDING_BUILT_MINOR}, ${RL_BINDING_BUILT_PATCH}`,
        );
        if (!moduleInstance) {
            console.info('[librl] librl version: (not loaded)');
            return -3;
        }
        const runtimeMajor = RL.getVersionMajor();
        const runtimeMinor = RL.getVersionMinor();
        const runtimePatch = RL.getVersionPatch();
        console.info(`[librl] librl version: ${runtimeMajor}, ${runtimeMinor}, ${runtimePatch}`);
        if (runtimeMajor !== (RL_BINDING_BUILT_MAJOR | 0)) {
            return -1;
        }
        if (runtimeMinor !== (RL_BINDING_BUILT_MINOR | 0)) {
            return -2;
        }
        if (runtimePatch !== (RL_BINDING_BUILT_PATCH | 0)) {
            return 1;
        }
        return 0;
    },
    getVersionMajor: () => {
        if (!moduleInstance) {
            return 0;
        }
        return moduleInstance.ccall('rl_version_major', 'number', [], []);
    },
    getVersionMinor: () => {
        if (!moduleInstance) {
            return 0;
        }
        return moduleInstance.ccall('rl_version_minor', 'number', [], []);
    },
    getVersionPatch: () => {
        if (!moduleInstance) {
            return 1;
        }
        return moduleInstance.ccall('rl_version_patch', 'number', [], []);
    },
    versionLabel: () => {
        if (!moduleInstance) {
            return 'dev';
        }
        return moduleInstance.ccall('rl_version_label', 'string', [], []);
    },
    getVersionNumber: () => {
        if (!moduleInstance) {
            return 1;
        }
        return moduleInstance.ccall('rl_version_number', 'number', [], []) >>> 0;
    },
    getVersionString: () => {
        if (!moduleInstance) {
            return '0.0.1-dev';
        }
        return moduleInstance.ccall('rl_version_string', 'string', [], []);
    },
    tick: () => {
        moduleInstance.ccall('rl_scratch_refresh', null, [], []);
        return moduleInstance.ccall('rl_tick', 'number', [], []);
    },
    getDeltaTime: () => {
        return moduleInstance.ccall('rl_get_delta_time', 'number', [], []);
    },
    setTargetFPS: (fps) => moduleInstance.ccall(
        "rl_set_target_fps", null, ["number"], [fps]
    ),

    _colorHandle: (index, generation) => ((generation << 16) | index) >>> 0,
    _RL_COLOR_NAMES: [
        "DEFAULT", "LIGHTGRAY", "GRAY", "DARKGRAY",
        "YELLOW", "GOLD", "ORANGE", "PINK",
        "RED", "MAROON", "GREEN", "LIME",
        "DARKGREEN", "SKYBLUE", "BLUE", "DARKBLUE",
        "PURPLE", "VIOLET", "DARKPURPLE",
        "BEIGE", "BROWN", "DARKBROWN",
        "WHITE", "BLACK", "BLANK", "MAGENTA", "RAYWHITE"
    ],
    _patchColorConstants: () => {
        if (!moduleInstance || !(moduleInstance.HEAPU32 || moduleInstance.HEAP32)) {
            return;
        }
        const heap = moduleInstance.HEAPU32 || moduleInstance.HEAP32;
        for (const name of RL._RL_COLOR_NAMES) {
            const ptr = moduleInstance["_RL_COLOR_" + name];
            if (ptr == null) continue;
            const value = heap[ptr >>> 2] >>> 0;
            RL["COLOR_" + name] = value;
        }
    },
    INIT_OK: 0,
    INIT_ERR_UNKNOWN: -1,
    INIT_ERR_ALREADY_INITIALIZED: -2,
    INIT_ERR_LOADER: -3,
    INIT_ERR_ASSET_HOST: -4,
    INIT_ERR_WINDOW: -5,
    BOOT_OK: 0,
    BOOT_ERR_UNKNOWN: -10,
    BOOT_ERR_LOADER: -11,
    BOOT_ERR_VERSION_MISMATCH: -12,
    CAMERA_PERSPECTIVE: 0,
    CAMERA_ORTHOGRAPHIC: 1,
    FLAG_FULLSCREEN_MODE: 0x00000002,
    FLAG_WINDOW_RESIZABLE: 4,
    FLAG_WINDOW_UNDECORATED: 0x00000008,
    FLAG_WINDOW_TRANSPARENT: 0x00000010,
    FLAG_MSAA_4X_HINT: 32,
    FLAG_VSYNC_HINT: 0x00000040,
    FLAG_WINDOW_HIDDEN: 0x00000080,
    FLAG_WINDOW_ALWAYS_RUN: 0x00000100,
    FLAG_WINDOW_MINIMIZED: 0x00000200,
    FLAG_WINDOW_MAXIMIZED: 0x00000400,
    FLAG_WINDOW_UNFOCUSED: 0x00000800,
    FLAG_WINDOW_TOPMOST: 0x00001000,
    FLAG_WINDOW_HIGHDPI: 0x00002000,
    FLAG_INTERLACED_HINT: 0x00010000,
    LOGGER_LEVEL_TRACE: 0,
    LOGGER_LEVEL_DEBUG: 1,
    LOGGER_LEVEL_INFO: 2,
    LOGGER_LEVEL_WARN: 3,
    LOGGER_LEVEL_ERROR: 4,
    LOGGER_LEVEL_FATAL: 5,
    BUTTON_UP: 0,
    BUTTON_PRESSED: 1,
    BUTTON_DOWN: 2,
    BUTTON_RELEASED: 3,

};

RL.fs = {
    remove: (filename) => {
        return moduleInstance.ccall('rl_fs_remove', 'number', ['string'], [filename]);
    },
    clear: () => {
        return moduleInstance.ccall('rl_fs_clear', 'number', [], []);
    },
    init: async (rootDir = "") => {
        return await moduleInstance.ccall('rl_fs_init', 'number', ['string'], [rootDir || ""], { async: true });
    },
    initAsync: (rootDir = "") => {
        return moduleInstance.ccall('rl_fs_init_async', 'number', ['string'], [rootDir || ""]);
    },
    deinitAsync: () => {
        return moduleInstance.ccall('rl_fs_deinit_async', 'number', [], []) >>> 0;
    },
    deinit: async () => {
        moduleInstance.ccall('rl_fs_deinit', null, [], [], { async: true });
    },
    isInitialized: () => {
        return moduleInstance.ccall('rl_fs_is_initialized', 'number', [], []) !== 0;
    },
    isReady: () => {
        return moduleInstance.ccall('rl_fs_is_ready', 'number', [], []) !== 0;
    },
    flush: () => {
        return moduleInstance.ccall('rl_fs_flush', 'number', [], []) | 0;
    },
    getRootDir: () => {
        return moduleInstance.ccall('rl_fs_get_root_dir', 'string', [], []);
    },
    normalizePath: (path) => {
        if (path == null) {
            return "";
        }
        const bufferSize = 4096;
        const bufferPtr = RL._mallocOrThrow(bufferSize);
        try {
            moduleInstance.ccall(
                'rl_fs_normalize_path',
                null,
                ['string', 'number', 'number'],
                [String(path), bufferPtr, bufferSize]
            );
            if (typeof moduleInstance.UTF8ToString === "function") {
                return moduleInstance.UTF8ToString(bufferPtr);
            }
            return "";
        } finally {
            RL._freeIfPossible(bufferPtr);
        }
    },
    restoreAsync: () => {
        return moduleInstance.ccall('rl_fs_restore_async', 'number', [], []);
    },
    read: (filename) => {
        if (!moduleInstance) {
            return null;
        }
        const stackSave = moduleInstance.stackSave;
        const stackRestore = moduleInstance.stackRestore;
        const stackAlloc = moduleInstance.stackAlloc;
        const heapU32 = moduleInstance.HEAPU32;
        const heapU8 = moduleInstance.HEAPU8;
        if (
            typeof stackSave !== "function" ||
            typeof stackRestore !== "function" ||
            typeof stackAlloc !== "function" ||
            !heapU32 ||
            !heapU8
        ) {
            return null;
        }
        const name = filename == null ? "" : String(filename);
        const prevSp = stackSave();
        try {
            // Allocate out-param slots: *out_data (pointer) and *out_size (size_t)
            const outDataSlot = stackAlloc(4) >>> 0;
            const outSizeSlot = stackAlloc(4) >>> 0;
            heapU32[outDataSlot >>> 2] = 0;
            heapU32[outSizeSlot >>> 2] = 0;
            const rc = moduleInstance.ccall(
                'rl_fs_read',
                'number',
                ['string', 'number', 'number'],
                [name, outDataSlot, outSizeSlot]
            ) | 0;
            const dataPtr = heapU32[outDataSlot >>> 2] >>> 0;
            const size = heapU32[outSizeSlot >>> 2] >>> 0;
            if (rc !== 0 || !dataPtr) {
                if (dataPtr) {
                    moduleInstance.ccall('rl_fs_read_free', null, ['number'], [dataPtr]);
                }
                return null;
            }
            const out = new Uint8Array(size);
            if (size > 0) {
                out.set(heapU8.subarray(dataPtr, dataPtr + size));
            }
            moduleInstance.ccall('rl_fs_read_free', null, ['number'], [dataPtr]);
            return out;
        } finally {
            stackRestore(prevSp);
        }
    },
    write: (path, data) => {
        if (typeof data === "string") {
            data = new TextEncoder().encode(data);
        }
        const ptr = RL._mallocOrThrow(data.byteLength);
        try {
            moduleInstance.HEAPU8.set(data, ptr);
            return moduleInstance.ccall('rl_fs_write', 'number', ['string', 'number', 'number'], [path, ptr, data.byteLength]) | 0;
        } finally {
            RL._freeIfPossible(ptr);
        }
    },
    mkdir: (path) => {
        return moduleInstance.ccall('rl_fs_mkdir', 'number', ['string'], [path]) | 0;
    },
    rmdir: (path) => {
        return moduleInstance.ccall('rl_fs_rmdir', 'number', ['string'], [path]) | 0;
    },
    exists: (filename) => {
        return moduleInstance.ccall('rl_fs_exists', 'number', ['string'], [filename]) !== 0;
    }
};

RL.asset = {
    ADD_TASK_OK: 0,
    ADD_TASK_ERR_INVALID: -1,
    ADD_TASK_ERR_QUEUE_FULL: -2,
    pingHost: (assetHost = "") => {
        return moduleInstance.ccall(
            'rl_asset_ping_host',
            'number',
            ['string'],
            [assetHost || ""]
        );
    },
    setHost: (assetHost) => {
        if (typeof assetHost !== "string") {
            return -1;
        }
        return moduleInstance.ccall('rl_asset_set_host', 'number', ['string'], [assetHost]) | 0;
    },
    getHost: () => {
        return moduleInstance.ccall('rl_asset_get_host', 'string', [], []);
    },
    ensure: async (localPath, src = null) => {
        if (typeof localPath === "string" && /\.gltf(?:[?#].*)?$/i.test(localPath)) {
            console.warn(
                `[librl] asset.ensure("${localPath}") does not currently follow .gltf dependencies. ` +
                `Use asset.ensureAsync(), rl.helpers.waitForAssetEnsureAsync(), or rl.helpers.createTaskGroup() instead.`
            );
        }
        return await moduleInstance.ccall(
            'rl_asset_ensure',
            'number',
            ['string', 'string'],
            [localPath, src ?? null],
            { async: true }
        );
    },
    ensureAsync: (localPath, src = null) => {
        return moduleInstance.ccall('rl_asset_ensure_async', 'number', ['string', 'string'], [localPath, src ?? null]);
    },
    ensureGroupAsync: (filenames) => {
        const count = moduleInstance.writeScratchStringTable(filenames);
        return moduleInstance.ccall('rl_asset_ensure_many_from_scratch_async', 'number', ['number'], [count]);
    },
    pollTask: (task) => {
        return moduleInstance.ccall('rl_asset_poll_task', 'number', ['number'], [task]) !== 0;
    },
    finishTask: (task) => {
        return moduleInstance.ccall('rl_asset_finish_task', 'number', ['number'], [task]);
    },
    getTaskPath: (task) => {
        return moduleInstance.ccall('rl_asset_get_task_path', 'string', ['number'], [task]);
    },
    freeTask: (task) => {
        return moduleInstance.ccall('rl_asset_free_task', null, ['number'], [task]);
    },
    addTask: (task, onSuccess = null, onFailure = null, ctx = null) => {
        let successPtr = 0;
        let failurePtr = 0;
        let cleanedUp = false;
        const cleanup = () => {
            if (cleanedUp || !moduleInstance) {
                return;
            }
            cleanedUp = true;
            if (successPtr) {
                moduleInstance.removeFunction(successPtr);
                successPtr = 0;
            }
            if (failurePtr) {
                moduleInstance.removeFunction(failurePtr);
                failurePtr = 0;
            }
        };
        const decodePath = (pathPtr) => {
            if (!pathPtr) {
                return "";
            }
            if (typeof moduleInstance.UTF8ToString === "function") {
                return moduleInstance.UTF8ToString(pathPtr >>> 0);
            }
            console.error("UTF8ToString runtime method is unavailable; cannot decode loader callback path");
            return "";
        };

        // Mirror the cpp binding's rl_asset_add_task behavior with local JS
        // springboards. The closures capture the provided callbacks/context, so
        // we do not need a separate userdata registry on the JS side.
        successPtr = moduleInstance.addFunction((pathPtr, _userData) => {
            try {
                if (typeof onSuccess === "function") {
                    onSuccess(decodePath(pathPtr), ctx);
                }
            } finally {
                cleanup();
            }
        }, "vii");
        failurePtr = moduleInstance.addFunction((pathPtr, _userData) => {
            try {
                if (typeof onFailure === "function") {
                    onFailure(decodePath(pathPtr), ctx);
                }
            } finally {
                cleanup();
            }
        }, "vii");

        try {
            const rc = moduleInstance.ccall(
                'rl_asset_add_task',
                'number',
                ['number', 'number', 'number', 'number'],
                [task, successPtr, failurePtr, 0]
            );
            if ((rc | 0) !== 0) {
                cleanup();
            }
            return rc;
        } catch (err) {
            cleanup();
            throw err;
        }
    },
    tick: () => {
        moduleInstance.ccall('rl_asset_tick', null, [], []);
    }
};

RL.event = {
    emit: (eventName, payload = 0) => {
        return moduleInstance.ccall('rl_event_emit', 'number', ['string', 'number'], [eventName, payload]);
    },
    on: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        RL._ensureEventDispatchPtr();
        if (RL._eventDispatchPtr === 0) {
            return -1;
        }

        callbackMap = RL._eventListenerIdsByCallback.get(callback);
        if (!callbackMap) {
            callbackMap = new Map();
            RL._eventListenerIdsByCallback.set(callback, callbackMap);
        }

        if (callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = RL._nextEventListenerId++;
        rc = moduleInstance.ccall('rl_event_on', 'number', ['string', 'number', 'number'], [eventName, RL._eventDispatchPtr, listenerId]);
        if (rc !== 0) {
            return rc;
        }

        callbackMap.set(eventName, listenerId);
        RL._eventListenersById.set(listenerId, { eventName, callback });
        return 0;
    },
    once: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        RL._ensureEventDispatchPtr();
        if (RL._eventDispatchPtr === 0) {
            return -1;
        }

        callbackMap = RL._eventListenerIdsByCallback.get(callback);
        if (!callbackMap) {
            callbackMap = new Map();
            RL._eventListenerIdsByCallback.set(callback, callbackMap);
        }

        if (callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = RL._nextEventListenerId++;
        rc = moduleInstance.ccall('rl_event_once', 'number', ['string', 'number', 'number'], [eventName, RL._eventDispatchPtr, listenerId]);
        if (rc !== 0) {
            return rc;
        }

        callbackMap.set(eventName, listenerId);
        RL._eventListenersById.set(listenerId, { eventName, callback });
        return 0;
    },
    off: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        callbackMap = RL._eventListenerIdsByCallback.get(callback);
        if (!callbackMap || !callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = callbackMap.get(eventName);
        rc = moduleInstance.ccall('rl_event_off', 'number', ['string', 'number', 'number'], [eventName, RL._eventDispatchPtr, listenerId]);
        if (rc === 0) {
            RL._forgetListenerById(listenerId);
        }
        return rc;
    },
    clearListeners: (eventName) => {
        const rc = moduleInstance.ccall('rl_event_off_all', 'number', ['string'], [eventName]);
        if (rc === 0) {
            RL._clearListenerCacheForEvent(eventName);
        }
        return rc;
    },
    getListenerCount: (eventName) => {
        return moduleInstance.ccall('rl_event_listener_count', 'number', ['string'], [eventName]);
    }
};

RL.window = {
    setSize: (width, height) => {
        return moduleInstance.ccall('rl_window_set_size', null, ['number', 'number'], [width, height]);
    },
    isCloseRequested: () => {
        return !!moduleInstance.ccall('rl_window_close_requested', 'number', [], []);
    },
    getMonitorCount: () => {
        return moduleInstance.ccall('rl_window_get_monitor_count', 'number', [], []);
    },
    setTitle: (title) => {
        return moduleInstance.ccall('rl_window_set_title', null, ['string'], [title]);
    },
    getCurrentMonitor: () => {
        return moduleInstance.ccall('rl_window_get_current_monitor', 'number', [], []);
    },
    setMonitor: (monitor) => {
        return moduleInstance.ccall('rl_window_set_monitor', null, ['number'], [monitor]);
    },
    getMonitorWidth: (monitor) => {
        return moduleInstance.ccall('rl_window_get_monitor_width', 'number', ['number'], [monitor]);
    },
    getMonitorHeight: (monitor) => {
        return moduleInstance.ccall('rl_window_get_monitor_height', 'number', ['number'], [monitor]);
    },
    setPosition: (x, y) => {
        return moduleInstance.ccall('rl_window_set_position', null, ['number', 'number'], [x, y]);
    },
    getScreenSize: () => {
        moduleInstance.ccall('rl_window_get_screen_size_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    },
    getPosition: () => {
        moduleInstance.ccall('rl_window_get_position_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    },
    getMonitorPosition: (monitor = 0) => {
        moduleInstance.ccall('rl_window_get_monitor_position_to_scratch', null, ['number'], [monitor]);
        return moduleInstance.getVector2();
    }
};

RL.render = {
    begin: () => {
        return moduleInstance.ccall('rl_render_begin', null, [], []);
    },
    end: () => {
        return moduleInstance.ccall('rl_render_end', null, [], []);
    },
    beginMode2D: (camera) => {
        return moduleInstance.ccall('rl_render_begin_mode_2d', null, ['number'], [camera]);
    },
    endMode2D: () => {
        return moduleInstance.ccall('rl_render_end_mode_2d', null, [], []);
    },
    beginMode3D: () => {
        return moduleInstance.ccall('rl_render_begin_mode_3d', null, [], []);
    },
    endMode3D: () => {
        return moduleInstance.ccall('rl_render_end_mode_3d', null, [], []);
    },
    clearBackground: (color) => {
        return moduleInstance.ccall('rl_render_clear_background', null, ['number'], [color]);
    },
    enableLighting: () => {
        return moduleInstance.ccall('rl_enable_lighting', null, [], []);
    },
    disableLighting: () => {
        return moduleInstance.ccall('rl_disable_lighting', null, [], []);
    },
    isLightingEnabled: () => {
        return moduleInstance.ccall('rl_is_lighting_enabled', 'number', [], []) !== 0;
    },
    setLightDirection: (x, y, z) => {
        return moduleInstance.ccall('rl_set_light_direction', null, ['number', 'number', 'number'], [x, y, z]);
    },
    setLightAmbient: (ambient) => {
        return moduleInstance.ccall('rl_set_light_ambient', null, ['number'], [ambient]);
    }
};

RL.camera3d = {
    create: (
        positionX, positionY, positionZ,
        targetX, targetY, targetZ,
        upX, upY, upZ,
        fovy, projection
    ) => {
        return moduleInstance.ccall(
            'rl_camera3d_create',
            'number',
            ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection]
        );
    },
    getDefault: () => {
        return moduleInstance.ccall('rl_camera3d_get_default', 'number', [], []);
    },
    set: (
        camera,
        positionX, positionY, positionZ,
        targetX, targetY, targetZ,
        upX, upY, upZ,
        fovy, projection
    ) => {
        return moduleInstance.ccall(
            'rl_camera3d_set',
            'number',
            ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection]
        ) !== 0;
    },
    setActive: (camera) => {
        return moduleInstance.ccall('rl_camera3d_set_active', 'number', ['number'], [camera]) !== 0;
    },
    getActive: () => {
        return moduleInstance.ccall('rl_camera3d_get_active', 'number', [], []);
    },
    destroy: (camera) => {
        return moduleInstance.ccall('rl_camera3d_destroy', null, ['number'], [camera]);
    }
};

RL.shape = {
    drawCube: (positionX, positionY, positionZ, width, height, length, color) => {
        return moduleInstance.ccall(
            'rl_shape_draw_cube',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [positionX, positionY, positionZ, width, height, length, color]
        );
    },
    drawRectangle: (x, y, width, height, color) => {
        return moduleInstance.ccall(
            'rl_shape_draw_rectangle',
            null,
            ['number', 'number', 'number', 'number', 'number'],
            [x | 0, y | 0, width | 0, height | 0, color >>> 0]
        );
    }
};

RL.debug = {
    enableFps: (x, y, fontSize, font = 0) => {
        return moduleInstance.ccall(
            'rl_debug_enable_fps',
            null,
            ['number', 'number', 'number', 'number'],
            [x | 0, y | 0, fontSize | 0, font >>> 0]
        );
    },
    disable: () => {
        return moduleInstance.ccall('rl_debug_disable', null, [], []);
    }
};

RL.text = {
    drawFps: (x, y) => {
        return moduleInstance.ccall('rl_text_draw_fps', null, ['number', 'number'], [x, y]);
    },
    drawFpsEx: (font, x, y, fontSize, color) => {
        moduleInstance.ccall('rl_text_draw_fps_ex', null, ['number', 'number', 'number', 'number', 'number'], [font, x, y, fontSize, color]);
    },
    draw: (text, x, y, fontSize, color) => {
        return moduleInstance.ccall('rl_text_draw', null, ['string', 'number', 'number', 'number', 'number'], [text, x, y, fontSize, color]);
    },
    drawEx: (font, text, x, y, fontSize, spacing, tint) => {
        return moduleInstance.ccall('rl_text_draw_ex', null, ['number', 'string', 'number', 'number', 'number', 'number', 'number'], [font, text, x, y, fontSize, spacing, tint]);
    },
    measure: (text, fontSize) => {
        return moduleInstance.ccall('rl_text_measure', 'number', ['string', 'number'], [text, fontSize]);
    },
    measureEx: (font, text, fontSize, spacing = 1) => {
        moduleInstance.ccall('rl_text_measure_ex_to_scratch', 'number', ['number', 'string', 'number', 'number'], [font, text, fontSize, spacing]);
        return moduleInstance.getVector2();
    },
    // End Scratch-backed wrappers
};

RL.texture = {
    getDefault: () => moduleInstance.ccall(
        "rl_texture_get_default", "number", [], []
    ),
    create: (path) => moduleInstance.ccall(
        "rl_texture_create", "number", ["string"], [path]
    ),
    destroy: (texture) => moduleInstance.ccall(
        "rl_texture_destroy", null, ["number"], [texture]
    ),
    drawEx: (texture, x, y, scale, rotation, tint) => {
        return moduleInstance.ccall('rl_texture_draw_ex', null, ['number', 'number', 'number', 'number', 'number', 'number'], [texture, x, y, scale, rotation, tint]);
    },
    drawGround: (texture, positionX, positionY, positionZ, width, length, tint) => {
        return moduleInstance.ccall('rl_texture_draw_ground', null, ['number', 'number', 'number', 'number', 'number', 'number', 'number'], [texture, positionX, positionY, positionZ, width, length, tint]);
    }
};

RL.input = {
    pollEvents: () => {
        return moduleInstance.ccall('rl_input_poll_events', null, [], []);
    },
    getMouseWheel: () => {
        return moduleInstance.ccall('rl_input_get_mouse_wheel', 'number', [], []);
    },
    getMouseButton: (button) => {
        return moduleInstance.ccall('rl_input_get_mouse_button', 'number', ['number'], [button]);
    },

    // Begin Scratch-backed wrappers
    // The following are wrappers that use the global scratch area to reduce js->wasm/wasm->js boundry calls
    // They either read scratch directly or via a *_to_scratch bridge.
    // We provide a uniform calling so js isn't aware of the intermediate scratch area use, 
    // while desktop gets the return structure directly,
    getMouseState: () => {
        const mouse = moduleInstance.getMouseState();
        return {
            x: mouse.x,
            y: mouse.y,
            wheel: mouse.wheel,
            left: mouse.buttons[0],
            right: mouse.buttons[1],
            middle: mouse.buttons[2],
            buttons: mouse.buttons
        };
    },
    getKeyboardState: () => {
        return moduleInstance.getKeyboard();
    },
    getGamepads: () => {
        if (!moduleInstance || typeof moduleInstance.getGamepads !== "function") {
            return [];
        }
        return moduleInstance.getGamepads();
    },
    getGamepad: (id) => {
        if (!moduleInstance || typeof moduleInstance.getGamepad !== "function") {
            return null;
        }
        return moduleInstance.getGamepad(id | 0);
    },
    getTouchpoints: () => {
        if (!moduleInstance || typeof moduleInstance.getTouchpoints !== "function") {
            return [];
        }
        return moduleInstance.getTouchpoints();
    },
    getTouchpoint: (id) => {
        if (!moduleInstance || typeof moduleInstance.getTouchpoint !== "function") {
            return null;
        }
        return moduleInstance.getTouchpoint(id | 0);
    },
    getMousePosition: () => {
        moduleInstance.ccall('rl_input_get_mouse_position_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    }
};

RL.color = {
    create: (r, g, b, a) => moduleInstance.ccall(
        "rl_color_create", "number", ["number", "number", "number", "number"], [r, g, b, a]
    ),
    destroy: (color) => moduleInstance.ccall(
        "rl_color_destroy", null, ["number"], [color]
    )
};

RL.font = {
    create: (path, fontSize) => moduleInstance.ccall(
        "rl_font_create", "number", ["string", "number"], [path, fontSize]
    ),
    destroy: (font) => moduleInstance.ccall(
        "rl_font_destroy", null, ["number"], [font]
    ),
    getDefault: () => moduleInstance.ccall(
        "rl_font_get_default", "number", [], []
    )
};

RL.model = {
    getDefaultAsset: () => moduleInstance.ccall(
        "rl_model_get_default_asset", "number", [], []
    ),
    loadAsset: (path) => moduleInstance.ccall(
        "rl_model_load_asset", "number", ["string"], [path]
    ),
    destroyAsset: (asset) => moduleInstance.ccall(
        "rl_model_destroy_asset", null, ["number"], [asset]
    ),
    create: (asset) => moduleInstance.ccall(
        "rl_model_create", "number", ["number"], [asset]
    ),
    createFromFile: (path) => moduleInstance.ccall(
        "rl_model_create_from_file", "number", ["string"], [path]
    ),
    setAsset: (model, asset) => moduleInstance.ccall(
        "rl_model_set_asset", "number", ["number", "number"], [model, asset]
    ) !== 0,
    setTransform: (
        model,
        positionX, positionY, positionZ,
        rotationX, rotationY, rotationZ,
        scaleX, scaleY, scaleZ
    ) => moduleInstance.ccall(
        "rl_model_set_transform",
        "number",
        ["number", "number", "number", "number", "number", "number", "number", "number", "number", "number"],
        [model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ]
    ) !== 0,
    draw: (model, tint) => moduleInstance.ccall(
        "rl_model_draw", null, ["number", "number"], [model, tint]
    ),
    isValid: (model) => moduleInstance.ccall(
        "rl_model_is_valid", "number", ["number"], [model]
    ) !== 0,
    isValidStrict: (model) => moduleInstance.ccall(
        "rl_model_is_valid_strict", "number", ["number"], [model]
    ) !== 0,
    getAnimationCount: (model) => moduleInstance.ccall(
        "rl_model_get_animation_count", "number", ["number"], [model]
    ),
    getAnimationFrameCount: (model, animationIndex) => moduleInstance.ccall(
        "rl_model_get_animation_frame_count", "number", ["number", "number"], [model, animationIndex]
    ),
    updateAnimation: (model, animationIndex, frame) => moduleInstance.ccall(
        "rl_model_update_animation", null, ["number", "number", "number"], [model, animationIndex, frame]
    ),
    setAnimation: (model, animationIndex) => moduleInstance.ccall(
        "rl_model_set_animation", "number", ["number", "number"], [model, animationIndex]
    ) !== 0,
    setAnimationSpeed: (model, speed) => moduleInstance.ccall(
        "rl_model_set_animation_speed", "number", ["number", "number"], [model, speed]
    ) !== 0,
    setAnimationLoop: (model, shouldLoop) => moduleInstance.ccall(
        "rl_model_set_animation_loop", "number", ["number", "number"], [model, shouldLoop ? 1 : 0]
    ) !== 0,
    setTint: (model, color = 0) => moduleInstance.ccall(
        "rl_model_set_tint", "number", ["number", "number"], [model, color]
    ) !== 0,
    animate: (model, deltaSeconds) => moduleInstance.ccall(
        "rl_model_animate", "number", ["number", "number"], [model, deltaSeconds]
    ) !== 0,
    destroy: (model) => moduleInstance.ccall(
        "rl_model_destroy", null, ["number"], [model]
    )
};

RL.pick = {
    model: (camera, model, mouseX, mouseY) => {
        const hit = moduleInstance.ccall(
            "rl_pick_model_to_scratch",
            "number",
            ["number", "number", "number", "number"],
            [camera, model, mouseX, mouseY]
        ) !== 0;
        const point = moduleInstance.getVector3();
        const normalDistance = moduleInstance.getVector4();
        return {
            hit,
            distance: normalDistance.w,
            point,
            normal: {
                x: normalDistance.x,
                y: normalDistance.y,
                z: normalDistance.z
            }
        };
    },
    sprite3d: (camera, sprite3d, mouseX, mouseY) => {
        const hit = moduleInstance.ccall(
            "rl_pick_sprite3d_to_scratch",
            "number",
            ["number", "number", "number", "number"],
            [camera, sprite3d, mouseX, mouseY]
        ) !== 0;
        const point = moduleInstance.getVector3();
        const normalDistance = moduleInstance.getVector4();
        return {
            hit,
            distance: normalDistance.w,
            point,
            normal: {
                x: normalDistance.x,
                y: normalDistance.y,
                z: normalDistance.z
            }
        };
    },
    resetStats: () => {
        moduleInstance.ccall("rl_pick_reset_stats", null, [], []);
    }
};

RL.music = {
    create: (path) => moduleInstance.ccall(
        "rl_music_create", "number", ["string"], [path]
    ),
    destroy: (music) => moduleInstance.ccall(
        "rl_music_destroy", null, ["number"], [music]
    ),
    play: (music) => moduleInstance.ccall(
        "rl_music_play", "number", ["number"], [music]
    ) !== 0,
    pause: (music) => moduleInstance.ccall(
        "rl_music_pause", "number", ["number"], [music]
    ) !== 0,
    stop: (music) => moduleInstance.ccall(
        "rl_music_stop", "number", ["number"], [music]
    ) !== 0,
    setLoop: (music, shouldLoop) => moduleInstance.ccall(
        "rl_music_set_loop", "number", ["number", "number"], [music, shouldLoop ? 1 : 0]
    ) !== 0,
    setVolume: (music, volume) => moduleInstance.ccall(
        "rl_music_set_volume", "number", ["number", "number"], [music, volume]
    ) !== 0,
    isPlaying: (music) => moduleInstance.ccall(
        "rl_music_is_playing", "number", ["number"], [music]
    ) !== 0,
    update: (music) => moduleInstance.ccall(
        "rl_music_update", "number", ["number"], [music]
    ) !== 0,
    updateAll: () => moduleInstance.ccall(
        "rl_music_update_all", null, [], []
    )
};

RL.sound = {
    create: (path) => moduleInstance.ccall(
        "rl_sound_create", "number", ["string"], [path]
    ),
    destroy: (sound) => moduleInstance.ccall(
        "rl_sound_destroy", null, ["number"], [sound]
    ),
    play: (sound) => moduleInstance.ccall(
        "rl_sound_play", "number", ["number"], [sound]
    ) !== 0,
    pause: (sound) => moduleInstance.ccall(
        "rl_sound_pause", "number", ["number"], [sound]
    ) !== 0,
    resume: (sound) => moduleInstance.ccall(
        "rl_sound_resume", "number", ["number"], [sound]
    ) !== 0,
    stop: (sound) => moduleInstance.ccall(
        "rl_sound_stop", "number", ["number"], [sound]
    ) !== 0,
    setVolume: (sound, volume) => moduleInstance.ccall(
        "rl_sound_set_volume", "number", ["number", "number"], [sound, volume]
    ) !== 0,
    setPitch: (sound, pitch) => moduleInstance.ccall(
        "rl_sound_set_pitch", "number", ["number", "number"], [sound, pitch]
    ) !== 0,
    setPan: (sound, pan) => moduleInstance.ccall(
        "rl_sound_set_pan", "number", ["number", "number"], [sound, pan]
    ) !== 0,
    isPlaying: (sound) => moduleInstance.ccall(
        "rl_sound_is_playing", "number", ["number"], [sound]
    ) !== 0
};

RL.sprite3d = {
    create: (texture) => moduleInstance.ccall(
        "rl_sprite3d_create", "number", ["number"], [texture]
    ),
    createFromFile: (path) => moduleInstance.ccall(
        "rl_sprite3d_create_from_file", "number", ["string"], [path]
    ),
    setTexture: (sprite, texture) => moduleInstance.ccall(
        "rl_sprite3d_set_texture", "number", ["number", "number"], [sprite, texture]
    ) !== 0,
    setTransform: (sprite, positionX, positionY, positionZ, size) => moduleInstance.ccall(
        "rl_sprite3d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, positionX, positionY, positionZ, size]
    ) !== 0,
    getDefaultTexture: () => moduleInstance.ccall(
        "rl_sprite3d_get_default_texture", "number", [], []
    ),
    getTransform: (sprite) => {
        const stackSave = moduleInstance.stackSave;
        const stackRestore = moduleInstance.stackRestore;
        const stackAlloc = moduleInstance.stackAlloc;
        const heapF32 = moduleInstance.HEAPF32;
        if (
            typeof stackSave !== "function" ||
            typeof stackRestore !== "function" ||
            typeof stackAlloc !== "function" ||
            !heapF32
        ) {
            return null;
        }
        const prevSp = stackSave();
        try {
            const positionXPtr = stackAlloc(4) >>> 0;
            const positionYPtr = stackAlloc(4) >>> 0;
            const positionZPtr = stackAlloc(4) >>> 0;
            const sizePtr = stackAlloc(4) >>> 0;
            const ok = moduleInstance.ccall(
                "rl_sprite3d_get_transform",
                "number",
                ["number", "number", "number", "number", "number"],
                [sprite >>> 0, positionXPtr, positionYPtr, positionZPtr, sizePtr]
            ) !== 0;
            if (!ok) {
                return null;
            }
            return {
                positionX: heapF32[positionXPtr >> 2],
                positionY: heapF32[positionYPtr >> 2],
                positionZ: heapF32[positionZPtr >> 2],
                size: heapF32[sizePtr >> 2],
            };
        } finally {
            stackRestore(prevSp);
        }
    },
    setTint: (sprite, color = 0) => moduleInstance.ccall(
        "rl_sprite3d_set_tint", "number", ["number", "number"], [sprite, color]
    ) !== 0,
    draw: (sprite, tint = 0) => moduleInstance.ccall(
        "rl_sprite3d_draw", null, ["number", "number"], [sprite, tint]
    ),
    destroy: (sprite) => moduleInstance.ccall(
        "rl_sprite3d_destroy", null, ["number"], [sprite]
    )
};

RL.sprite2d = {
    create: (texture) => moduleInstance.ccall(
        "rl_sprite2d_create", "number", ["number"], [texture]
    ),
    createFromFile: (path) => moduleInstance.ccall(
        "rl_sprite2d_create_from_file", "number", ["string"], [path]
    ),
    getDefaultTexture: () => moduleInstance.ccall(
        "rl_sprite2d_get_default_texture", "number", [], []
    ),
    setTexture: (sprite, texture) => moduleInstance.ccall(
        "rl_sprite2d_set_texture", "number", ["number", "number"], [sprite, texture]
    ) !== 0,
    setTransform: (sprite, x, y, scale, rotation) => moduleInstance.ccall(
        "rl_sprite2d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, x, y, scale, rotation]
    ) !== 0,
    setTint: (sprite, color = 0) => moduleInstance.ccall(
        "rl_sprite2d_set_tint", "number", ["number", "number"], [sprite, color]
    ) !== 0,
    draw: (sprite, tint = 0) => moduleInstance.ccall(
        "rl_sprite2d_draw", null, ["number", "number"], [sprite, tint]
    ),
    destroy: (sprite) => moduleInstance.ccall(
        "rl_sprite2d_destroy", null, ["number"], [sprite]
    )
};

RL.text2d = {
    create: (font, size) => moduleInstance.ccall(
        "rl_text2d_create", "number", ["number", "number"], [font, size]
    ),
    setFont: (handle, font) => moduleInstance.ccall(
        "rl_text2d_set_font", null, ["number", "number"], [handle, font]
    ),
    setSize: (handle, size) => moduleInstance.ccall(
        "rl_text2d_set_size", null, ["number", "number"], [handle, size]
    ),
    setContent: (handle, content) => moduleInstance.ccall(
        "rl_text2d_set_content", null, ["number", "string"], [handle, content]
    ),
    setPosition: (handle, x, y) => moduleInstance.ccall(
        "rl_text2d_set_position", null, ["number", "number", "number"], [handle, x, y]
    ),
    setColor: (handle, color) => moduleInstance.ccall(
        "rl_text2d_set_color", null, ["number", "number"], [handle, color]
    ),
    draw: (handle) => moduleInstance.ccall(
        "rl_text2d_draw", null, ["number"], [handle]
    ),
    destroy: (handle) => moduleInstance.ccall(
        "rl_text2d_destroy", null, ["number"], [handle]
    )
};

RL.logger = {
    message: (level, message) => moduleInstance.ccall(
        "rl_logger_message", null, ["number", "string"], [level, String(message ?? "").replaceAll("%", "%%")]
    ),
    messageSource: (level, sourceFile, sourceLine, message) => moduleInstance.ccall(
        "rl_logger_message_source",
        null,
        ["number", "string", "number", "string"],
        [
            level | 0,
            String(sourceFile ?? ""),
            sourceLine | 0,
            String(message ?? "").replaceAll("%", "%%"),
        ]
    ),
    setLevel: (level) => moduleInstance.ccall(
        "rl_logger_set_level", null, ["number"], [level]
    )
};

RL.helpers = {
    waitForFsReady: async (timeoutMs = 2000) => {
        const start = performance.now();
        while (performance.now() - start < timeoutMs) {
            if (RL.fs.isReady()) {
                return true;
            }
            await new Promise((resolve) => setTimeout(resolve, 16));
        }
        return RL.fs.isReady();
    },
    taskIsValid: (task) => {
        return task !== 0;
    },
    waitForTask: async (task, pollMs = 16) => {
        let rc = 0;

        if (!task) {
            return -1;
        }

        while (!RL.asset.pollTask(task)) {
            await new Promise((resolve) => setTimeout(resolve, pollMs));
        }

        rc = RL.asset.finishTask(task);
        RL.asset.freeTask(task);
        return rc;
    },
    waitForFsRestoreAsync: async () => {
        return RL.helpers.waitForTask(RL.fs.restoreAsync());
    },
    waitForAssetEnsureAsync: async (filename, src = null) => {
        return RL.helpers.waitForTask(RL.asset.ensureAsync(filename, src));
    },
    waitForAssetEnsureGroupAsync: async (filenames) => {
        return RL.helpers.waitForTask(RL.asset.ensureGroupAsync(filenames));
    },
    createTaskGroup: (onComplete = null, onError = null, ctx = null) => {
        const group = {
            entries: [],
            callbackContext: ctx,
            onCompleteCallback: typeof onComplete === "function" ? onComplete : null,
            onErrorCallback: typeof onError === "function" ? onError : null,
            terminalCallbackInvoked: false,
            failedCount: 0,
            completedCount: 0,
            addTask(task, onSuccess = null, onTaskError = null) {
                if (!task) {
                    return;
                }
                this.entries.push({
                    task,
                    path: RL.asset.getTaskPath(task),
                    done: false,
                    rc: 1,
                    onSuccess: typeof onSuccess === "function" ? onSuccess : null,
                    onError: typeof onTaskError === "function" ? onTaskError : null,
                });
            },
            addImportTask(path, onSuccess = null, onTaskError = null) {
                this.addTask(RL.asset.ensureAsync(path), onSuccess, onTaskError);
            },
            addImportTasks(paths, onSuccess = null, onTaskError = null) {
                if (!Array.isArray(paths)) {
                    return;
                }
                for (const path of paths) {
                    this.addImportTask(path, onSuccess, onTaskError);
                }
            },
            remainingTasks() {
                return this.entries.length - this.completedCount;
            },
            isDone() {
                return this.remainingTasks() === 0;
            },
            hasFailures() {
                return this.failedCount > 0;
            },
            tick() {
                RL.asset.tick();
                for (const entry of this.entries) {
                    if (entry.done) {
                        continue;
                    }
                    if (!RL.asset.pollTask(entry.task)) {
                        continue;
                    }
                    entry.rc = RL.asset.finishTask(entry.task);
                    RL.asset.freeTask(entry.task);
                    entry.done = true;
                    this.completedCount += 1;
                    if (entry.rc !== 0) {
                        this.failedCount += 1;
                        if (entry.onError) {
                            entry.onError(entry.path, this.callbackContext);
                        }
                    } else if (entry.onSuccess) {
                        entry.onSuccess(entry.path, this.callbackContext);
                    }
                }
                return this.remainingTasks() > 0;
            },
            process() {
                this.tick();
                if (!this.terminalCallbackInvoked && this.remainingTasks() === 0) {
                    this.terminalCallbackInvoked = true;
                    if (this.hasFailures()) {
                        if (this.onErrorCallback) {
                            this.onErrorCallback(this, this.callbackContext);
                        }
                    } else if (this.onCompleteCallback) {
                        this.onCompleteCallback(this, this.callbackContext);
                    }
                }
                return this.remainingTasks();
            },
            failedPaths() {
                const out = [];
                for (const entry of this.entries) {
                    if (entry.done && entry.rc !== 0) {
                        out.push(entry.path);
                    }
                }
                return out;
            },
        };
        return group;
    },
    getScreenWidth: () => {
        return RL.window.getScreenSize().x;
    },
    getScreenHeight: () => {
        return RL.window.getScreenSize().y;
    },
    getPickStats: () => {
        return {
            broadphaseTests: moduleInstance.ccall("rl_pick_get_broadphase_tests", "number", [], []),
            broadphaseRejects: moduleInstance.ccall("rl_pick_get_broadphase_rejects", "number", [], []),
            narrowphaseTests: moduleInstance.ccall("rl_pick_get_narrowphase_tests", "number", [], []),
            narrowphaseHits: moduleInstance.ccall("rl_pick_get_narrowphase_hits", "number", [], [])
        };
    },
};

export const rl = RL;
export default RL;
