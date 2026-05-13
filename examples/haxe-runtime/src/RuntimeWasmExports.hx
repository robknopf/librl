package;

/**
	Example-local wasm exports for the host/runtime ABI experiment.

	The `rt_*` symbols are a host/runtime contract for this example, not librl
	binding exports.
**/
@:buildXml('
  <target id="haxe" if="emscripten">
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_rt_boot\',\'_rt_init\',\'_rt_tick\',\'_rt_shutdown\']" />
    <flag value="-s" />
    <flag value="JSPI=1" />
    <flag value="-s" />
    <flag value="JSPI_EXPORTS=[\'rt_init\',\'rt_tick\',\'rt_shutdown\']" />
  </target>
')
@:keep
class RuntimeWasmExports {}
