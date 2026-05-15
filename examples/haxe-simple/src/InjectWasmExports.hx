package;

#if emscripten
/**
	Inject wasm exports as the runtime ABI for hosts.

	The `rt_*` symbols are a host/runtime contract for this example, not librl (although they are common to the runtime contract)
**/
@:buildXml('
  <target id="haxe" if="emscripten">
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_rt_boot\',\'_rt_init\',\'_rt_tick\',\'_rt_shutdown\']" />
    <flag value="-s" />
    <flag value="JSPI=1" />
    <flag value="-s" />
    <flag value="JSPI_EXPORTS=[\'rt_boot\',\'rt_init\',\'rt_tick\',\'rt_shutdown\']" />
  </target>
')
@:keep
class InjectWasmExports {}

#end