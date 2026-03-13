// appended to emscripten build with --extern-post-js bindings/js/rl.js
var moduleInstance;
var moduleOptions = {};

const RL = {
    _eventDispatchPtr: 0,
    _nextEventListenerId: 1,
    _eventListenersById: new Map(),
    _eventListenerIdsByCallback: new WeakMap(),
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
    init: async (opts) => {
        let resolvedAssetHost = "";
        opts = opts || {};
        opts.env = opts.env || {};
        moduleOptions = {...opts};
        moduleOptions.env = {...opts.env};

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

        moduleInstance.initScratchArea();

        if (typeof opts.assetHost === "string" && opts.assetHost.trim().length > 0) {
            resolvedAssetHost = opts.assetHost.trim();
        } else if (typeof window !== "undefined" && window.location && window.location.origin) {
            resolvedAssetHost = window.location.origin;
        }
        if (resolvedAssetHost.length > 0) {
            const setHostResult = moduleInstance.ccall(
                "rl_set_asset_host",
                "number",
                ["string"],
                [resolvedAssetHost]
            );
            if (setHostResult !== 0) {
                throw new Error("Failed to set asset host.");
            }
        }

        moduleInstance.ccall('rl_init', null, [], []);
    },
    update: () => {
        moduleInstance.ccall('rl_update_to_scratch', null, [], []);
    },
    getTime: () => {
        return moduleInstance.ccall('rl_frame_get_time', 'number', [], []);
    },
    deinit: () => {
        RL._eventListenersById.clear();
        RL._eventListenerIdsByCallback = new WeakMap();
        if (moduleInstance && RL._eventDispatchPtr !== 0) {
            moduleInstance.removeFunction(RL._eventDispatchPtr);
            RL._eventDispatchPtr = 0;
        }
        moduleInstance.ccall('rl_deinit', null, [], []);
    },
    uncacheFile: (filename) => {
        return moduleInstance.ccall('rl_loader_uncache_file', 'number', ['string'], [filename]);
    },
    clearCache: () => {
        return moduleInstance.ccall('rl_loader_clear_cache', 'number', [], []);
    },
    beginRestore: () => {
        return moduleInstance.ccall('rl_loader_begin_restore', 'number', [], []);
    },
    beginPrepareFile: (filename) => {
        return moduleInstance.ccall('rl_loader_begin_prepare_file', 'number', ['string'], [filename]);
    },
    beginPrepareModel: (filename) => {
        return moduleInstance.ccall('rl_loader_begin_prepare_model', 'number', ['string'], [filename]);
    },
    beginPreparePaths: (filenames) => {
        const count = moduleInstance.writeScratchStringTable(filenames);
        return moduleInstance.ccall('rl_loader_begin_prepare_paths_from_scratch', 'number', ['number'], [count]);
    },
    pollLoaderOp: (op) => {
        return moduleInstance.ccall('rl_loader_poll_op', 'number', ['number'], [op]) !== 0;
    },
    finishLoaderOp: (op) => {
        return moduleInstance.ccall('rl_loader_finish_op', 'number', ['number'], [op]);
    },
    freeLoaderOp: (op) => {
        return moduleInstance.ccall('rl_loader_free_op', null, ['number'], [op]);
    },
    isLocalFile: (filename) => {
        return moduleInstance.ccall('rl_loader_is_local', 'number', ['string'], [filename]) !== 0;
    },
    waitForLoaderOp: async (op, pollMs = 16) => {
        let rc = 0;

        if (!op) {
            return -1;
        }

        while (!RL.pollLoaderOp(op)) {
            await new Promise((resolve) => setTimeout(resolve, pollMs));
        }

        rc = RL.finishLoaderOp(op);
        RL.freeLoaderOp(op);
        return rc;
    },
    restore: async () => {
        return RL.waitForLoaderOp(RL.beginRestore());
    },
    prepareFile: async (filename) => {
        return RL.waitForLoaderOp(RL.beginPrepareFile(filename));
    },
    prepareModel: async (filename) => {
        return RL.waitForLoaderOp(RL.beginPrepareModel(filename));
    },
    preparePaths: async (filenames) => {
        return RL.waitForLoaderOp(RL.beginPreparePaths(filenames));
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

    initWindow: (width, height, title, flags = 0) => {
        let windowFlags = Number.isInteger(flags) ? flags : 0;

        // we default to keeping the canvas the same aspect ratio as the ideal dimensions
        var idealWidth = moduleOptions.idealWidth || 1024;
        var idealHeight = moduleOptions.idealHeight || 1280;
        var aspectRatio = idealWidth / idealHeight;

        window.addEventListener('resize', (_event) => {
            const windowWidth = window.innerWidth;
            const windowHeight = window.innerHeight;

            let newWidth, newHeight;
            if (windowWidth / windowHeight > aspectRatio) {
                newHeight = windowHeight;
                newWidth = windowHeight * aspectRatio;
            } else {
                newWidth = windowWidth;
                newHeight = windowWidth / aspectRatio;
            }

            //console.log("resize", newWidth, newHeight);

            moduleInstance.ccall(
                "rl_window_set_size",
                null,
                ["number", "number"],
                [newWidth, newHeight]
            );
        });


        moduleInstance.ccall('rl_window_init', null, ['number', 'number', 'string', 'number'], [width, height, title, windowFlags]);
        // force an initial resize event
        window.dispatchEvent(new Event('resize'));
    },
    closeWindow: () => {
        return moduleInstance.ccall('rl_window_close', null, [], []);
    },
    setWindowSize: (width, height) => {
        return moduleInstance.ccall('rl_window_set_size', null, ['number', 'number'], [width, height]);
    },
    setWindowPosition: (x, y) => {
        return moduleInstance.ccall('rl_window_set_position', null, ['number', 'number'], [x, y]);
    },
    beginDrawing: () => {
        return moduleInstance.ccall('rl_frame_begin', null, [], []);
    },
    endDrawing: () => {
        return moduleInstance.ccall('rl_frame_end', null, [], []);
    },
    beginMode3D: () => {
        return moduleInstance.ccall('rl_begin_mode_3d', null, [], []);
    },
    endMode3D: () => {
        return moduleInstance.ccall('rl_end_mode_3d', null, [], []);
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
        return moduleInstance.ccall('rl_frame_clear_background', null, ['number'], [color]);
    },
    drawCube: (positionX, positionY, positionZ, width, height, length, color) => {
        return moduleInstance.ccall(
            'rl_draw_cube',
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

    //color: {
        // Predefined Colors
        DEFAULT: 0,
        LIGHTGRAY: 1,
        GRAY: 2,
        DARKGRAY: 3,
        YELLOW: 4,
        GOLD: 5,
        ORANGE: 6,
        PINK: 7,
        RED: 8,
        MAROON: 9,
        GREEN: 10,
        LIME: 11,
        DARKGREEN: 12,
        SKYBLUE: 13,
        BLUE: 14,
        DARKBLUE: 15,
        PURPLE: 16,
        VIOLET: 17,
        DARKPURPLE: 18,
        BEIGE: 19,
        BROWN: 20,
        DARKBROWN: 21,
        WHITE: 22,
        BLACK: 23,
        BLANK: 24,
        MAGENTA: 25,
        RAYWHITE: 26,
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
        "rl_font_create", "number", ["string", "number"], [path, fontSize], { async: true } // async: true, it uses fetch
    ),
    destroyFont: (font) => moduleInstance.ccall(
        "rl_font_destroy", null, ["number"], [font]
    ),
    rl_font_get_default: () => moduleInstance.ccall(
        "rl_font_get_default", "number", [], []
    ),
    setTargetFPS: (fps) => moduleInstance.ccall(
        "rl_frame_runner_set_target_fps", null, ["number"], [fps]
    ),
    createModel: (path) => moduleInstance.ccall(
        "rl_model_create", "number", ["string"], [path], { async: true } // async: true, it uses fetch
    ),
    drawModel: (model, x, y, z, scale, tint) => moduleInstance.ccall(
        "rl_model_draw", null, ["number", "number", "number", "number", "number", "number"], [model, x, y, z, scale, tint]
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
    createMusic: (path) => moduleInstance.ccall(
        "rl_music_create", "number", ["string"], [path], { async: true }
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
        "rl_sound_create", "number", ["string"], [path], { async: true }
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
        "rl_texture_create", "number", ["string"], [path], { async: true }
    ),
    destroyTexture: (texture) => moduleInstance.ccall(
        "rl_texture_destroy", null, ["number"], [texture]
    ),
    createSprite3D: (path) => moduleInstance.ccall(
        "rl_sprite3d_create", "number", ["string"], [path], { async: true }
    ),
    createSprite3DFromTexture: (texture) => moduleInstance.ccall(
        "rl_sprite3d_create_from_texture", "number", ["number"], [texture]
    ),
    drawSprite3D: (sprite, x, y, z, size, tint) => moduleInstance.ccall(
        "rl_sprite3d_draw", null, ["number", "number", "number", "number", "number", "number"], [sprite, x, y, z, size, tint]
    ),
    destroySprite3D: (sprite) => moduleInstance.ccall(
        "rl_sprite3d_destroy", null, ["number"], [sprite]
    ),

}
