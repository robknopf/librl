package rl;

/**
* Injects librl include path and link flags into the hxcpp build for the Haxe example.
 * Requires -D LIBRL_ROOT=/path/to/librl (set by the build command).
 * Emits a clear error if LIBRL_ROOT is missing.
 *
 * Supports both desktop (gcc) and WASM (emscripten) targets via conditional XML.
 */
@:buildXml('
  <files id="haxe">
    <error value="Missing LIBRL_ROOT (-D LIBRL_ROOT=/path/to/librl_root_directory)" unless="LIBRL_ROOT" />
    <echo value="LIBRL_ROOT: ${LIBRL_ROOT}" />
    <compilerflag value="-I${LIBRL_ROOT}/include" />
    <compilerflag value="-DPLATFORM_WEB" if="emscripten" />
    <compilerflag value="-Wno-incompatible-function-pointer-types" />
  </files>

  <!-- Desktop linking -->
  <target id="haxe" unless="emscripten">
    <lib name="${LIBRL_ROOT}/lib/librl.a" />
    <lib name="-lm" />
    <lib name="-lpthread" />
    <lib name="-ldl" />
    <lib name="-lX11" />
    <lib name="-lcurl" />
    <lib name="-lnghttp2" />
    <lib name="-lz" />
    <lib name="-lssl" />
    <lib name="-lcrypto" />
    
  </target>

  <!-- WASM linking -->
  <target id="haxe" if="emscripten">
    <lib name="${LIBRL_ROOT}/lib/librl.wasm.a" />
    <lib name="-lm" />
  </target>

  <!-- Override the emscripten exe linker with raylib/librl-specific flags -->
  <linker id="exe" exe="emcc" replace="true" if="emscripten">
    <flag value="-s" />
    <flag value="WASM=1" />
    <flag value="-s" />
    <flag value="USE_GLFW=3" />
    <flag value="-s" />
    <flag value="FETCH=1" />
    <flag value="-s" />
    <flag value="MIN_WEBGL_VERSION=2" />
    <flag value="-s" />
    <flag value="MAX_WEBGL_VERSION=2" />
    <flag value="-s" />
    <flag value="ALLOW_MEMORY_GROWTH=1" />
    <flag value="-s" />
    <flag value="INITIAL_MEMORY=67108864" />
    <flag value="-lidbfs.js" />
    <flag value="-s" />
    <flag value="MODULARIZE=1" />
    <flag value="-s" />
    <flag value="EXPORT_ES6=1" />
    <!-- browser_host.js / runner.js call Module.ccall(rt_boot|...) -->
    <flag value="-s" />
    <flag value="EXPORTED_RUNTIME_METHODS=[\'ccall\',\'cwrap\']" />
    
    <!--
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_rt_boot\',\'_rt_init\',\'_rt_tick\',\'_rt_shutdown\']" />
    -->
    
    <!-- hxcpp GC requires spill-pointers -->
    <flag value="--Wno-limited-postlink-optimizations" />
    <flag value="-s" />
    <flag value="BINARYEN_EXTRA_PASSES=&apos;--spill-pointers&apos;" />

    <!-- wasm exceptions for Haxe try/catch -->
    <flag value="-fwasm-exceptions" />

    <section unless="debug">
      <flag value="-O3"/>
    </section>
    <section if="debug">
      <flag value="-g"/>
    </section>

    <ext value="${HXCPP_LINK_EMSCRIPTEN_EXT}"/>
    <outflag value="-o "/>
  </linker>
  ')
@:keep
class InjectLibRL {}

@:emscripten

