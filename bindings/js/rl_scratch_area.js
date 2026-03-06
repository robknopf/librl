

//function getRLScratchAreaWrapper(Module) {

//console.log("getRLScratchAreaWrapper", Module);


// Cache references to WebAssembly memory
//const HEAP32 = Module.HEAP32;
//const HEAPF32 = Module.HEAPF32;

var scratchAreaPtr = 0;
var scratchAreaOffsets = {};

Module.initScratchArea = () => {

    // Fetch scratch area pointer and offsets pointer (called once during initialization)
    scratchAreaPtr = Module.ccall("rl_scratch_area_get", "number", [], []) >> 2; // Convert to 32-bit index
    const scratchAreaOffsetsPtr = Module.ccall("rl_scratch_area_get_offsets", "number", [], []) >> 2; // Convert to 32-bit index


    // Precompute offsets (static throughout the application lifecycle)
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
            last_key: HEAP32[scratchAreaOffsetsPtr + 13],
            last_char: HEAP32[scratchAreaOffsetsPtr + 14],
        },
        gamepads: {
            max_num_gamepads: HEAP32[scratchAreaOffsetsPtr + 15],
            gamepad: HEAP32[scratchAreaOffsetsPtr + 16],
            id: HEAP32[scratchAreaOffsetsPtr + 17],
            axis: HEAP32[scratchAreaOffsetsPtr + 18],
            buttons: HEAP32[scratchAreaOffsetsPtr + 19],
            stride: HEAP32[scratchAreaOffsetsPtr + 20] >> 2, // Convert stride to 32-bit units
        },
        touchpoints: {
            count: HEAP32[scratchAreaOffsetsPtr + 21],
            touchpoint: HEAP32[scratchAreaOffsetsPtr + 22],
            id: HEAP32[scratchAreaOffsetsPtr + 23],
            x: HEAP32[scratchAreaOffsetsPtr + 24],
            y: HEAP32[scratchAreaOffsetsPtr + 25],
            stride: HEAP32[scratchAreaOffsetsPtr + 26] >> 2, // Convert stride to 32-bit units
        },
    };
};


//const scratchAreaWrapper = {
//Module.scratchArea = {
// General-purpose fields
Module.getVector2 = () => ({
    x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector2 >> 2)],
    y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector2 >> 2) + 1],
});

Module.getVector3 = () => ({
    x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2)],
    y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2) + 1],
    z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector3 >> 2) + 2],
});

Module.getVector4 = () => ({
    x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2)],
    y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 1],
    z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 2],
    w: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.vector4 >> 2) + 3],
});

Module.getMatrix = () => {
    const matrixOffset = scratchAreaPtr + (scratchAreaOffsets.matrix >> 2);
    return HEAPF32.subarray(matrixOffset, matrixOffset + 16); // 4x4 matrix
};

Module.getQuaternion = () => ({
    x: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2)],
    y: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 1],
    z: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 2],
    w: HEAPF32[scratchAreaPtr + (scratchAreaOffsets.quaternion >> 2) + 3],
});

Module.getColor = () => ({
    r: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2)],
    g: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 1],
    b: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 2],
    a: HEAP32[scratchAreaPtr + (scratchAreaOffsets.color >> 2) + 3],
});

Module.getRectangle = () => ({
    x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2)],
    y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 1],
    width: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 2],
    height: HEAP32[scratchAreaPtr + (scratchAreaOffsets.rectangle >> 2) + 3],
});

// input fields
Module.getMouseState = () => ({
    x: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.x >> 2)],
    y: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.y >> 2)],
    wheel: HEAP32[scratchAreaPtr + (scratchAreaOffsets.mouse.wheel >> 2)],
    buttons: HEAP32.subarray(
        scratchAreaPtr + (scratchAreaOffsets.mouse.buttons >> 2),
        scratchAreaPtr + (scratchAreaOffsets.mouse.buttons >> 2) + 3
    ),
});

Module.getKeyboard = () => ({
    max_num_keys: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.max_num_keys >> 2)],
    keys: HEAP32.subarray(
        scratchAreaPtr + (scratchAreaOffsets.keyboard.keys >> 2),
        scratchAreaPtr + (scratchAreaOffsets.keyboard.keys >> 2) +
        HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.max_num_keys >> 2)]
    ),
    last_key: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.last_key >> 2)],
    last_char: HEAP32[scratchAreaPtr + (scratchAreaOffsets.keyboard.last_char >> 2)],
});

Module.getGamepads = () => {
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
}
//}
//return scratchAreaWrapper;

