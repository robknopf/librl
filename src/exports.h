#ifndef EXPORTS_H
#define EXPORTS_H

#ifdef PLATFORM_WEB
    #include <emscripten.h>
    #define RL_KEEP EMSCRIPTEN_KEEPALIVE
    #define RL_ASYNC EMSCRIPTEN_ASYNCIFY
#else // empty stubs
    #define RL_KEEP
    #define RL_ASYNC
#endif

#endif // EXPORTS_H