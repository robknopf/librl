package;

/**
	local wasm exports for the browser launcher.
**/
@:buildXml('
  <target id="haxe" if="emscripten">
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_rt_boot\',\'_rt_init\',\'_rt_tick\',\'_rt_shutdown\',\'_rt_load\',\'_rt_unload\']" />
    <flag value="-s" />
    <flag value="JSPI=1" />
    <flag value="-s" />
    <flag value="JSPI_EXPORTS=[\'rt_boot\',\'rt_init\',\'rt_tick\',\'rt_shutdown\',\'rt_load\',\'rt_unload\']" />
  </target>
')
@:keep
class WasmExports {}

