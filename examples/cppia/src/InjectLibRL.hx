package;
/**
 * Injects librl include path and link flags into the hxcpp build for the cppia host example.
 * Reuses the same LIBRL_ROOT convention as the main Haxe example.
 */
@:buildXml('
  <files id="haxe">
    <error value="Missing LIBRL_ROOT (-D LIBRL_ROOT=/path/to/librl_root_directory)" unless="LIBRL_ROOT" />
    <echo value="LIBRL_ROOT: ${LIBRL_ROOT}" />
    <compilerflag value="-I${LIBRL_ROOT}/include" />
  </files>
  <target id="haxe">
    <lib name="${LIBRL_ROOT}/lib/librl.a" />
    <lib name="-lm" />
    <lib name="-lpthread" />
    <lib name="-ldl" />
    <lib name="-lX11" />
    <lib name="-lcurl" />
  </target>
')
@:keep
class InjectLibRL {}

