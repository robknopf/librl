// appended to emscripten build with --extern-post-js bindings/js/rl.js
var moduleInstance;
var moduleOptions = {};

const RL = {
    _eventDispatchPtr: 0,
    _nextEventListenerId: 1,
    _eventListenersById: new Map(),
    _eventListenerIdsByCallback: new WeakMap(),
    _runInitPtr: 0,
    _runTickPtr: 0,
    _runShutdownPtr: 0,
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
        if (!moduleInstance) {
            return;
        }
        if (RL._runInitPtr !== 0) {
            moduleInstance.removeFunction(RL._runInitPtr);
            RL._runInitPtr = 0;
        }
        if (RL._runTickPtr !== 0) {
            moduleInstance.removeFunction(RL._runTickPtr);
            RL._runTickPtr = 0;
        }
        if (RL._runShutdownPtr !== 0) {
            moduleInstance.removeFunction(RL._runShutdownPtr);
            RL._runShutdownPtr = 0;
        }
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
    init: async (opts) => {
        opts = opts || {};
        opts.env = opts.env || {};
        moduleOptions = {...opts};
        moduleOptions.env = {...opts.env};

        if (moduleOptions.idealWidth == null) {
            moduleOptions.idealWidth = moduleOptions.windowWidth;
        }
        if (moduleOptions.idealHeight == null) {
            moduleOptions.idealHeight = moduleOptions.windowHeight;
        }

        // set up env for the Module
        if (!moduleOptions.env.canvas) {
            moduleOptions.env.canvas = document.getElementById('renderCanvas');
        }
        if (!moduleOptions.env.print) {
            var output = document.getElementById('output');
            if (!output) {
                const output = document.createElement("textarea");
                output.id = "output";
                output.style.width = "100%";
                output.style.height = "100px";
                document.body.appendChild(output);
            }

            moduleOptions.env.print = function () {
                var e = document.getElementById("output");
                return e && (e.value = ""), function (n) {
                    arguments.length > 1 && (n = Array.prototype.slice.call(arguments).join(" ")), console.log(n), e && (e.value += n + "\n", e.scrollTop = e.scrollHeight)
                }
            }();
        }

        // create an instance of the module
        moduleInstance = await Module(moduleOptions.env);

        RL._patchColorConstants();

        moduleInstance.initScratchArea();

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
            setI32(0, (moduleOptions.windowWidth || 0) | 0);
            setI32(4, (moduleOptions.windowHeight || 0) | 0);

            const titlePtr = stringToTempUtf8OrNull(moduleOptions.windowTitle);
            const assetPtr = stringToTempUtf8OrNull(moduleOptions.assetHost);
            const cachePtr = stringToTempUtf8OrNull(moduleOptions.loaderCacheDir);
            allocatedPtrs.push(titlePtr, assetPtr, cachePtr);

            setI32(8, titlePtr >>> 0);
            setI32(12, (moduleOptions.windowFlags || 0) >>> 0);
            setI32(16, assetPtr >>> 0);
            setI32(20, cachePtr >>> 0);

            initRc = moduleInstance.ccall("rl_init", "number", ["number"], [cfgPtr]) | 0;
        } finally {
            if (useHeapAlloc) {
                for (const ptr of allocatedPtrs) {
                    freeTemp(ptr);
                }
            } else if (canUseStack) {
                moduleInstance.stackRestore(stackTop);
            }
        }

        if (initRc !== 0) {
            return initRc;
        }

        RL._installWebResizeHandler(moduleOptions);
        if (typeof window !== "undefined" && window.dispatchEvent) {
            window.dispatchEvent(new Event("resize"));
        }
        return 0;
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
    update: () => {
        moduleInstance.ccall('rl_update_to_scratch', null, [], []);
    },
    getTime: () => {
        return moduleInstance.ccall('rl_get_time', 'number', [], []);
    },
    deinit: () => {
        RL._eventListenersById.clear();
        RL._eventListenerIdsByCallback = new WeakMap();
        RL._clearRunCallbacks();
        if (moduleInstance && RL._eventDispatchPtr !== 0) {
            moduleInstance.removeFunction(RL._eventDispatchPtr);
            RL._eventDispatchPtr = 0;
        }
        moduleInstance.ccall('rl_deinit', null, [], []);
    },
    isInitialized: () => {
        return moduleInstance.ccall('rl_is_initialized', 'number', [], []) !== 0;
    },
    getPlatform: () => {
        return moduleInstance.ccall('rl_get_platform', 'string', [], []);
    },
    uncacheFile: (filename) => {
        return moduleInstance.ccall('rl_loader_uncache_file', 'number', ['string'], [filename]);
    },
    clearCache: () => {
        return moduleInstance.ccall('rl_loader_clear_cache', 'number', [], []);
    },
    pingAssetHost: (assetHost = "") => {
        return moduleInstance.ccall(
            'rl_loader_ping_asset_host',
            'number',
            ['string'],
            [assetHost || ""]
        );
    },
    restoreFS: () => {
        return moduleInstance.ccall('rl_loader_restore_fs_async', 'number', [], []);
    },
    importAsset: (filename) => {
        return moduleInstance.ccall('rl_loader_create_import_task', 'number', ['string'], [filename]);
    },
    importAssets: (filenames) => {
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
    freeTask: (task) => {
        return moduleInstance.ccall('rl_loader_free_task', null, ['number'], [task]);
    },
    addTask: (task, path) => {
        return moduleInstance.ccall(
            'rl_loader_add_task',
            'number',
            ['number', 'string', 'number', 'number', 'number'],
            [task, path, 0, 0, 0]
        );
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
                this.addTask(RL.importAsset(path), onSuccess, onTaskError);
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
    isLocalFile: (filename) => {
        return moduleInstance.ccall('rl_loader_is_local', 'number', ['string'], [filename]) !== 0;
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
    restore: async () => {
        return RL.waitForTask(RL.restoreFS());
    },
    importAssetAsync: async (filename) => {
        return RL.waitForTask(RL.importAsset(filename));
    },
    importAssetsAsync: async (filenames) => {
        return RL.waitForTask(RL.importAssets(filenames));
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
    setWindowPosition: (x, y) => {
        return moduleInstance.ccall('rl_window_set_position', null, ['number', 'number'], [x, y]);
    },
    beginDrawing: () => {
        return moduleInstance.ccall('rl_render_begin', null, [], []);
    },
    endDrawing: () => {
        return moduleInstance.ccall('rl_render_end', null, [], []);
    },
    beginMode3D: () => {
        return moduleInstance.ccall('rl_render_begin_mode_3d', null, [], []);
    },
    endMode3D: () => {
        return moduleInstance.ccall('rl_render_end_mode_3d', null, [], []);
    },
    run: (init, tick, shutdown) => {
        if (typeof tick !== "function") {
            throw new Error("RL.run requires a tick callback.");
        }

        RL._clearRunCallbacks();

        RL._runInitPtr = typeof init === "function"
            ? moduleInstance.addFunction(() => init(), "vi")
            : 0;
        RL._runTickPtr = moduleInstance.addFunction(() => tick(), "vi");
        RL._runShutdownPtr = moduleInstance.addFunction(() => {
                try {
                    if (typeof shutdown === "function") {
                    shutdown();
                    }
                } finally {
                    RL._clearRunCallbacks();
                }
            }, "vi");

        return moduleInstance.ccall(
            'rl_run',
            null,
            ['number', 'number', 'number', 'number'],
            [RL._runInitPtr, RL._runTickPtr, RL._runShutdownPtr, 0]
        );
    },
    start: (init, tick, shutdown) => {
        if (typeof tick !== "function") {
            throw new Error("RL.start requires a tick callback.");
        }

        RL._clearRunCallbacks();

        RL._runInitPtr = typeof init === "function"
            ? moduleInstance.addFunction(() => init(), "vi")
            : 0;
        RL._runTickPtr = moduleInstance.addFunction(() => tick(), "vi");
        RL._runShutdownPtr = moduleInstance.addFunction(() => {
            try {
                if (typeof shutdown === "function") {
                    shutdown();
                }
            } finally {
                RL._clearRunCallbacks();
            }
        }, "vi");

        return moduleInstance.ccall(
            'rl_start',
            'number',
            ['number', 'number', 'number', 'number'],
            [RL._runInitPtr, RL._runTickPtr, RL._runShutdownPtr, 0]
        );
    },
    tick: () => {
        return moduleInstance.ccall('rl_tick', 'number', [], []);
    },
    stop: () => {
        return moduleInstance.ccall('rl_stop', null, [], []);
    },
    createCamera3D: (
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
    getDefaultCamera3D: () => {
        return moduleInstance.ccall('rl_camera3d_get_default', 'number', [], []);
    },
    setCamera3D: (
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
    setActiveCamera3D: (camera) => {
        return moduleInstance.ccall('rl_camera3d_set_active', 'number', ['number'], [camera]) !== 0;
    },
    getActiveCamera3D: () => {
        return moduleInstance.ccall('rl_camera3d_get_active', 'number', [], []);
    },
    destroyCamera3D: (camera) => {
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
    measureText: (text, fontSize) => {
        return moduleInstance.ccall('rl_text_measure', 'number', ['string', 'number'], [text, fontSize]);
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
    createFont: async (path, fontSize) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load font: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_font_create", "number", ["string", "number"], [path, fontSize]);
    },
    createFontFromLocal: (path, fontSize) => moduleInstance.ccall(
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
    createModel: async (path) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load model: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_model_create", "number", ["string"], [path]);
    },
    createModelFromLocal: (path) => moduleInstance.ccall(
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
    pickModel: (camera, model, mouseX, mouseY, x = 0, y = 0, z = 0, scale = 1) => {
        const hit = moduleInstance.ccall(
            "rl_pick_model_to_scratch",
            "number",
            ["number", "number", "number", "number", "number", "number", "number", "number"],
            [camera, model, mouseX, mouseY, x, y, z, scale]
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
    pickSprite3D: (camera, sprite3d, mouseX, mouseY, x = 0, y = 0, z = 0, size = 1) => {
        const hit = moduleInstance.ccall(
            "rl_pick_sprite3d_to_scratch",
            "number",
            ["number", "number", "number", "number", "number", "number", "number", "number"],
            [camera, sprite3d, mouseX, mouseY, x, y, z, size]
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
    createMusic: async (path) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load music: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_music_create", "number", ["string"], [path]);
    },
    createMusicFromLocal: (path) => moduleInstance.ccall(
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
    createSound: async (path) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load sound: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_sound_create", "number", ["string"], [path]);
    },
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
    createTexture: async (path) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load texture: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_texture_create", "number", ["string"], [path]);
    },
    destroyTexture: (texture) => moduleInstance.ccall(
        "rl_texture_destroy", null, ["number"], [texture]
    ),
    createSprite3D: async (path) => {
        const rc = await RL.importAssetAsync(path);
        if (rc !== 0) throw new Error(`Failed to load sprite3d: ${path} (rc=${rc})`);
        return moduleInstance.ccall("rl_sprite3d_create", "number", ["string"], [path]);
    },
    createSprite3DFromLocal: (path) => moduleInstance.ccall(
        "rl_sprite3d_create", "number", ["string"], [path]
    ),
    createSprite3DFromTexture: (texture) => moduleInstance.ccall(
        "rl_sprite3d_create_from_texture", "number", ["number"], [texture]
    ),
    sprite3DSetTransform: (sprite, positionX, positionY, positionZ, size) => moduleInstance.ccall(
        "rl_sprite3d_set_transform", "number", ["number", "number", "number", "number", "number"], [sprite, positionX, positionY, positionZ, size]
    ) !== 0,
    drawSprite3D: (sprite, tint) => moduleInstance.ccall(
        "rl_sprite3d_draw", null, ["number", "number"], [sprite, tint]
    ),
    destroySprite3D: (sprite) => moduleInstance.ccall(
        "rl_sprite3d_destroy", null, ["number"], [sprite]
    ),

}
