import {
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
    RL_BINDING_BUILT_VERSION_STRING,
} from '../gen/rl_version.js';
import type { EmscriptenFactory, EmscriptenModule } from './emscripten.js';
import type { ScratchAreaOffsets } from './scratch.js';
import type {
    RLApi,
    RLAsset,
    RLCamera3d,
    RLColor,
    RLColorPreset,
    RLColorPresets,
    RLDebug,
    RLEvent,
    RLFont,
    RLFs,
    RLKeyboardState,
    RLGamepadState,
    RLTouchpoint,
    RLAssetTaskCallback,
    RLHelpers,
    RLInitOptions,
    RLInput,
    RLLogger,
    RLModel,
    RLMusic,
    RLPickResult,
    RLPick,
    RLRender,
    RLScene,
    RLShape,
    RLSound,
    RLSprite2d,
    RLSprite3d,
    RLTaskGroup,
    RLTaskGroupCallback,
    RLTaskGroupTaskCallback,
    RLText,
    RLText2d,
    RLTexture,
    RLWindow,
    RLHandle,
} from './types.js';

export type * from './types.js';

export {
    RL_BINDING_BUILT_MAJOR,
    RL_BINDING_BUILT_MINOR,
    RL_BINDING_BUILT_PATCH,
    RL_BINDING_BUILT_VERSION_STRING,
} from '../gen/rl_version.js';

let moduleInstance: EmscriptenModule | undefined;
let moduleFactoryPromise: Promise<EmscriptenFactory> | null = null;
let moduleFactoryPath = "";
let moduleOptions: RLInitOptions = {};
let scratchAreaPtr = 0;
let scratchAreaBytePtr = 0;
let scratchAreaOffsets = {} as ScratchAreaOffsets;

const BOOT_OK = 0;
const BOOT_ERR_UNKNOWN = -10;
const BOOT_ERR_LOADER = -11;
const BOOT_ERR_VERSION_MISMATCH = -12;

function reqModule(): EmscriptenModule {
    if (!moduleInstance) {
        throw new Error("RL module not initialized");
    }
    return moduleInstance;
}

function ccNum(
    name: string,
    argTypes: string[] = [],
    args: unknown[] = [],
    opts?: { async?: boolean },
): number {
    return reqModule().ccall(name, "number", argTypes, args, opts) as number;
}

function ccStr(name: string, argTypes: string[] = [], args: unknown[] = []): string {
    return reqModule().ccall(name, "string", argTypes, args) as string;
}

function ccHandle(name: string, argTypes: string[] = [], args: unknown[] = []): RLHandle {
    return ccNum(name, argTypes, args);
}

let eventDispatchPtr = 0;
let nextEventListenerId = 1;
let eventListenersById = new Map();
let eventListenerIdsByCallback = new WeakMap();
const dispatchEventFromWasm = (payload: number, userData: number) => {
        const listener = eventListenersById.get(userData >>> 0);
        if (!listener || typeof listener.callback !== "function") {
            return;
        }
        listener.callback(payload >>> 0);
    };
const ensureEventDispatchPtr = () => {
        if (!moduleInstance || eventDispatchPtr !== 0) {
            return;
        }
        eventDispatchPtr = moduleInstance.addFunction(
            dispatchEventFromWasm as (...args: unknown[]) => unknown,
            "vii",
        );
    };
const forgetListenerById = (listenerId: number) => {
        const listener = eventListenersById.get(listenerId);
        let callbackMap = null;
        if (!listener) {
            return;
        }
        callbackMap = eventListenerIdsByCallback.get(listener.callback);
        if (callbackMap) {
            callbackMap.delete(listener.eventName);
        }
        eventListenersById.delete(listenerId);
    };
const clearListenerCacheForEvent = (eventName: string) => {
        const idsToDelete: number[] = [];
        eventListenersById.forEach((listener, id) => {
            if (listener && listener.eventName === eventName) {
                idsToDelete.push(id);
            }
        });
        idsToDelete.forEach((id) => forgetListenerById(id));
    };
const clearRunCallbacks = () => {
        /* Reserved for symmetry with deinit; run/start/stop removed from librl. */
    };
const installScratchHelpers = () => {
        const Module = moduleInstance;
        if (!Module) {
            return;
        }

        Module.initScratchArea = () => {
            const HEAP32 = Module.HEAP32;
            scratchAreaBytePtr = Module.ccall("rl_scratch_get_base", "number", [], []) as number;
            scratchAreaPtr = scratchAreaBytePtr >> 2;
            const scratchAreaOffsetsPtr = (Module.ccall("rl_scratch_get_offsets", "number", [], []) as number) >> 2;

            scratchAreaOffsets = {
                vector2: HEAP32[scratchAreaOffsetsPtr],
                vector3: HEAP32[scratchAreaOffsetsPtr + 1],
                vector4: HEAP32[scratchAreaOffsetsPtr + 2],
                matrix: HEAP32[scratchAreaOffsetsPtr + 3],
                quaternion: HEAP32[scratchAreaOffsetsPtr + 4],
                color: HEAP32[scratchAreaOffsetsPtr + 5],
                rectangle: HEAP32[scratchAreaOffsetsPtr + 6],
                pickResult: {
                    hit: HEAP32[scratchAreaOffsetsPtr + 7],
                    handle: HEAP32[scratchAreaOffsetsPtr + 8],
                    distance: HEAP32[scratchAreaOffsetsPtr + 9],
                    point: HEAP32[scratchAreaOffsetsPtr + 10],
                    normal: HEAP32[scratchAreaOffsetsPtr + 11],
                },
                mouse: {
                    x: HEAP32[scratchAreaOffsetsPtr + 12],
                    y: HEAP32[scratchAreaOffsetsPtr + 13],
                    wheel: HEAP32[scratchAreaOffsetsPtr + 14],
                    buttons: HEAP32[scratchAreaOffsetsPtr + 15],
                    dx: HEAP32[scratchAreaOffsetsPtr + 16],
                    dy: HEAP32[scratchAreaOffsetsPtr + 17],
                },
                keyboard: {
                    max_num_keys: HEAP32[scratchAreaOffsetsPtr + 18],
                    keys: HEAP32[scratchAreaOffsetsPtr + 19],
                    pressed_key: HEAP32[scratchAreaOffsetsPtr + 20],
                    pressed_char: HEAP32[scratchAreaOffsetsPtr + 21],
                    num_pressed_keys: HEAP32[scratchAreaOffsetsPtr + 22],
                    pressed_keys: HEAP32[scratchAreaOffsetsPtr + 23],
                    num_pressed_chars: HEAP32[scratchAreaOffsetsPtr + 24],
                    pressed_chars: HEAP32[scratchAreaOffsetsPtr + 25],
                },
                gamepads: {
                    max_num_gamepads: HEAP32[scratchAreaOffsetsPtr + 26],
                    gamepad: HEAP32[scratchAreaOffsetsPtr + 27],
                    id: HEAP32[scratchAreaOffsetsPtr + 28],
                    axis: HEAP32[scratchAreaOffsetsPtr + 29],
                    buttons: HEAP32[scratchAreaOffsetsPtr + 30],
                    stride: HEAP32[scratchAreaOffsetsPtr + 31] >> 2,
                },
                touchpoints: {
                    count: HEAP32[scratchAreaOffsetsPtr + 32],
                    touchpoint: HEAP32[scratchAreaOffsetsPtr + 33],
                    id: HEAP32[scratchAreaOffsetsPtr + 34],
                    x: HEAP32[scratchAreaOffsetsPtr + 35],
                    y: HEAP32[scratchAreaOffsetsPtr + 36],
                    stride: HEAP32[scratchAreaOffsetsPtr + 37] >> 2,
                },
                stringTable: {
                    offsets: HEAP32[scratchAreaOffsetsPtr + 38],
                    bytes: HEAP32[scratchAreaOffsetsPtr + 39],
                    maxEntries: HEAP32[scratchAreaOffsetsPtr + 40],
                    maxBytes: HEAP32[scratchAreaOffsetsPtr + 41],
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

        Module.getPickResult = (): RLPickResult => {
            const HEAPU8 = Module.HEAPU8;
            const HEAP32 = Module.HEAP32;
            const HEAPF32 = Module.HEAPF32;
            const pointOffset = scratchAreaPtr + (scratchAreaOffsets.pickResult.point >> 2);
            const normalOffset = scratchAreaPtr + (scratchAreaOffsets.pickResult.normal >> 2);
            return {
                hit: HEAPU8[scratchAreaBytePtr + scratchAreaOffsets.pickResult.hit] !== 0,
                handle: HEAP32[scratchAreaPtr + (scratchAreaOffsets.pickResult.handle >> 2)] >>> 0,
                distance: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.pickResult.distance >> 2)],
                point: {
                    x: HEAPF32[pointOffset],
                    y: HEAPF32[pointOffset + 1],
                    z: HEAPF32[pointOffset + 2],
                },
                normal: {
                    x: HEAPF32[normalOffset],
                    y: HEAPF32[normalOffset + 1],
                    z: HEAPF32[normalOffset + 2],
                },
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
                dx: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.dx >> 2)],
                dy: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.dy >> 2)],
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
                const encodedLength = (Module.lengthBytesUTF8?.(text) ?? (text.length * 4 + 1)) + 1;
                if (byteOffset + encodedLength > maxBytes) {
                    throw new Error(`scratch string bytes overflow at index ${i}`);
                }
                HEAPU32[offsetsIndex + i] = byteOffset >>> 0;
                Module.stringToUTF8?.(text, bytesIndex + byteOffset, encodedLength);
                byteOffset += encodedLength;
            }

            return values.length;
        };
    };
const mallocOrThrow = (size: number) => {
        const m = moduleInstance && (moduleInstance._malloc || moduleInstance.malloc);
        if (typeof m !== "function") {
            throw new Error("malloc not available in emscripten module (expected _malloc or malloc)");
        }
        const p = m(size) >>> 0;
        if (!p) {
            throw new Error("malloc failed");
        }
        return p;
    };
const freeIfPossible = (p: number) => {
        if (!p) {
            return;
        }
        const f = moduleInstance && (moduleInstance._free || moduleInstance.free);
        if (typeof f === "function") {
            f(p);
        }
    };
const stringToNewUtf8OrNull = (s: string | null | undefined) => {
        if (s == null) {
            return 0;
        }
        if (typeof s !== "string") {
            s = String(s);
        }
        const mod = reqModule();
        if (mod.stringToNewUTF8) {
            return mod.stringToNewUTF8(s) >>> 0;
        }
        const len = (mod.lengthBytesUTF8 ? mod.lengthBytesUTF8(s) : (s.length * 4 + 1)) + 0;
        const bytes = mallocOrThrow(len);
        if (mod.stringToUTF8) {
            mod.stringToUTF8(s, bytes, len);
        } else {
            throw new Error("stringToUTF8 not available; cannot encode JS strings to wasm memory");
        }
        return bytes;
    };
const getModulePath = (opts: RLInitOptions) => {
        const modulePath = opts?.modulePath ?? moduleOptions.modulePath;
        if (modulePath) {
            return String(modulePath);
        }
        return new URL("../../../lib/librl.js", import.meta.url).href;
    };
const loadModuleFactory = async (opts: RLInitOptions) => {
        const modulePath = getModulePath(opts);
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
    };
const prepareModuleOptions = (opts: RLInitOptions = {}): RLInitOptions => {
        const merged: RLInitOptions = {
            ...moduleOptions,
            ...opts,
            env: {
                ...(moduleOptions.env ?? {}),
                ...(opts.env ?? {}),
            },
        };
        moduleOptions = merged;
        const env = moduleOptions.env ?? (moduleOptions.env = {});

        if (moduleOptions.idealWidth == null && moduleOptions.windowWidth != null) {
            moduleOptions.idealWidth = moduleOptions.windowWidth;
        }
        if (moduleOptions.idealHeight == null && moduleOptions.windowHeight != null) {
            moduleOptions.idealHeight = moduleOptions.windowHeight;
        }

        if (moduleOptions.wasmPath && !env.locateFile) {
            env.locateFile = (path, prefix) => {
                return path === "librl.wasm" ? String(moduleOptions.wasmPath) : prefix + path;
            };
        }

        if (!env.canvas && typeof document !== "undefined") {
            const canvasId = moduleOptions.canvasId || "renderCanvas";
            env.canvas = document.getElementById(canvasId) as HTMLCanvasElement | null;
        }
        if (!env.print) {
            env.print = (...args: unknown[]) => {
                console.log(...args);
            };
        }
        if (!env.printErr) {
            env.printErr = (...args: unknown[]) => {
                console.error(...args);
            };
        }
        return moduleOptions;
    };
const prepareInitOptions = (opts: RLInitOptions = {}) => {
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
    };
const hasJspiSupport = () => {
        const wasm = WebAssembly as typeof WebAssembly & {
            Suspending?: unknown;
            promising?: unknown;
        };
        return typeof wasm.Suspending === "function"
            && typeof wasm.promising === "function";
    };
const tryLoadModuleInstance = async (opts: RLInitOptions = {}) => {
        prepareModuleOptions(opts);

        if (moduleInstance) {
            return BOOT_OK;
        }

        try {
            const moduleFactory = await loadModuleFactory(opts);
            moduleInstance = await moduleFactory(moduleOptions.env as Record<string, unknown> | undefined);
        } catch (err) {
            console.error("RL.boot failed", err);
            moduleInstance = undefined;
            return BOOT_ERR_LOADER;
        }

        if (compareVersion() < 0) {
            moduleInstance = undefined;
            return BOOT_ERR_VERSION_MISMATCH;
        }

        installScratchHelpers();
        patchColorConstants();
        moduleInstance.initScratchArea();

        return BOOT_OK;
    };
const ensureModuleInstance = async (opts: RLInitOptions = {}) => {
        const rc = await tryLoadModuleInstance(opts);
        if (rc !== BOOT_OK) {
            throw new Error(`RL boot failed with code ${rc}`);
        }
        return moduleInstance;
    };
const initValuesCcallArgs = (initOptions: ReturnType<typeof prepareInitOptions>) => [
        (initOptions.windowWidth || 0) | 0,
        (initOptions.windowHeight || 0) | 0,
        initOptions.windowTitle ?? "",
        (initOptions.windowFlags || 0) >>> 0,
        initOptions.assetHost ?? "",
        initOptions.fsRootDir ?? "",
    ];
const callInitWithOptionsAsync = async (
        opts: RLInitOptions,
        symbolName: string,
        asyncOptions: { async?: boolean },
    ) => {
        await ensureModuleInstance(opts);
        const initOptions = prepareInitOptions(opts);

        const initRc = (await reqModule().ccall(
            symbolName,
            "number",
            ["number", "number", "string", "number", "string", "string"],
            initValuesCcallArgs(initOptions),
            asyncOptions
        ) as number) | 0;

        if (initRc !== 0) {
            return initRc;
        }

        return 0;
    };
const callInitWithOptionsImmediate = (opts: RLInitOptions, symbolName: string) => {
        const initOptions = prepareInitOptions(opts);

        if (!moduleInstance) {
            throw new Error("Module must be booted before calling polling-style init APIs");
        }

        const initRc = (reqModule().ccall(
            symbolName,
            "number",
            ["number", "number", "string", "number", "string", "string"],
            initValuesCcallArgs(initOptions)
        ) as number) | 0;

        if (initRc !== 0) {
            return initRc;
        }

        return 0;
    };
const compareVersion = () => {
        console.info(
            `[librl] bindings version: ${RL_BINDING_BUILT_MAJOR}, ${RL_BINDING_BUILT_MINOR}, ${RL_BINDING_BUILT_PATCH}`,
        );
        if (!moduleInstance) {
            console.info('[librl] librl version: (not loaded)');
            return -3;
        }
        const runtimeMajor = moduleInstance.ccall('rl_version_major', 'number', [], []) as number;
        const runtimeMinor = moduleInstance.ccall('rl_version_minor', 'number', [], []) as number;
        const runtimePatch = moduleInstance.ccall('rl_version_patch', 'number', [], []) as number;
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
    };
const RL_COLOR_NAMES = [
        "DEFAULT", "LIGHTGRAY", "GRAY", "DARKGRAY",
        "YELLOW", "GOLD", "ORANGE", "PINK",
        "RED", "MAROON", "GREEN", "LIME",
        "DARKGREEN", "SKYBLUE", "BLUE", "DARKBLUE",
        "PURPLE", "VIOLET", "DARKPURPLE",
        "BEIGE", "BROWN", "DARKBROWN",
        "WHITE", "BLACK", "BLANK", "MAGENTA", "RAYWHITE"
    ] as const satisfies readonly RLColorPreset[];

const rlCore = {
    TICK_RUNNING: 0,
    TICK_WAITING: 1,
    TICK_FAILED: -1,
    boot: async (opts = {}) => {
        if (!hasJspiSupport()) {
            return BOOT_ERR_LOADER;
        }

        try {
            return await tryLoadModuleInstance(opts);
        } catch (err) {
            console.error("RL.boot failed", err);
            moduleInstance = undefined;
            return BOOT_ERR_UNKNOWN;
        }
    },
    init: async (opts: RLInitOptions = {}) => {
        return await callInitWithOptionsAsync(opts, "rl_init_values", { async: true });
    },
    initAsync: (opts: RLInitOptions = {}) => {
        return callInitWithOptionsImmediate(opts, "rl_init_values_async");
    },
    refreshScratch: () => {
        reqModule().ccall('rl_scratch_refresh', null, [], []);
    },
    getTime: () => ccNum('rl_get_time'),
    handleKind: (handle: RLHandle) => ccNum('rl_handle_get_kind', ['number'], [handle]),
    deinit: async () => {
        eventListenersById.clear();
        eventListenerIdsByCallback = new WeakMap();
        clearRunCallbacks();
        if (moduleInstance && eventDispatchPtr !== 0) {
            moduleInstance.removeFunction?.(eventDispatchPtr);
            eventDispatchPtr = 0;
        }
        reqModule().ccall('rl_deinit', null, [], [], { async: true });
    },
    isInitialized: () => ccNum('rl_is_initialized') !== 0,
    getPlatform: () => ccStr('rl_get_platform'),
    getVersionMajor: () => moduleInstance ? ccNum('rl_version_major') : 0,
    getVersionMinor: () => moduleInstance ? ccNum('rl_version_minor') : 0,
    getVersionPatch: () => moduleInstance ? ccNum('rl_version_patch') : 1,
    versionLabel: () => moduleInstance ? ccStr('rl_version_label') : 'dev',
    getVersionNumber: () => moduleInstance ? ccNum('rl_version_number') >>> 0 : 1,
    getVersionString: () => moduleInstance ? ccStr('rl_version_string') : '0.0.1-dev',
    tick: () => {
        reqModule().ccall('rl_scratch_refresh', null, [], []);
        return ccNum('rl_tick');
    },
    getDeltaTime: () => ccNum('rl_get_delta_time'),
    setTargetFPS: (fps: number) => reqModule().ccall(
        "rl_set_target_fps", null, ["number"], [fps]
    ),
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
    HANDLE_KIND_NONE: 0,
    HANDLE_KIND_COLOR: 1,
    HANDLE_KIND_CAMERA3D: 2,
    HANDLE_KIND_FONT: 3,
    HANDLE_KIND_TEXTURE: 4,
    HANDLE_KIND_SPRITE2D: 5,
    HANDLE_KIND_SPRITE3D: 6,
    HANDLE_KIND_MODEL: 7,
    HANDLE_KIND_MODEL_ASSET: 8,
    HANDLE_KIND_SOUND: 9,
    HANDLE_KIND_MUSIC: 10,
    HANDLE_KIND_TEXT2D: 11,
    HANDLE_KIND_SCENE: 12,
    HANDLE_KIND_SHAPE: 13,
    HANDLE_KIND_ASSET_TASK: 32,
};

const fs = {
    remove: (filename) => {
        return ccNum('rl_fs_remove', ['string'], [filename]);
    },
    clear: () => {
        return ccNum('rl_fs_clear', [], []);
    },
    init: async (rootDir = "") => {
        return await ccNum('rl_fs_init', ['string'], [rootDir || ""], { async: true });
    },
    initAsync: (rootDir = "") => {
        return ccNum('rl_fs_init_async', ['string'], [rootDir || ""]);
    },
    deinitAsync: () => {
        return ccNum('rl_fs_deinit_async', [], []) >>> 0;
    },
    deinit: async () => {
        reqModule().ccall('rl_fs_deinit', null, [], [], { async: true });
    },
    isInitialized: () => {
        return ccNum('rl_fs_is_initialized', [], []) !== 0;
    },
    isReady: () => {
        return ccNum('rl_fs_is_ready', [], []) !== 0;
    },
    flush: () => {
        return ccNum('rl_fs_flush', [], []) | 0;
    },
    getRootDir: () => {
        return ccStr('rl_fs_get_root_dir', [], []);
    },
    normalizePath: (path) => {
        if (path == null) {
            return "";
        }
        const bufferSize = 4096;
        const bufferPtr = mallocOrThrow(bufferSize);
        try {
            reqModule().ccall(
                'rl_fs_normalize_path',
                null,
                ['string', 'number', 'number'],
                [String(path), bufferPtr, bufferSize]
            );
            if (typeof reqModule().UTF8ToString === "function") {
                return reqModule().UTF8ToString(bufferPtr);
            }
            return "";
        } finally {
            freeIfPossible(bufferPtr);
        }
    },
    restoreAsync: () => {
        return ccNum('rl_fs_restore_async', [], []);
    },
    read: (filename) => {
        if (!moduleInstance) {
            return null;
        }
        const stackSave = reqModule().stackSave;
        const stackRestore = reqModule().stackRestore;
        const stackAlloc = reqModule().stackAlloc;
        const heapU32 = reqModule().HEAPU32;
        const heapU8 = reqModule().HEAPU8;
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
            const rc = ccNum('rl_fs_read', ['string', 'number', 'number'], [name, outDataSlot, outSizeSlot]) | 0;
            const dataPtr = heapU32[outDataSlot >>> 2] >>> 0;
            const size = heapU32[outSizeSlot >>> 2] >>> 0;
            if (rc !== 0 || !dataPtr) {
                if (dataPtr) {
                    reqModule().ccall('rl_fs_read_free', null, ['number'], [dataPtr]);
                }
                return null;
            }
            const out = new Uint8Array(size);
            if (size > 0) {
                out.set(heapU8.subarray(dataPtr, dataPtr + size));
            }
            reqModule().ccall('rl_fs_read_free', null, ['number'], [dataPtr]);
            return out;
        } finally {
            stackRestore(prevSp);
        }
    },
    write: (path, data) => {
        if (typeof data === "string") {
            data = new TextEncoder().encode(data);
        }
        const ptr = mallocOrThrow(data.byteLength);
        try {
            reqModule().HEAPU8.set(new Uint8Array(data.buffer, data.byteOffset, data.byteLength), ptr);
            return ccNum('rl_fs_write', ['string', 'number', 'number'], [path, ptr, data.byteLength]) | 0;
        } finally {
            freeIfPossible(ptr);
        }
    },
    mkdir: (path) => {
        return ccNum('rl_fs_mkdir', ['string'], [path]) | 0;
    },
    rmdir: (path) => {
        return ccNum('rl_fs_rmdir', ['string'], [path]) | 0;
    },
    exists: (filename) => {
        return ccNum('rl_fs_exists', ['string'], [filename]) !== 0;
    }
} satisfies RLFs;

const asset = {
    ADD_TASK_OK: 0,
    ADD_TASK_ERR_INVALID: -1,
    ADD_TASK_ERR_QUEUE_FULL: -2,
    pingHost: (assetHost = "") => {
        return ccNum('rl_asset_ping_host', ['string'], [assetHost || ""]);
    },
    setHost: (assetHost) => {
        if (typeof assetHost !== "string") {
            return -1;
        }
        return ccNum('rl_asset_set_host', ['string'], [assetHost]) | 0;
    },
    getHost: () => {
        return ccStr('rl_asset_get_host', [], []);
    },
    ensure: async (localPath, src = null) => {
        if (typeof localPath === "string" && /\.gltf(?:[?#].*)?$/i.test(localPath)) {
            console.warn(
                `[librl] asset.ensure("${localPath}") does not currently follow .gltf dependencies. ` +
                `Use asset.ensureAsync(), rl.helpers.waitForAssetEnsureAsync(), or rl.helpers.createTaskGroup() instead.`
            );
        }
        return await ccNum('rl_asset_ensure', ['string', 'string'], [localPath, src ?? null], { async: true });
    },
    ensureAsync: (localPath, src = null) => {
        return ccNum('rl_asset_ensure_async', ['string', 'string'], [localPath, src ?? null]);
    },
    ensureGroupAsync: (filenames) => {
        const count = reqModule().writeScratchStringTable(filenames);
        return ccNum('rl_asset_ensure_many_from_scratch_async', ['number'], [count]);
    },
    pollTask: (task) => {
        return ccNum('rl_asset_poll_task', ['number'], [task]) !== 0;
    },
    finishTask: (task) => {
        return ccNum('rl_asset_finish_task', ['number'], [task]);
    },
    getTaskPath: (task) => {
        return ccStr('rl_asset_get_task_path', ['number'], [task]);
    },
    freeTask: (task) => {
        return reqModule().ccall('rl_asset_free_task', null, ['number'], [task]);
    },
    addTask: (task: RLHandle, onSuccess: RLAssetTaskCallback | null = null, onFailure: RLAssetTaskCallback | null = null, ctx: unknown = null) => {
        let successPtr = 0;
        let failurePtr = 0;
        let cleanedUp = false;
        const cleanup = () => {
            if (cleanedUp || !moduleInstance) {
                return;
            }
            cleanedUp = true;
            if (successPtr) {
                reqModule().removeFunction?.(successPtr);
                successPtr = 0;
            }
            if (failurePtr) {
                reqModule().removeFunction?.(failurePtr);
                failurePtr = 0;
            }
        };
        const decodePath = (pathPtr: number) => {
            if (!pathPtr) {
                return "";
            }
            if (typeof reqModule().UTF8ToString === "function") {
                return reqModule().UTF8ToString(pathPtr >>> 0);
            }
            console.error("UTF8ToString runtime method is unavailable; cannot decode loader callback path");
            return "";
        };

        // Mirror the cpp binding's rl_asset_add_task behavior with local JS
        // springboards. The closures capture the provided callbacks/context, so
        // we do not need a separate userdata registry on the JS side.
        successPtr = reqModule().addFunction((pathPtr: unknown, _userData: unknown) => {
            try {
                if (typeof onSuccess === "function") {
                    onSuccess(decodePath(pathPtr as number), ctx);
                }
            } finally {
                cleanup();
            }
        }, "vii");
        failurePtr = reqModule().addFunction((pathPtr: unknown, _userData: unknown) => {
            try {
                if (typeof onFailure === "function") {
                    onFailure(decodePath(pathPtr as number), ctx);
                }
            } finally {
                cleanup();
            }
        }, "vii");

        try {
            const rc = ccNum('rl_asset_add_task', ['number', 'number', 'number', 'number'], [task, successPtr, failurePtr, 0]);
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
        reqModule().ccall('rl_asset_tick', null, [], []);
    }
} satisfies RLAsset;

const event = {
    emit: (eventName, payload = 0) => {
        return ccNum('rl_event_emit', ['string', 'number'], [eventName, payload]);
    },
    on: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        ensureEventDispatchPtr();
        if (eventDispatchPtr === 0) {
            return -1;
        }

        callbackMap = eventListenerIdsByCallback.get(callback);
        if (!callbackMap) {
            callbackMap = new Map();
            eventListenerIdsByCallback.set(callback, callbackMap);
        }

        if (callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = nextEventListenerId++;
        rc = ccNum('rl_event_on', ['string', 'number', 'number'], [eventName, eventDispatchPtr, listenerId]);
        if (rc !== 0) {
            return rc;
        }

        callbackMap.set(eventName, listenerId);
        eventListenersById.set(listenerId, { eventName, callback });
        return 0;
    },
    once: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        ensureEventDispatchPtr();
        if (eventDispatchPtr === 0) {
            return -1;
        }

        callbackMap = eventListenerIdsByCallback.get(callback);
        if (!callbackMap) {
            callbackMap = new Map();
            eventListenerIdsByCallback.set(callback, callbackMap);
        }

        if (callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = nextEventListenerId++;
        rc = ccNum('rl_event_once', ['string', 'number', 'number'], [eventName, eventDispatchPtr, listenerId]);
        if (rc !== 0) {
            return rc;
        }

        callbackMap.set(eventName, listenerId);
        eventListenersById.set(listenerId, { eventName, callback });
        return 0;
    },
    off: (eventName, callback) => {
        let callbackMap = null;
        let listenerId = 0;
        let rc = 0;

        if (typeof eventName !== "string" || eventName.length === 0 || typeof callback !== "function") {
            return -1;
        }

        callbackMap = eventListenerIdsByCallback.get(callback);
        if (!callbackMap || !callbackMap.has(eventName)) {
            return 0;
        }

        listenerId = callbackMap.get(eventName);
        rc = ccNum('rl_event_off', ['string', 'number', 'number'], [eventName, eventDispatchPtr, listenerId]);
        if (rc === 0) {
            forgetListenerById(listenerId);
        }
        return rc;
    },
    clearListeners: (eventName) => {
        const rc = ccNum('rl_event_off_all', ['string'], [eventName]);
        if (rc === 0) {
            clearListenerCacheForEvent(eventName);
        }
        return rc;
    },
    getListenerCount: (eventName) => {
        return ccNum('rl_event_listener_count', ['string'], [eventName]);
    }
} satisfies RLEvent;

const window = {
    setSize: (width, height) => {
        return reqModule().ccall('rl_window_set_size', null, ['number', 'number'], [width, height]);
    },
    isCloseRequested: () => {
        return !!ccNum('rl_window_close_requested', [], []);
    },
    getMonitorCount: () => {
        return ccNum('rl_window_get_monitor_count', [], []);
    },
    setTitle: (title) => {
        return reqModule().ccall('rl_window_set_title', null, ['string'], [title]);
    },
    getCurrentMonitor: () => {
        return ccNum('rl_window_get_current_monitor', [], []);
    },
    setMonitor: (monitor) => {
        return reqModule().ccall('rl_window_set_monitor', null, ['number'], [monitor]);
    },
    getMonitorWidth: (monitor) => {
        return ccNum('rl_window_get_monitor_width', ['number'], [monitor]);
    },
    getMonitorHeight: (monitor) => {
        return ccNum('rl_window_get_monitor_height', ['number'], [monitor]);
    },
    setPosition: (x, y) => {
        return reqModule().ccall('rl_window_set_position', null, ['number', 'number'], [x, y]);
    },
    getScreenSize: () => {
        reqModule().ccall('rl_window_get_screen_size_to_scratch', null, [], []);
        return reqModule().getVector2();
    },
    getPosition: () => {
        reqModule().ccall('rl_window_get_position_to_scratch', null, [], []);
        return reqModule().getVector2();
    },
    getMonitorPosition: (monitor = 0) => {
        reqModule().ccall('rl_window_get_monitor_position_to_scratch', null, ['number'], [monitor]);
        return reqModule().getVector2();
    }
} satisfies RLWindow;

const render = {
    begin: () => {
        return reqModule().ccall('rl_render_begin', null, [], []);
    },
    end: () => {
        return reqModule().ccall('rl_render_end', null, [], []);
    },
    beginMode2D: (camera) => {
        return reqModule().ccall('rl_render_begin_mode_2d', null, ['number'], [camera]);
    },
    endMode2D: () => {
        return reqModule().ccall('rl_render_end_mode_2d', null, [], []);
    },
    beginMode3D: () => {
        return reqModule().ccall('rl_render_begin_mode_3d', null, [], []);
    },
    endMode3D: () => {
        return reqModule().ccall('rl_render_end_mode_3d', null, [], []);
    },
    clearBackground: (color) => {
        return reqModule().ccall('rl_render_clear_background', null, ['number'], [color]);
    },
    enableLighting: () => {
        return reqModule().ccall('rl_enable_lighting', null, [], []);
    },
    disableLighting: () => {
        return reqModule().ccall('rl_disable_lighting', null, [], []);
    },
    isLightingEnabled: () => {
        return ccNum('rl_is_lighting_enabled', [], []) !== 0;
    },
    setLightDirection: (x, y, z) => {
        return reqModule().ccall('rl_set_light_direction', null, ['number', 'number', 'number'], [x, y, z]);
    },
    setLightAmbient: (ambient) => {
        return reqModule().ccall('rl_set_light_ambient', null, ['number'], [ambient]);
    }
} satisfies RLRender;

const camera3d = {
    create: (
        positionX, positionY, positionZ,
        targetX, targetY, targetZ,
        upX, upY, upZ,
        fovy, projection
    ) => {
        return ccNum('rl_camera3d_create', ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'], [positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection]);
    },
    getDefault: () => {
        return ccNum('rl_camera3d_get_default', [], []);
    },
    set: (
        camera,
        positionX, positionY, positionZ,
        targetX, targetY, targetZ,
        upX, upY, upZ,
        fovy, projection
    ) => {
        return ccNum('rl_camera3d_set', ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'], [camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection]) !== 0;
    },
    setActive: (camera) => {
        return ccNum('rl_camera3d_set_active', ['number'], [camera]) !== 0;
    },
    getActive: () => {
        return ccNum('rl_camera3d_get_active', [], []);
    },
    destroy: (camera) => {
        return reqModule().ccall('rl_camera3d_destroy', null, ['number'], [camera]);
    }
} satisfies RLCamera3d;

const shape = {
    create: () => ccHandle("rl_shape_create"),
    destroy: (shapeHandle) => reqModule().ccall(
        "rl_shape_destroy", null, ["number"], [shapeHandle >>> 0]
    ),
    setVisible: (shapeHandle, visible) => reqModule().ccall(
        "rl_shape_set_visible", "number", ["number", "number"], [shapeHandle >>> 0, visible ? 1 : 0]
    ) !== 0,
    isVisible: (shapeHandle) => reqModule().ccall(
        "rl_shape_is_visible", "number", ["number"], [shapeHandle >>> 0]
    ) !== 0,
    setStrokeColor: (shapeHandle, color) => reqModule().ccall(
        "rl_shape_set_stroke_color", "number", ["number", "number"], [shapeHandle >>> 0, color >>> 0]
    ) !== 0,
    setLine3d: (shapeHandle, startX, startY, startZ, endX, endY, endZ) => reqModule().ccall(
        "rl_shape_set_line_3d",
        "number",
        ["number", "number", "number", "number", "number", "number", "number"],
        [shapeHandle >>> 0, startX, startY, startZ, endX, endY, endZ]
    ) !== 0,
    setLineStrip3d: (shapeHandle, points) => {
        const module = reqModule();
        const floats = points instanceof Float32Array ? points : new Float32Array(points);
        const numPoints = (floats.length / 3) | 0;
        const bytesNeeded = floats.length * 4;
        let ptr = 0;
        if (bytesNeeded > 0) {
            ptr = module._malloc(bytesNeeded);
            if (!ptr) throw new Error("Failed to allocate memory for retained line strip");
        }
        try {
            if (ptr) {
                module.HEAPF32.set(floats, ptr >> 2);
            }
            return module.ccall(
                "rl_shape_set_line_strip_3d",
                "number",
                ["number", "number", "number"],
                [shapeHandle >>> 0, ptr, numPoints]
            ) !== 0;
        } finally {
            if (ptr) {
                module._free(ptr);
            }
        }
    },
    draw: (shapeHandle) => {
        return reqModule().ccall(
            "rl_shape_draw",
            null,
            ["number"],
            [shapeHandle >>> 0]
        );
    },
    drawCube: (positionX, positionY, positionZ, width, height, length, color) => {
        return reqModule().ccall(
            'rl_shape_draw_cube',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [positionX, positionY, positionZ, width, height, length, color]
        );
    },
    drawCircle3d: (centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color) => {
        return reqModule().ccall(
            'rl_shape_draw_circle_3d',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color >>> 0]
        );
    },
    drawRectangle: (x, y, width, height, color) => {
        return reqModule().ccall(
            'rl_shape_draw_rectangle',
            null,
            ['number', 'number', 'number', 'number', 'number'],
            [x | 0, y | 0, width | 0, height | 0, color >>> 0]
        );
    },
    drawLine3d: (startX, startY, startZ, endX, endY, endZ, color) => {
        return reqModule().ccall(
            'rl_shape_draw_line_3d',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [startX, startY, startZ, endX, endY, endZ, color >>> 0]
        );
    },
    drawLineStrip3d: (points, color) => {
        const module = reqModule();
        const numPoints = points.length / 3;
        const bytesNeeded = points.length * 4; // 4 bytes per float
        const ptr = module._malloc(bytesNeeded);
        if (!ptr) throw new Error('Failed to allocate memory for line strip');
        try {
            module.HEAPF32.set(points instanceof Float32Array ? points : new Float32Array(points), ptr >> 2);
            module.ccall(
                'rl_shape_draw_line_strip_3d',
                null,
                ['number', 'number', 'number'],
                [ptr, numPoints, color >>> 0]
            );
        } finally {
            module._free(ptr);
        }
    }
} satisfies RLShape;

const debug = {
    enableFps: (x, y, fontSize, font = 0) => {
        return reqModule().ccall(
            'rl_debug_enable_fps',
            null,
            ['number', 'number', 'number', 'number'],
            [x | 0, y | 0, fontSize | 0, font >>> 0]
        );
    },
    disableFps: () => {
        return reqModule().ccall('rl_debug_disable_fps', null, [], []);
    }
} satisfies RLDebug;

const text = {
    drawFps: (x, y) => {
        return reqModule().ccall('rl_text_draw_fps', null, ['number', 'number'], [x, y]);
    },
    drawFpsEx: (font, x, y, fontSize, color) => {
        reqModule().ccall('rl_text_draw_fps_ex', null, ['number', 'number', 'number', 'number', 'number'], [font, x, y, fontSize, color]);
    },
    draw: (text, x, y, fontSize, color) => {
        return reqModule().ccall('rl_text_draw', null, ['string', 'number', 'number', 'number', 'number'], [text, x, y, fontSize, color]);
    },
    drawEx: (font, text, x, y, fontSize, spacing, tint) => {
        return reqModule().ccall('rl_text_draw_ex', null, ['number', 'string', 'number', 'number', 'number', 'number', 'number'], [font, text, x, y, fontSize, spacing, tint]);
    },
    measure: (text, fontSize) => {
        return ccNum('rl_text_measure', ['string', 'number'], [text, fontSize]);
    },
    measureEx: (font, text, fontSize, spacing = 1) => {
        ccNum('rl_text_measure_ex_to_scratch', ['number', 'string', 'number', 'number'], [font, text, fontSize, spacing]);
        return reqModule().getVector2();
    },
    // End Scratch-backed wrappers
} satisfies RLText;

const texture = {
    getDefault: () => ccHandle("rl_texture_get_default"),
    create: (path: string) => ccHandle("rl_texture_create", ["string"], [path]),
    destroy: (texture: RLHandle) => reqModule().ccall(
        "rl_texture_destroy", null, ["number"], [texture]
    ),
    drawEx: (texture, x, y, scale, rotation, tint) => {
        return reqModule().ccall('rl_texture_draw_ex', null, ['number', 'number', 'number', 'number', 'number', 'number'], [texture, x, y, scale, rotation, tint]);
    },
    drawGround: (texture, positionX, positionY, positionZ, width, length, tint) => {
        return reqModule().ccall('rl_texture_draw_ground', null, ['number', 'number', 'number', 'number', 'number', 'number', 'number'], [texture, positionX, positionY, positionZ, width, length, tint]);
    }
} satisfies RLTexture;

const input = {
    pollEvents: () => {
        return reqModule().ccall('rl_input_poll_events', null, [], []);
    },
    captureCursor: () => {
        return reqModule().ccall('rl_input_capture_cursor', null, [], []);
    },
    releaseCursor: () => {
        return reqModule().ccall('rl_input_release_cursor', null, [], []);
    },
    getMouseWheel: () => {
        return ccNum('rl_input_get_mouse_wheel', [], []);
    },
    getMouseButton: (button) => {
        return ccNum('rl_input_get_mouse_button', ['number'], [button]);
    },

    // Begin Scratch-backed wrappers
    // The following are wrappers that use the global scratch area to reduce js->wasm/wasm->js boundry calls
    // They either read scratch directly or via a *_to_scratch bridge.
    // We provide a uniform calling so js isn't aware of the intermediate scratch area use, 
    // while desktop gets the return structure directly,
    getMouseState: () => {
        const mouse = reqModule().getMouseState();
        return {
            x: mouse.x,
            y: mouse.y,
            wheel: mouse.wheel,
            left: mouse.buttons[0],
            right: mouse.buttons[1],
            middle: mouse.buttons[2],
            buttons: mouse.buttons,
            dx: mouse.dx,
            dy: mouse.dy,
        };
    },
    getKeyboardState: (): RLKeyboardState =>
        reqModule().getKeyboard() as unknown as RLKeyboardState,
    getGamepads: (): RLGamepadState[] => {
        const mod = reqModule();
        if (typeof mod.getGamepads !== "function") {
            return [];
        }
        return mod.getGamepads() as RLGamepadState[];
    },
    getGamepad: (id: number): RLGamepadState | null => {
        const mod = reqModule();
        if (typeof mod.getGamepad !== "function") {
            return null;
        }
        return mod.getGamepad(id | 0) as RLGamepadState | null;
    },
    getTouchpoints: (): RLTouchpoint[] => {
        const mod = reqModule();
        if (typeof mod.getTouchpoints !== "function") {
            return [];
        }
        return mod.getTouchpoints() as RLTouchpoint[];
    },
    getTouchpoint: (id: number): RLTouchpoint | null => {
        const mod = reqModule();
        if (typeof mod.getTouchpoint !== "function") {
            return null;
        }
        return mod.getTouchpoint(id | 0) as RLTouchpoint | null;
    },
    getMousePosition: () => {
        const HEAP32 = reqModule().HEAP32;
        return {
            x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.x >> 2)],
            y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.y >> 2)],
        };
    },
    getMouseDelta: () => {
        const HEAP32 = reqModule().HEAP32;
        return {
            x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.dx >> 2)],
            y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.dy >> 2)],
        };
    }
} satisfies RLInput;

const color = {
    ...Object.fromEntries(RL_COLOR_NAMES.map((name) => [name, 0])) as RLColorPresets,
    create: (r: number, g: number, b: number, a: number) =>
        ccHandle("rl_color_create", ["number", "number", "number", "number"], [r, g, b, a]),
    destroy: (colorHandle: RLHandle) => reqModule().ccall(
        "rl_color_destroy", null, ["number"], [colorHandle]
    )
} satisfies RLColor;

const patchColorConstants = () => {
        if (!moduleInstance || !(moduleInstance.HEAPU32 || moduleInstance.HEAP32)) {
            return;
        }
        const heap = moduleInstance.HEAPU32 || moduleInstance.HEAP32;
        for (const name of RL_COLOR_NAMES) {
            const ptr = moduleInstance["_RL_COLOR_" + name] as number | undefined;
            if (ptr == null) continue;
            color[name] = heap[(ptr >>> 2)] >>> 0;
        }
    };

const font = {
    create: (path: string, fontSize: number) =>
        ccHandle("rl_font_create", ["string", "number"], [path, fontSize]),
    destroy: (font: RLHandle) => reqModule().ccall(
        "rl_font_destroy", null, ["number"], [font]
    ),
    getDefault: () => ccHandle("rl_font_get_default"),
} satisfies RLFont;

const model = {
    getDefaultAsset: () => ccHandle("rl_model_get_default_asset"),
    loadAsset: (path: string) => ccHandle("rl_model_load_asset", ["string"], [path]),
    destroyAsset: (asset: RLHandle) => reqModule().ccall(
        "rl_model_destroy_asset", null, ["number"], [asset]
    ),
    create: (asset: RLHandle) => ccHandle("rl_model_create", ["number"], [asset]),
    createFromFile: (path: string) => ccHandle("rl_model_create_from_file", ["string"], [path]),
    setAsset: (model, asset) => reqModule().ccall(
        "rl_model_set_asset", "number", ["number", "number"], [model, asset]
    ) !== 0,
    setTransform: (
        model,
        positionX, positionY, positionZ,
        rotationX, rotationY, rotationZ,
        scaleX, scaleY, scaleZ
    ) => reqModule().ccall(
        "rl_model_set_transform",
        "number",
        ["number", "number", "number", "number", "number", "number", "number", "number", "number", "number"],
        [model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ]
    ) !== 0,
    setVisible: (model, visible) => reqModule().ccall(
        "rl_model_set_visible", "number", ["number", "number"], [model, visible ? 1 : 0]
    ) !== 0,
    setPickable: (model, pickable) => reqModule().ccall(
        "rl_model_set_pickable", "number", ["number", "number"], [model, pickable ? 1 : 0]
    ) !== 0,
    isVisible: (model) => reqModule().ccall(
        "rl_model_is_visible", "number", ["number"], [model]
    ) !== 0,
    isPickable: (model) => reqModule().ccall(
        "rl_model_is_pickable", "number", ["number"], [model]
    ) !== 0,
    draw: (model) => reqModule().ccall(
        "rl_model_draw", null, ["number"], [model]
    ),
    isValid: (model) => reqModule().ccall(
        "rl_model_is_valid", "number", ["number"], [model]
    ) !== 0,
    isValidStrict: (model) => reqModule().ccall(
        "rl_model_is_valid_strict", "number", ["number"], [model]
    ) !== 0,
    getAnimationCount: (model: RLHandle) =>
        ccNum("rl_model_get_animation_count", ["number"], [model]),
    getAnimationFrameCount: (model: RLHandle, animationIndex: number) =>
        ccNum("rl_model_get_animation_frame_count", ["number", "number"], [model, animationIndex]),
    updateAnimation: (model, animationIndex, frame) => reqModule().ccall(
        "rl_model_update_animation", null, ["number", "number", "number"], [model, animationIndex, frame]
    ),
    setAnimation: (model, animationIndex) => reqModule().ccall(
        "rl_model_set_animation", "number", ["number", "number"], [model, animationIndex]
    ) !== 0,
    setAnimationSpeed: (model, speed) => reqModule().ccall(
        "rl_model_set_animation_speed", "number", ["number", "number"], [model, speed]
    ) !== 0,
    setAnimationLoop: (model, shouldLoop) => reqModule().ccall(
        "rl_model_set_animation_loop", "number", ["number", "number"], [model, shouldLoop ? 1 : 0]
    ) !== 0,
    setTint: (model, color = 0) => reqModule().ccall(
        "rl_model_set_tint", "number", ["number", "number"], [model, color]
    ) !== 0,
    animate: (model, deltaSeconds) => reqModule().ccall(
        "rl_model_animate", "number", ["number", "number"], [model, deltaSeconds]
    ) !== 0,
    destroy: (model) => reqModule().ccall(
        "rl_model_destroy", null, ["number"], [model]
    )
} satisfies RLModel;

const pick = {
    model: (camera, model, mouseX, mouseY) => {
        reqModule().ccall(
            "rl_pick_model_to_scratch",
            "number",
            ["number", "number", "number", "number"],
            [camera, model, mouseX, mouseY]
        );
        return reqModule().getPickResult();
    },
    sprite3d: (camera, sprite3d, mouseX, mouseY) => {
        reqModule().ccall(
            "rl_pick_sprite3d_to_scratch",
            "number",
            ["number", "number", "number", "number"],
            [camera, sprite3d, mouseX, mouseY]
        );
        return reqModule().getPickResult();
    },
    resetStats: () => {
        reqModule().ccall("rl_pick_reset_stats", null, [], []);
    }
} satisfies RLPick;

const scene = {
    create: () => ccHandle("rl_scene_create"),
    destroy: (sceneHandle) => reqModule().ccall(
        "rl_scene_destroy", null, ["number"], [sceneHandle]
    ),
    add: (sceneHandle, drawable, layer = 0) => reqModule().ccall(
        "rl_scene_add", "number", ["number", "number", "number"], [sceneHandle, drawable, layer]
    ) !== 0,
  setLayer: (sceneHandle, drawable, layer) => reqModule().ccall(
        "rl_scene_set_layer", "number", ["number", "number", "number"], [sceneHandle, drawable, layer]
    ) !== 0,
    remove: (sceneHandle, drawable) => reqModule().ccall(
        "rl_scene_remove", "number", ["number", "number"], [sceneHandle, drawable]
    ) !== 0,
    clear: (sceneHandle) => reqModule().ccall(
        "rl_scene_clear", null, ["number"], [sceneHandle]
    ),
    setActiveCamera: (sceneHandle, camera) => reqModule().ccall(
        "rl_scene_set_active_camera", null, ["number", "number"], [sceneHandle, camera]
    ),
    draw: (sceneHandle) => reqModule().ccall(
        "rl_scene_draw", null, ["number"], [sceneHandle]
    ),
    pick: (sceneHandle, camera, mouseX, mouseY) => {
        reqModule().ccall(
            "rl_scene_pick_to_scratch",
            "number",
            ["number", "number", "number", "number"],
            [sceneHandle, camera, mouseX, mouseY]
        );
        return reqModule().getPickResult();
    },
} satisfies RLScene;

const music = {
    create: (path: string) => ccHandle("rl_music_create", ["string"], [path]),
    destroy: (music) => reqModule().ccall(
        "rl_music_destroy", null, ["number"], [music]
    ),
    play: (music) => reqModule().ccall(
        "rl_music_play", "number", ["number"], [music]
    ) !== 0,
    pause: (music) => reqModule().ccall(
        "rl_music_pause", "number", ["number"], [music]
    ) !== 0,
    stop: (music) => reqModule().ccall(
        "rl_music_stop", "number", ["number"], [music]
    ) !== 0,
    setLoop: (music, shouldLoop) => reqModule().ccall(
        "rl_music_set_loop", "number", ["number", "number"], [music, shouldLoop ? 1 : 0]
    ) !== 0,
    setVolume: (music, volume) => reqModule().ccall(
        "rl_music_set_volume", "number", ["number", "number"], [music, volume]
    ) !== 0,
    isPlaying: (music) => reqModule().ccall(
        "rl_music_is_playing", "number", ["number"], [music]
    ) !== 0,
    update: (music) => reqModule().ccall(
        "rl_music_update", "number", ["number"], [music]
    ) !== 0,
    updateAll: () => reqModule().ccall(
        "rl_music_update_all", null, [], []
    )
} satisfies RLMusic;

const sound = {
    create: (path: string) => ccHandle("rl_sound_create", ["string"], [path]),
    destroy: (sound) => reqModule().ccall(
        "rl_sound_destroy", null, ["number"], [sound]
    ),
    play: (sound) => reqModule().ccall(
        "rl_sound_play", "number", ["number"], [sound]
    ) !== 0,
    pause: (sound) => reqModule().ccall(
        "rl_sound_pause", "number", ["number"], [sound]
    ) !== 0,
    resume: (sound) => reqModule().ccall(
        "rl_sound_resume", "number", ["number"], [sound]
    ) !== 0,
    stop: (sound) => reqModule().ccall(
        "rl_sound_stop", "number", ["number"], [sound]
    ) !== 0,
    setVolume: (sound, volume) => reqModule().ccall(
        "rl_sound_set_volume", "number", ["number", "number"], [sound, volume]
    ) !== 0,
    setPitch: (sound, pitch) => reqModule().ccall(
        "rl_sound_set_pitch", "number", ["number", "number"], [sound, pitch]
    ) !== 0,
    setPan: (sound, pan) => reqModule().ccall(
        "rl_sound_set_pan", "number", ["number", "number"], [sound, pan]
    ) !== 0,
    isPlaying: (sound) => reqModule().ccall(
        "rl_sound_is_playing", "number", ["number"], [sound]
    ) !== 0
} satisfies RLSound;

const sprite3d = {
    create: (texture: RLHandle) => ccHandle("rl_sprite3d_create", ["number"], [texture]),
    createFromFile: (path: string) => ccHandle("rl_sprite3d_create_from_file", ["string"], [path]),
    setTexture: (sprite, texture) => reqModule().ccall(
        "rl_sprite3d_set_texture", "number", ["number", "number"], [sprite, texture]
    ) !== 0,
    setTransform: (sprite, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ) => reqModule().ccall(
        "rl_sprite3d_set_transform", "number", ["number", "number", "number", "number", "number", "number", "number", "number", "number", "number"], [sprite, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ]
    ) !== 0,
    setSize: (sprite, size) => reqModule().ccall(
        "rl_sprite3d_set_size", "number", ["number", "number"], [sprite, size]
    ) !== 0,
    setFacing: (sprite, facing) => reqModule().ccall(
        "rl_sprite3d_set_facing", "number", ["number", "number"], [sprite, facing]
    ) !== 0,
    setVisible: (sprite, visible) => reqModule().ccall(
        "rl_sprite3d_set_visible", "number", ["number", "number"], [sprite, visible ? 1 : 0]
    ) !== 0,
    setPickable: (sprite, pickable) => reqModule().ccall(
        "rl_sprite3d_set_pickable", "number", ["number", "number"], [sprite, pickable ? 1 : 0]
    ) !== 0,
    isVisible: (sprite) => reqModule().ccall(
        "rl_sprite3d_is_visible", "number", ["number"], [sprite]
    ) !== 0,
    isPickable: (sprite) => reqModule().ccall(
        "rl_sprite3d_is_pickable", "number", ["number"], [sprite]
    ) !== 0,
    getDefaultTexture: () => ccHandle("rl_sprite3d_get_default_texture"),
    getTransform: (sprite) => {
        const stackSave = reqModule().stackSave;
        const stackRestore = reqModule().stackRestore;
        const stackAlloc = reqModule().stackAlloc;
        const heapF32 = reqModule().HEAPF32;
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
            const rotationXPtr = stackAlloc(4) >>> 0;
            const rotationYPtr = stackAlloc(4) >>> 0;
            const rotationZPtr = stackAlloc(4) >>> 0;
            const scaleXPtr = stackAlloc(4) >>> 0;
            const scaleYPtr = stackAlloc(4) >>> 0;
            const scaleZPtr = stackAlloc(4) >>> 0;
            const ok = reqModule().ccall(
                "rl_sprite3d_get_transform",
                "number",
                ["number", "number", "number", "number", "number", "number", "number", "number", "number", "number"],
                [sprite >>> 0, positionXPtr, positionYPtr, positionZPtr, rotationXPtr, rotationYPtr, rotationZPtr, scaleXPtr, scaleYPtr, scaleZPtr]
            ) !== 0;
            if (!ok) {
                return null;
            }
            return {
                positionX: heapF32[positionXPtr >> 2],
                positionY: heapF32[positionYPtr >> 2],
                positionZ: heapF32[positionZPtr >> 2],
                rotationX: heapF32[rotationXPtr >> 2],
                rotationY: heapF32[rotationYPtr >> 2],
                rotationZ: heapF32[rotationZPtr >> 2],
                scaleX: heapF32[scaleXPtr >> 2],
                scaleY: heapF32[scaleYPtr >> 2],
                scaleZ: heapF32[scaleZPtr >> 2],
            };
        } finally {
            stackRestore(prevSp);
        }
    },
    setTint: (sprite, color = 0) => reqModule().ccall(
        "rl_sprite3d_set_tint", "number", ["number", "number"], [sprite, color]
    ) !== 0,
    draw: (sprite) => reqModule().ccall(
        "rl_sprite3d_draw", null, ["number"], [sprite]
    ),
    destroy: (sprite) => reqModule().ccall(
        "rl_sprite3d_destroy", null, ["number"], [sprite]
    )
} satisfies RLSprite3d;

const sprite2d = {
    create: (texture: RLHandle) => ccHandle("rl_sprite2d_create", ["number"], [texture]),
    createFromFile: (path: string) => ccHandle("rl_sprite2d_create_from_file", ["string"], [path]),
    getDefaultTexture: () => ccHandle("rl_sprite2d_get_default_texture"),
    setTexture: (sprite, texture) => reqModule().ccall(
        "rl_sprite2d_set_texture", "number", ["number", "number"], [sprite, texture]
    ) !== 0,
    setTransform: (sprite, x, y, scale, rotation) => reqModule().ccall(
        "rl_sprite2d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, x, y, scale, rotation]
    ) !== 0,
    setVisible: (sprite, visible) => reqModule().ccall(
        "rl_sprite2d_set_visible", "number", ["number", "number"], [sprite, visible ? 1 : 0]
    ) !== 0,
    setPickable: (sprite, pickable) => reqModule().ccall(
        "rl_sprite2d_set_pickable", "number", ["number", "number"], [sprite, pickable ? 1 : 0]
    ) !== 0,
    isVisible: (sprite) => reqModule().ccall(
        "rl_sprite2d_is_visible", "number", ["number"], [sprite]
    ) !== 0,
    isPickable: (sprite) => reqModule().ccall(
        "rl_sprite2d_is_pickable", "number", ["number"], [sprite]
    ) !== 0,
    setTint: (sprite, color = 0) => reqModule().ccall(
        "rl_sprite2d_set_tint", "number", ["number", "number"], [sprite, color]
    ) !== 0,
    draw: (sprite) => reqModule().ccall(
        "rl_sprite2d_draw", null, ["number"], [sprite]
    ),
    destroy: (sprite) => reqModule().ccall(
        "rl_sprite2d_destroy", null, ["number"], [sprite]
    )
} satisfies RLSprite2d;

const text2d = {
    create: (font: RLHandle, size: number) => ccHandle("rl_text2d_create", ["number", "number"], [font, size]),
    setFont: (handle, font) => reqModule().ccall(
        "rl_text2d_set_font", null, ["number", "number"], [handle, font]
    ),
    setSize: (handle, size) => reqModule().ccall(
        "rl_text2d_set_size", null, ["number", "number"], [handle, size]
    ),
    setContent: (handle, content) => reqModule().ccall(
        "rl_text2d_set_content", null, ["number", "string"], [handle, content]
    ),
    setPosition: (handle, x, y) => reqModule().ccall(
        "rl_text2d_set_position", null, ["number", "number", "number"], [handle, x, y]
    ),
    setColor: (handle, color) => reqModule().ccall(
        "rl_text2d_set_color", null, ["number", "number"], [handle, color]
    ),
    setVisible: (handle, visible) => reqModule().ccall(
        "rl_text2d_set_visible", "number", ["number", "number"], [handle, visible ? 1 : 0]
    ) !== 0,
    setPickable: (handle, pickable) => reqModule().ccall(
        "rl_text2d_set_pickable", "number", ["number", "number"], [handle, pickable ? 1 : 0]
    ) !== 0,
    isVisible: (handle) => reqModule().ccall(
        "rl_text2d_is_visible", "number", ["number"], [handle]
    ) !== 0,
    isPickable: (handle) => reqModule().ccall(
        "rl_text2d_is_pickable", "number", ["number"], [handle]
    ) !== 0,
    draw: (handle) => reqModule().ccall(
        "rl_text2d_draw", null, ["number"], [handle]
    ),
    destroy: (handle) => reqModule().ccall(
        "rl_text2d_destroy", null, ["number"], [handle]
    )
} satisfies RLText2d;

const logger = {
    message: (level, message) => reqModule().ccall(
        "rl_logger_message", null, ["number", "string"], [level, String(message ?? "").replaceAll("%", "%%")]
    ),
    messageSource: (level, sourceFile, sourceLine, message) => reqModule().ccall(
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
    setLevel: (level) => reqModule().ccall(
        "rl_logger_set_level", null, ["number"], [level]
    )
} satisfies RLLogger;

async function waitForTask(task: RLHandle, pollMs = 16): Promise<number> {
    if (!task) {
        return -1;
    }

    while (!asset.pollTask(task)) {
        await new Promise((resolve) => setTimeout(resolve, pollMs));
    }

    const rc = asset.finishTask(task);
    asset.freeTask(task);
    return rc;
}

const helpers = {
    waitForFsReady: async (timeoutMs = 2000) => {
        const start = performance.now();
        while (performance.now() - start < timeoutMs) {
            if (fs.isReady()) {
                return true;
            }
            await new Promise((resolve) => setTimeout(resolve, 16));
        }
        return fs.isReady();
    },
    taskIsValid: (task) => {
        return task !== 0;
    },
    waitForTask,
    waitForFsRestoreAsync: async () => waitForTask(fs.restoreAsync()),
    waitForAssetEnsureAsync: async (filename: string, src: string | null = null) =>
        waitForTask(asset.ensureAsync(filename, src)),
    waitForAssetEnsureGroupAsync: async (filenames: string[]) =>
        waitForTask(asset.ensureGroupAsync(filenames)),
    createTaskGroup: <T = unknown>(
        onComplete: RLTaskGroupCallback<T> | null = null,
        onError: RLTaskGroupCallback<T> | null = null,
        ctx: T | null = null,
    ): RLTaskGroup<T> => {
        type TaskGroupEntry = {
            task: RLHandle;
            path: string;
            done: boolean;
            rc: number;
            onSuccess: RLTaskGroupTaskCallback<T> | null;
            onError: RLTaskGroupTaskCallback<T> | null;
        };
        const entries: TaskGroupEntry[] = [];
        const group = {
            entries,
            callbackContext: ctx,
            onCompleteCallback: typeof onComplete === "function" ? onComplete : null,
            onErrorCallback: typeof onError === "function" ? onError : null,
            terminalCallbackInvoked: false,
            failedCount: 0,
            completedCount: 0,
            addTask(task: RLHandle, onSuccess: RLTaskGroupTaskCallback<T> | null = null, onTaskError: RLTaskGroupTaskCallback<T> | null = null) {
                if (!task) {
                    return;
                }
                this.entries.push({
                    task,
                    path: asset.getTaskPath(task),
                    done: false,
                    rc: 1,
                    onSuccess: typeof onSuccess === "function" ? onSuccess : null,
                    onError: typeof onTaskError === "function" ? onTaskError : null,
                });
            },
            addImportTask(path: string, onSuccess: RLTaskGroupTaskCallback<T> | null = null, onTaskError: RLTaskGroupTaskCallback<T> | null = null) {
                this.addTask(asset.ensureAsync(path), onSuccess, onTaskError);
            },
            addImportTasks(paths: string[], onSuccess: RLTaskGroupTaskCallback<T> | null = null, onTaskError: RLTaskGroupTaskCallback<T> | null = null) {
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
                asset.tick();
                for (const entry of this.entries) {
                    if (entry.done) {
                        continue;
                    }
                    if (!asset.pollTask(entry.task)) {
                        continue;
                    }
                    entry.rc = asset.finishTask(entry.task);
                    asset.freeTask(entry.task);
                    entry.done = true;
                    this.completedCount += 1;
                    if (entry.rc !== 0) {
                        this.failedCount += 1;
                        if (entry.onError) {
                            entry.onError(entry.path, this.callbackContext as T);
                        }
                    } else if (entry.onSuccess) {
                        entry.onSuccess(entry.path, this.callbackContext as T);
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
                            this.onErrorCallback(this, this.callbackContext as T);
                        }
                    } else if (this.onCompleteCallback) {
                        this.onCompleteCallback(this, this.callbackContext as T);
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
        return group as RLTaskGroup<T>;
    },
    getScreenWidth: () => {
        return window.getScreenSize().x;
    },
    getScreenHeight: () => {
        return window.getScreenSize().y;
    },
    getPickStats: () => ({
            broadphaseTests: ccNum("rl_pick_get_broadphase_tests"),
            broadphaseRejects: ccNum("rl_pick_get_broadphase_rejects"),
            narrowphaseTests: ccNum("rl_pick_get_narrowphase_tests"),
            narrowphaseHits: ccNum("rl_pick_get_narrowphase_hits"),
        }),
} satisfies RLHelpers;

export const rl = {
    ...rlCore,
    fs, asset, event, window, render, camera3d, shape, debug, text, texture, input, color, font, model, pick, scene, music, sound, sprite3d, sprite2d, text2d, logger, helpers,
} satisfies RLApi;

export default rl;
