package tests.bindings.haxe;

/**
 * Injects librl include path and link flags into the hxcpp build.
 * Requires -D LIBRL_ROOT=/path/to/librl (set by Makefile).
 */
@:buildXml("
  <files id='haxe'>
    <compilerflag value='-I${LIBRL_ROOT}/include' />
  </files>
  <target id='haxe'>
    <lib name='${LIBRL_ROOT}/lib/librl.a' />
    <lib name='-lm' />
    <lib name='-lpthread' />
    <lib name='-ldl' />
    <lib name='-lX11' />
    <lib name='-lcurl' />
  </target>
")
class BuildLibrl {}
