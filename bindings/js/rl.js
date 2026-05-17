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
    _waitForIdbfsReady: async (timeoutMs = 2000) => {
        const start = performance.now();
        while (performance.now() - start < timeoutMs) {
            if (RL.isIdbfsReady()) {
                return true;
            }
            await new Promise((resolve) => setTimeout(resolve, 16));
        }
        return RL.isIdbfsReady();
    },
    isIdbfsReady: () => {
        return !!(moduleInstance && moduleInstance.fileio_idbfs_ready);
    },
    waitForIdbfsReady: async (timeoutMs = 2000) => {
        return RL._waitForIdbfsReady(timeoutMs);
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

    /* unused for now
    _installWebResizeHandler: (opts) => {
        if (typeof window === "undefined" || !window.addEventListener) {
            return;
        }

        const idealWidth = opts.idealWidth || opts.windowWidth || 1024;
        const idealHeight = opts.idealHeight || opts.windowHeight || 1280;
        const aspectRatio = idealWidth / idealHeight;

        window.addEventListener("resize", (_event) => {
            const windowWidth = window.innerWidth;
            const windowHeight = window.innerHeight;

            let newWidth;
            let newHeight;
            if (windowWidth / windowHeight > aspectRatio) {
                newHeight = windowHeight;
                newWidth = windowHeight * aspectRatio;
            } else {
                newWidth = windowWidth;
                newHeight = windowWidth / aspectRatio;
            }

            moduleInstance.ccall("rl_window_set_size", null, ["number", "number"], [newWidth, newHeight]);
        });
    },
    */
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
            loaderCacheDir: opts.loaderCacheDir ?? moduleOptions.loaderCacheDir ?? "",
            idealWidth: moduleOptions.idealWidth ?? opts.windowWidth ?? 1024,
            idealHeight: moduleOptions.idealHeight ?? opts.windowHeight ?? 1280,
        };
    },
    _ensureModuleInstance: async (opts) => {
        RL._prepareModuleOptions(opts);

        if (moduleInstance) {
            return moduleInstance;
        }

        const moduleFactory = await RL._loadModuleFactory(opts);
        moduleInstance = await moduleFactory(moduleOptions.env);
        if (RL._compareVersion() < 0) {
            throw new Error("incompatible version");
        }
        
        RL._installScratchHelpers();
        RL._patchColorConstants();
        moduleInstance.initScratchArea();

        return moduleInstance;
    },
    boot: async (opts = {}) => {
        await RL._ensureModuleInstance(opts);
        return 0;
    },
    _callInitWithOptionsAsync: async (opts, symbolName, asyncOptions) => {
        await RL._ensureModuleInstance();
        const initOptions = RL._prepareInitOptions(opts);

        const cfgSize = moduleInstance.ccall("rl_init_config_sizeof", "number", [], []) >>> 0;
        if (!cfgSize) {
            throw new Error("rl_init_config_sizeof returned 0");
        }

        const heapMalloc = moduleInstance && (moduleInstance._malloc || moduleInstance.malloc);
        const useHeapAlloc = typeof heapMalloc === "function";
        const canUseStack =
            moduleInstance &&
            typeof moduleInstance.stackSave === "function" &&
            typeof moduleInstance.stackAlloc === "function" &&
            typeof moduleInstance.stackRestore === "function";
        if (!useHeapAlloc && !canUseStack) {
            throw new Error("init config allocation unavailable (need malloc or stackAlloc)");
        }

        let stackTop = 0;
        const allocTemp = (size) => {
            if (useHeapAlloc) {
                return RL._mallocOrThrow(size);
            }
            return moduleInstance.stackAlloc(size) >>> 0;
        };
        const freeTemp = (ptr) => {
            if (useHeapAlloc) {
                RL._freeIfPossible(ptr);
            }
        };
        const stringToTempUtf8OrNull = (s) => {
            if (s == null) {
                return 0;
            }
            if (typeof s !== "string") {
                s = String(s);
            }
            const len = (moduleInstance.lengthBytesUTF8 ? moduleInstance.lengthBytesUTF8(s) : (s.length * 4 + 1)) + 1;
            const ptr = allocTemp(len);
            if (moduleInstance.stringToUTF8) {
                moduleInstance.stringToUTF8(s, ptr, len);
                return ptr >>> 0;
            }
            throw new Error("stringToUTF8 not available; cannot encode JS strings to wasm memory");
        };

        const allocatedPtrs = [];
        let initRc = -1;
        if (symbolName === "rl_init_values" || symbolName === "rl_init_values_async") {
            initRc = (await moduleInstance.ccall(
                symbolName,
                "number",
                ["number", "number", "string", "number", "string", "string"],
                [
                    (initOptions.windowWidth || 0) | 0,
                    (initOptions.windowHeight || 0) | 0,
                    initOptions.windowTitle ?? "",
                    (initOptions.windowFlags || 0) >>> 0,
                    initOptions.assetHost ?? "",
                    initOptions.loaderCacheDir ?? "",
                ],
                asyncOptions
            )) | 0;
        } else {
            try {
                if (!useHeapAlloc) {
                    stackTop = moduleInstance.stackSave();
                }

                const cfgPtr = allocTemp(cfgSize);
                allocatedPtrs.push(cfgPtr);
                const heapU8 = moduleInstance.HEAPU8;
                heapU8.fill(0, cfgPtr, cfgPtr + cfgSize);

                const heapI32 = moduleInstance.HEAP32;
                const setI32 = (offset, v) => {
                    heapI32[(cfgPtr + offset) >> 2] = v | 0;
                };

                // Layout must match `rl_init_config_t` in include/rl_config.h
                setI32(0, (initOptions.windowWidth || 0) | 0);
                setI32(4, (initOptions.windowHeight || 0) | 0);

                const titlePtr = stringToTempUtf8OrNull(initOptions.windowTitle);
                const assetPtr = stringToTempUtf8OrNull(initOptions.assetHost);
                const cachePtr = stringToTempUtf8OrNull(initOptions.loaderCacheDir);
                allocatedPtrs.push(titlePtr, assetPtr, cachePtr);

                setI32(8, titlePtr >>> 0);
                setI32(12, (initOptions.windowFlags || 0) >>> 0);
                setI32(16, assetPtr >>> 0);
                setI32(20, cachePtr >>> 0);

                initRc = (await moduleInstance.ccall(symbolName, "number", ["number"], [cfgPtr], asyncOptions)) | 0;
            } finally {
                if (useHeapAlloc) {
                    for (const ptr of allocatedPtrs) {
                        freeTemp(ptr);
                    }
                } else if (canUseStack) {
                    moduleInstance.stackRestore(stackTop);
                }
            }
        }

        if (initRc !== 0) {
            return initRc;
        }

     /*
        RL._installWebResizeHandler(initOptions);
        if (typeof window !== "undefined" && window.dispatchEvent) {
            window.dispatchEvent(new Event("resize"));
        }
            */
        return 0;
    },
    _callInitWithOptionsImmediate: (opts, symbolName) => {
        const initOptions = RL._prepareInitOptions(opts);

        if (!moduleInstance) {
            throw new Error("Module must be booted before calling polling-style init APIs");
        }

        let initRc = -1;
        if (symbolName === "rl_init_values_async") {
            initRc = moduleInstance.ccall(
                symbolName,
                "number",
                ["number", "number", "string", "number", "string", "string"],
                [
                    (initOptions.windowWidth || 0) | 0,
                    (initOptions.windowHeight || 0) | 0,
                    initOptions.windowTitle ?? "",
                    (initOptions.windowFlags || 0) >>> 0,
                    initOptions.assetHost ?? "",
                    initOptions.loaderCacheDir ?? "",
                ]
            ) | 0;
        } else {
            const cfgSize = moduleInstance.ccall("rl_init_config_sizeof", "number", [], []) >>> 0;
            if (!cfgSize) {
                throw new Error("rl_init_config_sizeof returned 0");
            }

            const heapMalloc = moduleInstance && (moduleInstance._malloc || moduleInstance.malloc);
            const useHeapAlloc = typeof heapMalloc === "function";
            const canUseStack =
                moduleInstance &&
                typeof moduleInstance.stackSave === "function" &&
                typeof moduleInstance.stackAlloc === "function" &&
                typeof moduleInstance.stackRestore === "function";
            if (!useHeapAlloc && !canUseStack) {
                throw new Error("init config allocation unavailable (need malloc or stackAlloc)");
            }

            let stackTop = 0;
            const allocTemp = (size) => {
                if (useHeapAlloc) {
                    return RL._mallocOrThrow(size);
                }
                return moduleInstance.stackAlloc(size) >>> 0;
            };
            const freeTemp = (ptr) => {
                if (useHeapAlloc) {
                    RL._freeIfPossible(ptr);
                }
            };
            const stringToTempUtf8OrNull = (s) => {
                if (s == null) {
                    return 0;
                }
                if (typeof s !== "string") {
                    s = String(s);
                }
                const len = (moduleInstance.lengthBytesUTF8 ? moduleInstance.lengthBytesUTF8(s) : (s.length * 4 + 1)) + 1;
                const ptr = allocTemp(len);
                if (moduleInstance.stringToUTF8) {
                    moduleInstance.stringToUTF8(s, ptr, len);
                    return ptr >>> 0;
                }
                throw new Error("stringToUTF8 not available; cannot encode JS strings to wasm memory");
            };

            const allocatedPtrs = [];
            try {
                if (!useHeapAlloc) {
                    stackTop = moduleInstance.stackSave();
                }

                const cfgPtr = allocTemp(cfgSize);
                allocatedPtrs.push(cfgPtr);
                const heapU8 = moduleInstance.HEAPU8;
                heapU8.fill(0, cfgPtr, cfgPtr + cfgSize);

                const heapI32 = moduleInstance.HEAP32;
                const setI32 = (offset, v) => {
                    heapI32[(cfgPtr + offset) >> 2] = v | 0;
                };

                setI32(0, (initOptions.windowWidth || 0) | 0);
                setI32(4, (initOptions.windowHeight || 0) | 0);

                const titlePtr = stringToTempUtf8OrNull(initOptions.windowTitle);
                const assetPtr = stringToTempUtf8OrNull(initOptions.assetHost);
                const cachePtr = stringToTempUtf8OrNull(initOptions.loaderCacheDir);
                allocatedPtrs.push(titlePtr, assetPtr, cachePtr);

                setI32(8, titlePtr >>> 0);
                setI32(12, (initOptions.windowFlags || 0) >>> 0);
                setI32(16, assetPtr >>> 0);
                setI32(20, cachePtr >>> 0);

                initRc = moduleInstance.ccall(symbolName, "number", ["number"], [cfgPtr]) | 0;
            } finally {
                if (useHeapAlloc) {
                    for (const ptr of allocatedPtrs) {
                        freeTemp(ptr);
                    }
                } else if (canUseStack) {
                    moduleInstance.stackRestore(stackTop);
                }
            }
        }

        if (initRc !== 0) {
            return initRc;
        }

        RL._installWebResizeHandler(initOptions);
        if (typeof window !== "undefined" && window.dispatchEvent) {
            window.dispatchEvent(new Event("resize"));
        }
        return 0;
    },
    init: async (opts) => {
        return await RL._callInitWithOptionsAsync(opts, "rl_init", { async: true });
    },
    initAsync: (opts) => {
        return RL._callInitWithOptionsImmediate(opts, "rl_init_values_async");
    },
    initValues: async (
        width, height, title,
        flags = 0, assetHost = "", loaderCacheDir = ""
    ) => {
        return await RL._callInitWithOptionsAsync({
            windowWidth: width,
            windowHeight: height,
            windowTitle: title,
            windowFlags: flags,
            assetHost,
            loaderCacheDir
        }, "rl_init_values", { async: true });
    },
    initValuesAsync: (
        width, height, title,
        flags = 0, assetHost = "", loaderCacheDir = ""
    ) => {
        return RL._callInitWithOptionsImmediate({
            windowWidth: width,
            windowHeight: height,
            windowTitle: title,
            windowFlags: flags,
            assetHost,
            loaderCacheDir
        }, "rl_init_values_async");
    },
    setAssetHost: (assetHost) => {
        if (typeof assetHost !== "string") {
            return -1;
        }
        return moduleInstance.ccall('rl_set_asset_host', 'number', ['string'], [assetHost]);
    },
    getAssetHost: () => {
        return moduleInstance.ccall('rl_get_asset_host', 'string', [], []);
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
        const runtimeMajor = RL.versionMajor();
        const runtimeMinor = RL.versionMinor();
        const runtimePatch = RL.versionPatch();
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
    versionMajor: () => {
        if (!moduleInstance) {
            return 0;
        }
        return moduleInstance.ccall('rl_version_major', 'number', [], []);
    },
    versionMinor: () => {
        if (!moduleInstance) {
            return 0;
        }
        return moduleInstance.ccall('rl_version_minor', 'number', [], []);
    },
    versionPatch: () => {
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
    versionNumber: () => {
        if (!moduleInstance) {
            return 1;
        }
        return moduleInstance.ccall('rl_version_number', 'number', [], []) >>> 0;
    },
    versionString: () => {
        if (!moduleInstance) {
            return '0.0.1-dev';
        }
        return moduleInstance.ccall('rl_version_string', 'string', [], []);
    },
    uncacheAsset: (filename) => {
        return moduleInstance.ccall('rl_loader_uncache_asset', 'number', ['string'], [filename]);
    },
    clearCache: () => {
        return moduleInstance.ccall('rl_loader_clear_cache', 'number', [], []);
    },
    loaderInit: async (mountPoint = "") => {
        return await moduleInstance.ccall('rl_loader_init', 'number', ['string'], [mountPoint || ""], { async: true });
    },
    loaderInitAsync: (mountPoint = "") => {
        return moduleInstance.ccall('rl_loader_init_async', 'number', ['string'], [mountPoint || ""]);
    },
    loaderDeinit: async () => {
        moduleInstance.ccall('rl_loader_deinit', null, [], [], { async: true });
    },
    loaderIsInitialized: () => {
        return moduleInstance.ccall('rl_loader_is_initialized', 'number', [], []) !== 0;
    },
    loaderIsReady: () => {
        return moduleInstance.ccall('rl_loader_is_ready', 'number', [], []) !== 0;
    },
    getCacheDir: () => {
        return moduleInstance.ccall('rl_loader_get_cache_dir', 'string', [], []);
    },
    pingAssetHost: (assetHost = "") => {
        return moduleInstance.ccall(
            'rl_loader_ping_asset_host',
            'number',
            ['string'],
            [assetHost || ""]
        );
    },
    restoreFSAsync: () => {
        return moduleInstance.ccall('rl_loader_restore_fs_async', 'number', [], []);
    },
    importAsset: async (filename) => {
        if (typeof filename === "string" && /\.gltf(?:[?#].*)?$/i.test(filename)) {
            console.warn(
                `[librl] importAsset("${filename}") does not currently follow .gltf dependencies. ` +
                `Use importAssetAsync()/waitForImportAssetAsync() or a task group instead.`
            );
        }
        return await moduleInstance.ccall(
            'rl_loader_import_asset',
            'number',
            ['string'],
            [filename],
            { async: true }
        );
    },
    importAssetAsync: (filename) => {
        return moduleInstance.ccall('rl_loader_create_import_task', 'number', ['string'], [filename]);
    },
    importAssetsAsync: (filenames) => {
        const count = moduleInstance.writeScratchStringTable(filenames);
        return moduleInstance.ccall('rl_loader_import_assets_from_scratch_async', 'number', ['number'], [count]);
    },
    pollTask: (task) => {
        return moduleInstance.ccall('rl_loader_poll_task', 'number', ['number'], [task]) !== 0;
    },
    finishTask: (task) => {
        return moduleInstance.ccall('rl_loader_finish_task', 'number', ['number'], [task]);
    },
    getTaskPath: (task) => {
        return moduleInstance.ccall('rl_loader_get_task_path', 'string', ['number'], [task]);
    },

/*
    // js native read, using the FS.  We are using the librl version, 
    // but keep this around for reference

    readLocal: (filename) => {
        const fs = moduleInstance && moduleInstance.FS;
        let data = null;
        if (!fs || typeof fs.readFile !== "function") {
            return null;
        }
        try {
            data = fs.readFile(filename);
        } catch (_err) {
            return null;
        }
        return data instanceof Uint8Array ? data : new Uint8Array(data);
    },
*/

    readLocal: (filename) => {
        if (!moduleInstance) {
            return null;
        }
        const readFn = moduleInstance._rl_loader_read_local;
        const freeResultFn = moduleInstance._rl_loader_read_result_free;
        const stackSave = moduleInstance.stackSave;
        const stackRestore = moduleInstance.stackRestore;
        const stackAlloc = moduleInstance.stackAlloc;
        const heapU32 = moduleInstance.HEAPU32;
        const heapI32 = moduleInstance.HEAP32;
        const heapU8 = moduleInstance.HEAPU8;
        if (
            typeof readFn !== "function" ||
            typeof freeResultFn !== "function" ||
            typeof stackSave !== "function" ||
            typeof stackRestore !== "function" ||
            typeof stackAlloc !== "function" ||
            !heapU32 ||
            !heapI32 ||
            !heapU8
        ) {
            return null;
        }
        const name = filename == null ? "" : String(filename);
        const prevSp = stackSave();
        try {
            const resultPtr = stackAlloc(12) >>> 0;
            const pathPtr = RL._stringToNewUtf8OrNull(name);
            if (!pathPtr && name.length > 0) {
                return null;
            }
            try {
                readFn(resultPtr >>> 0, pathPtr >>> 0);
            } finally {
                RL._freeIfPossible(pathPtr);
            }
            const dataPtr = heapU32[resultPtr >>> 2] >>> 0;
            const size = heapU32[(resultPtr + 4) >>> 2] >>> 0;
            const err = heapI32[(resultPtr + 8) >>> 2] | 0;
            if (err !== 0 || !dataPtr) {
                freeResultFn(resultPtr);
                return null;
            }
            const out = new Uint8Array(size);
            if (size > 0) {
                out.set(heapU8.subarray(dataPtr, dataPtr + size));
            }
            freeResultFn(resultPtr);
            return out;
        } finally {
            stackRestore(prevSp);
        }
    },
  
    taskIsValid: (task) => {
        //return moduleInstance.ccall('rl_loader_task_is_valid', 'number', ['number'], [task]) !== 0;
        return task !== 0;
    },

    freeTask: (task) => {
        return moduleInstance.ccall('rl_loader_free_task', null, ['number'], [task]);
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

        // Mirror the cpp binding's rl_loader_add_task behavior with local JS
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
                'rl_loader_add_task',
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
    loaderTick: () => {
        moduleInstance.ccall('rl_loader_tick', null, [], []);
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
                    path: RL.getTaskPath(task),
                    done: false,
                    rc: 1,
                    onSuccess: typeof onSuccess === "function" ? onSuccess : null,
                    onError: typeof onTaskError === "function" ? onTaskError : null,
                });
            },
            addImportTask(path, onSuccess = null, onTaskError = null) {
                this.addTask(RL.importAssetAsync(path), onSuccess, onTaskError);
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
                RL.loaderTick();
                for (const entry of this.entries) {
                    if (entry.done) {
                        continue;
                    }
                    if (!RL.pollTask(entry.task)) {
                        continue;
                    }
                    entry.rc = RL.finishTask(entry.task);
                    RL.freeTask(entry.task);
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
    isAssetCached: (filename) => {
        return moduleInstance.ccall('rl_loader_is_asset_cached', 'number', ['string'], [filename]) !== 0;
    },
    waitForTask: async (task, pollMs = 16) => {
        let rc = 0;

        if (!task) {
            return -1;
        }

        while (!RL.pollTask(task)) {
            await new Promise((resolve) => setTimeout(resolve, pollMs));
        }

        rc = RL.finishTask(task);
        RL.freeTask(task);
        return rc;
    },
    restoreAsync: async () => {
        return RL.waitForTask(RL.restoreFSAsync());
    },
    waitForImportAssetAsync: async (filename) => {
        return RL.waitForTask(RL.importAssetAsync(filename));
    },
    waitForImportAssetsAsync: async (filenames) => {
        return RL.waitForTask(RL.importAssetsAsync(filenames));
    },
    emitEvent: (eventName, payload = 0) => {
        return moduleInstance.ccall('rl_event_emit', 'number', ['string', 'number'], [eventName, payload]);
    },
    onEvent: (eventName, callback) => {
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
    onceEvent: (eventName, callback) => {
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
    offEvent: (eventName, callback) => {
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
    clearEventListeners: (eventName) => {
        const rc = moduleInstance.ccall('rl_event_off_all', 'number', ['string'], [eventName]);
        if (rc === 0) {
            RL._clearListenerCacheForEvent(eventName);
        }
        return rc;
    },
    getEventListenerCount: (eventName) => {
        return moduleInstance.ccall('rl_event_listener_count', 'number', ['string'], [eventName]);
    },
    setWindowSize: (width, height) => {
        return moduleInstance.ccall('rl_window_set_size', null, ['number', 'number'], [width, height]);
    },
    isWindowCloseRequested: () => {
        return !!moduleInstance.ccall('rl_window_close_requested', 'number', [], []);
    },
    getMonitorCount: () => {
        return moduleInstance.ccall('rl_window_get_monitor_count', 'number', [], []);
    },
    setWindowTitle: (title) => {
        return moduleInstance.ccall('rl_window_set_title', null, ['string'], [title]);
    },
    getCurrentMonitor: () => {
        return moduleInstance.ccall('rl_window_get_current_monitor', 'number', [], []);
    },
    setWindowMonitor: (monitor) => {
        return moduleInstance.ccall('rl_window_set_monitor', null, ['number'], [monitor]);
    },
    getMonitorWidth: (monitor) => {
        return moduleInstance.ccall('rl_window_get_monitor_width', 'number', ['number'], [monitor]);
    },
    getMonitorHeight: (monitor) => {
        return moduleInstance.ccall('rl_window_get_monitor_height', 'number', ['number'], [monitor]);
    },
    setWindowPosition: (x, y) => {
        return moduleInstance.ccall('rl_window_set_position', null, ['number', 'number'], [x, y]);
    },
    beginDrawing: () => {
        return moduleInstance.ccall('rl_render_begin', null, [], []);
    },
    endDrawing: () => {
        return moduleInstance.ccall('rl_render_end', null, [], []);
    },
    beginMode2D: (camera) => {
        return moduleInstance.ccall('rl_render_begin_mode_2d', null, ['number'], [camera]);
    },
    endMode2D: () => {
        return moduleInstance.ccall('rl_render_end_mode_2d', null, [], []);
    },
    beginMode3d: () => {
        return moduleInstance.ccall('rl_render_begin_mode_3d', null, [], []);
    },
    endMode3d: () => {
        return moduleInstance.ccall('rl_render_end_mode_3d', null, [], []);
    },
    tick: () => {
        moduleInstance.ccall('rl_scratch_refresh', null, [], []);
        return moduleInstance.ccall('rl_tick', 'number', [], []);
    },
    getDeltaTime: () => {
        return moduleInstance.ccall('rl_get_delta_time', 'number', [], []);
    },
    createCamera3d: (
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
    getDefaultCamera3d: () => {
        return moduleInstance.ccall('rl_camera3d_get_default', 'number', [], []);
    },
    setCamera3d: (
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
    setActiveCamera3d: (camera) => {
        return moduleInstance.ccall('rl_camera3d_set_active', 'number', ['number'], [camera]) !== 0;
    },
    getActiveCamera3d: () => {
        return moduleInstance.ccall('rl_camera3d_get_active', 'number', [], []);
    },
    destroyCamera3d: (camera) => {
        return moduleInstance.ccall('rl_camera3d_destroy', null, ['number'], [camera]);
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
    },
    clearBackground: (color) => {
        return moduleInstance.ccall('rl_render_clear_background', null, ['number'], [color]);
    },
    drawCube: (positionX, positionY, positionZ, width, height, length, color) => {
        return moduleInstance.ccall(
            'rl_shape_draw_cube',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [positionX, positionY, positionZ, width, height, length, color]
        );
    },
    drawFPS: (x, y) => {
        return moduleInstance.ccall('rl_text_draw_fps', null, ['number', 'number'], [x, y]);
    },
    drawFPSEx: (font, x, y, fontSize, color) => {
        moduleInstance.ccall('rl_text_draw_fps_ex', null, ['number', 'number', 'number', 'number', 'number'], [font, x, y, fontSize, color]);
    },
    drawText: (text, x, y, fontSize, color) => {
        return moduleInstance.ccall('rl_text_draw', null, ['string', 'number', 'number', 'number', 'number'], [text, x, y, fontSize, color]);
    },
    drawTextEx: (font, text, x, y, fontSize, spacing, tint) => {
        return moduleInstance.ccall('rl_text_draw_ex', null, ['number', 'string', 'number', 'number', 'number', 'number', 'number'], [font, text, x, y, fontSize, spacing, tint]);
    },
    drawTextureEx: (texture, x, y, scale, rotation, tint) => {
        return moduleInstance.ccall('rl_texture_draw_ex', null, ['number', 'number', 'number', 'number', 'number', 'number'], [texture, x, y, scale, rotation, tint]);
    },
    drawTextureGround: (texture, positionX, positionY, positionZ, width, length, tint) => {
        return moduleInstance.ccall('rl_texture_draw_ground', null, ['number', 'number', 'number', 'number', 'number', 'number', 'number'], [texture, positionX, positionY, positionZ, width, length, tint]);
    },
    measureText: (text, fontSize) => {
        return moduleInstance.ccall('rl_text_measure', 'number', ['string', 'number'], [text, fontSize]);
    },
    pollInputEvents: () => {
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
    // while desktop gets the return structure directly
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
    getScreenSize: () => {
        moduleInstance.ccall('rl_window_get_screen_size_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    },
    getScreenWidth: () => {
        return RL.getScreenSize().x;
    },
    getScreenHeight: () => {
        return RL.getScreenSize().y;
    },
    getWindowPosition: () => {
        moduleInstance.ccall('rl_window_get_position_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    },
    getMonitorPosition: (monitor = 0) => {
        moduleInstance.ccall('rl_window_get_monitor_position_to_scratch', null, ['number'], [monitor]);
        return moduleInstance.getVector2();
    },
    getMousePosition: () => {
        moduleInstance.ccall('rl_input_get_mouse_position_to_scratch', null, [], []);
        return moduleInstance.getVector2();
    },
    measureTextEx: (font, text, fontSize, spacing = 1) => {
        moduleInstance.ccall('rl_text_measure_ex_to_scratch', 'number', ['number', 'string', 'number', 'number'], [font, text, fontSize, spacing]);
        return moduleInstance.getVector2();
    },
    // End Scratch-backed wrappers

    // Predefined color handles: export the C globals and read their values once at init.
    // Uses EXPORTED_GLOBALS for _RL_COLOR_* so JS never redefines the numbers itself.
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
    CAMERA_PERSPECTIVE: 0,
    CAMERA_ORTHOGRAPHIC: 1,
    FLAG_MSAA_4X_HINT: 32,
    FLAG_WINDOW_RESIZABLE: 4,
    BUTTON_UP: 0,
    BUTTON_PRESSED: 1,
    BUTTON_DOWN: 2,
    BUTTON_RELEASED: 3,
    // },

    createColor: (r, g, b, a) => moduleInstance.ccall(
        "rl_color_create", "number", ["number", "number", "number", "number"], [r, g, b, a]
    ),
    destroyColor: (color) => moduleInstance.ccall(
        "rl_color_destroy", null, ["number"], [color]
    ),
    createFont: (path, fontSize) => moduleInstance.ccall(
        "rl_font_create", "number", ["string", "number"], [path, fontSize]
    ),
    destroyFont: (font) => moduleInstance.ccall(
        "rl_font_destroy", null, ["number"], [font]
    ),
    rl_font_get_default: () => moduleInstance.ccall(
        "rl_font_get_default", "number", [], []
    ),
    setTargetFPS: (fps) => moduleInstance.ccall(
        "rl_set_target_fps", null, ["number"], [fps]
    ),
    createModel: (path) => moduleInstance.ccall(
        "rl_model_create", "number", ["string"], [path]
    ),
    modelSetTransform: (
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
    drawModel: (model, tint) => moduleInstance.ccall(
        "rl_model_draw", null, ["number", "number"], [model, tint]
    ),
    isModelValid: (model) => moduleInstance.ccall(
        "rl_model_is_valid", "number", ["number"], [model]
    ) !== 0,
    isModelValidStrict: (model) => moduleInstance.ccall(
        "rl_model_is_valid_strict", "number", ["number"], [model]
    ) !== 0,
    modelAnimationCount: (model) => moduleInstance.ccall(
        "rl_model_animation_count", "number", ["number"], [model]
    ),
    modelAnimationFrameCount: (model, animationIndex) => moduleInstance.ccall(
        "rl_model_animation_frame_count", "number", ["number", "number"], [model, animationIndex]
    ),
    modelAnimationUpdate: (model, animationIndex, frame) => moduleInstance.ccall(
        "rl_model_animation_update", null, ["number", "number", "number"], [model, animationIndex, frame]
    ),
    modelSetAnimation: (model, animationIndex) => moduleInstance.ccall(
        "rl_model_set_animation", "number", ["number", "number"], [model, animationIndex]
    ) !== 0,
    modelSetAnimationSpeed: (model, speed) => moduleInstance.ccall(
        "rl_model_set_animation_speed", "number", ["number", "number"], [model, speed]
    ) !== 0,
    modelSetAnimationLoop: (model, shouldLoop) => moduleInstance.ccall(
        "rl_model_set_animation_loop", "number", ["number", "number"], [model, shouldLoop ? 1 : 0]
    ) !== 0,
    modelAnimate: (model, deltaSeconds) => moduleInstance.ccall(
        "rl_model_animate", "number", ["number", "number"], [model, deltaSeconds]
    ) !== 0,
    destroyModel: (model) => moduleInstance.ccall(
        "rl_model_destroy", null, ["number"], [model]
    ),
    pickModel: (camera, model, mouseX, mouseY) => {
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
    pickSprite3d: (camera, sprite3d, mouseX, mouseY) => {
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
    resetPickStats: () => {
        moduleInstance.ccall("rl_pick_reset_stats", null, [], []);
    },
    getPickStats: () => {
        return {
            broadphaseTests: moduleInstance.ccall("rl_pick_get_broadphase_tests", "number", [], []),
            broadphaseRejects: moduleInstance.ccall("rl_pick_get_broadphase_rejects", "number", [], []),
            narrowphaseTests: moduleInstance.ccall("rl_pick_get_narrowphase_tests", "number", [], []),
            narrowphaseHits: moduleInstance.ccall("rl_pick_get_narrowphase_hits", "number", [], [])
        };
    },
    createMusic: (path) => moduleInstance.ccall(
        "rl_music_create", "number", ["string"], [path]
    ),
    destroyMusic: (music) => moduleInstance.ccall(
        "rl_music_destroy", null, ["number"], [music]
    ),
    playMusic: (music) => moduleInstance.ccall(
        "rl_music_play", "number", ["number"], [music]
    ) !== 0,
    pauseMusic: (music) => moduleInstance.ccall(
        "rl_music_pause", "number", ["number"], [music]
    ) !== 0,
    stopMusic: (music) => moduleInstance.ccall(
        "rl_music_stop", "number", ["number"], [music]
    ) !== 0,
    setMusicLoop: (music, shouldLoop) => moduleInstance.ccall(
        "rl_music_set_loop", "number", ["number", "number"], [music, shouldLoop ? 1 : 0]
    ) !== 0,
    setMusicVolume: (music, volume) => moduleInstance.ccall(
        "rl_music_set_volume", "number", ["number", "number"], [music, volume]
    ) !== 0,
    isMusicPlaying: (music) => moduleInstance.ccall(
        "rl_music_is_playing", "number", ["number"], [music]
    ) !== 0,
    updateMusic: (music) => moduleInstance.ccall(
        "rl_music_update", "number", ["number"], [music]
    ) !== 0,
    updateAllMusic: () => moduleInstance.ccall(
        "rl_music_update_all", null, [], []
    ),
    createSound: (path) => moduleInstance.ccall(
        "rl_sound_create", "number", ["string"], [path]
    ),
    destroySound: (sound) => moduleInstance.ccall(
        "rl_sound_destroy", null, ["number"], [sound]
    ),
    playSound: (sound) => moduleInstance.ccall(
        "rl_sound_play", "number", ["number"], [sound]
    ) !== 0,
    pauseSound: (sound) => moduleInstance.ccall(
        "rl_sound_pause", "number", ["number"], [sound]
    ) !== 0,
    resumeSound: (sound) => moduleInstance.ccall(
        "rl_sound_resume", "number", ["number"], [sound]
    ) !== 0,
    stopSound: (sound) => moduleInstance.ccall(
        "rl_sound_stop", "number", ["number"], [sound]
    ) !== 0,
    setSoundVolume: (sound, volume) => moduleInstance.ccall(
        "rl_sound_set_volume", "number", ["number", "number"], [sound, volume]
    ) !== 0,
    setSoundPitch: (sound, pitch) => moduleInstance.ccall(
        "rl_sound_set_pitch", "number", ["number", "number"], [sound, pitch]
    ) !== 0,
    setSoundPan: (sound, pan) => moduleInstance.ccall(
        "rl_sound_set_pan", "number", ["number", "number"], [sound, pan]
    ) !== 0,
    isSoundPlaying: (sound) => moduleInstance.ccall(
        "rl_sound_is_playing", "number", ["number"], [sound]
    ) !== 0,
    createTexture: (path) => moduleInstance.ccall(
        "rl_texture_create", "number", ["string"], [path]
    ),
    destroyTexture: (texture) => moduleInstance.ccall(
        "rl_texture_destroy", null, ["number"], [texture]
    ),
    createSprite3d: (path) => moduleInstance.ccall(
        "rl_sprite3d_create", "number", ["string"], [path]
    ),
    createSprite3dFromTexture: (texture) => moduleInstance.ccall(
        "rl_sprite3d_create_from_texture", "number", ["number"], [texture]
    ),
    sprite3dSetTransform: (sprite, positionX, positionY, positionZ, size) => moduleInstance.ccall(
        "rl_sprite3d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, positionX, positionY, positionZ, size]
    ) !== 0,
    drawSprite3d: (sprite, tint) => moduleInstance.ccall(
        "rl_sprite3d_draw", null, ["number", "number"], [sprite, tint]
    ),
    destroySprite3d: (sprite) => moduleInstance.ccall(
        "rl_sprite3d_destroy", null, ["number"], [sprite]
    ),
    createSprite2D: (path) => moduleInstance.ccall(
        "rl_sprite2d_create", "number", ["string"], [path]
    ),
    createSprite2DFromTexture: (texture) => moduleInstance.ccall(
        "rl_sprite2d_create_from_texture", "number", ["number"], [texture]
    ),
    sprite2DSetTransform: (sprite, x, y, scale, rotation) => moduleInstance.ccall(
        "rl_sprite2d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, x, y, scale, rotation]
    ) !== 0,
    drawSprite2D: (sprite, tint) => moduleInstance.ccall(
        "rl_sprite2d_draw", null, ["number", "number"], [sprite, tint]
    ),
    destroySprite2D: (sprite) => moduleInstance.ccall(
        "rl_sprite2d_destroy", null, ["number"], [sprite]
    ),
    loggerMessage: (level, message) => moduleInstance.ccall(
        "rl_logger_message", null, ["number", "string"], [level, String(message ?? "").replaceAll("%", "%%")]
    ),
    loggerSetLevel: (level) => moduleInstance.ccall(
        "rl_logger_set_level", null, ["number"], [level]
    ),

};

export const rl = RL;
export default RL;
