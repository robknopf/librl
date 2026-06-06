package rl;

/**
 * Injects librl include path and link flags into the hxcpp build.
 *
 * In-repo examples: `-D LIBRL_ROOT=...` and pre-built `lib/librl.a` / `lib/librl.wasm.a`.
 * With `-lib librl-hx`: includes `project/Build.xml` (compile from submodule source).
 */
@:buildXml('
  <include name="${haxelib:librl-hx}/project/Build.xml" if="librl_hx" />

  <section unless="librl_hx">
    <files id="haxe">
      <error value="Missing LIBRL_ROOT (-D LIBRL_ROOT=/path/to/librl_root_directory)" unless="LIBRL_ROOT" />
      <echo value="LIBRL_ROOT: ${LIBRL_ROOT}" />
      <compilerflag value="-I${LIBRL_ROOT}/include" />
      <compilerflag value="-I${WGUTILS_ROOT}/include" if="WGUTILS_ROOT"/>
	    <compilerflag value="-I${LIBRL_ROOT}/deps/wgutils/include" unless="WGUTILS_ROOT" />
      <compilerflag value="-DPLATFORM_WEB" if="emscripten" />
      <compilerflag value="-Wno-incompatible-function-pointer-types" />
    </files>

    <!-- emscripten compile flags -->
    <compiler id="emscripten" exe="emcc">
    <!-- supress some warnings that emcc has from hxcpp generated code -->
      <cppflag value="-Wno-inconsistent-missing-override" />
      <cppflag value="-Wno-overflow" />
      <cppflag value="-Wno-nontrivial-memcall" />
    </compiler>

    <!-- Desktop linking -->
    <target id="haxe" unless="emscripten||static_link">
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
      <lib name="-lrt" />
      <lib name="-lGL" />
      <lib name="-lX11" />
      <lib name="-lXrandr" />
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
      <!-- Project-local examples decide which app/runtime functions to export. -->
      <flag value="-s" />
      <flag value="EXPORTED_RUNTIME_METHODS=[\'ccall\',\'cwrap\']" />

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
  </section>
  ')
@:keep
class InjectLibRL {}
