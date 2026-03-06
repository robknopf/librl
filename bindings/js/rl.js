// appended to emscripten build with --extern-post-js bindings/js/rl.js
var moduleInstance;
var moduleOptions = {};

const RL = {
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

        // IDBFS restore is async in wasm init; wait briefly so first asset loads
        // can hit local cache instead of racing into remote fetch.
        await RL.waitForIdbfsReady(2000);

     
      
    },
    update: () => {
        moduleInstance.ccall('rl_update', null, [], []);
    },
    getTime: () => {
        return moduleInstance.ccall('rl_get_time', 'number', [], []);
    },
    deinit: () => {
        moduleInstance.ccall('rl_deinit', null, [], []);
    },

    initWindow: (width, height, title) => {

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
                "rl_set_window_size",
                null,
                ["number", "number"],
                [newWidth, newHeight]
            );
        });


        moduleInstance.ccall('rl_init_window', null, ['number', 'number', 'string'], [width, height, title]);
        // force an initial resize event
        window.dispatchEvent(new Event('resize'));
    },
    closeWindow: () => {
        return moduleInstance.ccall('rl_close_window', null, [], []);
    },
    setWindowSize: (width, height) => {
        return moduleInstance.ccall('rl_set_window_size', null, ['number', 'number'], [width, height]);
    },
    getScreenWidth: () => {
        return moduleInstance.ccall('rl_get_screen_width', 'number', [], []);
    },
    getScreenHeight: () => {
        return moduleInstance.ccall('rl_get_screen_height', 'number', [], []);
    },
    setWindowPosition: (x, y) => {
        return moduleInstance.ccall('rl_get_window_position', null, ['number', 'number'], [x, y]);
    },
    getWindowPosition: () => {
        moduleInstance.ccall('rl_get_window_position', 'number', [], []);
        // get the vector2 result from the scratch area
        return moduleInstance.getVector2();
    },
    beginDrawing: () => {
        return moduleInstance.ccall('rl_begin_drawing', null, [], []);
    },
    endDrawing: () => {
        return moduleInstance.ccall('rl_end_drawing', null, [], []);
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
        return moduleInstance.ccall('rl_clear_background', null, ['number'], [color]);
    },
    drawCube: (positionX, positionY, positionZ, width, height, length, color) => {
        return moduleInstance.ccall(
            'rl_draw_cube',
            null,
            ['number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [positionX, positionY, positionZ, width, height, length, color]
        );
    },
    getMouseState: () => {
        // get the mouse position from the scratch area, it should be updated by the library every frame
        return moduleInstance.getMouseState();
    },
    getKeyboard: () => {
        // get the mouse position from the scratch area, it should be updated by the library every frame
        return moduleInstance.getKeyboard();
    },
    drawFPS: (x, y) => {
        return moduleInstance.ccall('rl_draw_fps', null, ['number', 'number'], [x, y]);
    },
    drawFPSEx: (font, x, y, fontSize, color) => {
        moduleInstance.ccall('rl_draw_fps_ex', null, ['number', 'number', 'number', 'number', 'number'], [font, x, y, fontSize, color]);
    },
    drawText: (text, x, y, fontSize, color) => {
        return moduleInstance.ccall('rl_draw_text', null, ['string', 'number', 'number', 'number', 'number'], [text, x, y, fontSize, color]);
    },
    drawTextEx: (font, text, x, y, fontSize, spacing, tint) => {
        return moduleInstance.ccall('rl_draw_text_ex', null, ['number', 'string', 'number', 'number', 'number', 'number', 'number'], [font, text, x, y, fontSize, spacing, tint]);
    },
    measureText: (text, fontSize) => {
        return moduleInstance.ccall('rl_measure_text', 'number', ['string', 'number'], [text, fontSize]);
    },
    measureTextEx: (font, text, fontSize, spacing = 1) => {
        moduleInstance.ccall('rl_measure_text_ex', 'number', ['number', 'string', 'number', 'number'], [font, text, fontSize, spacing]);
        return moduleInstance.getVector2();
    },
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
        "rl_set_target_fps", null, ["number"], [fps]
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
