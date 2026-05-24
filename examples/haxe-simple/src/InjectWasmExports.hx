package;

#if emscripten
/**
	Inject wasm link flags (JSPI, EXPORTED_FUNCTIONS) for `runtime_host.js`.

	Must be imported from the wasm entry module (e.g. `Main.hx`) so `@:buildXml` is applied.
**/
@:buildXml('
  <target id="haxe" if="emscripten">
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_rt_boot\',\'_rt_init\',\'_rt_load\',\'_rt_unload\',\'_rt_tick\',\'_rt_shutdown\']" />
    <flag value="-s" />
    <flag value="JSPI=1" />
    <flag value="-s" />
    <flag value="JSPI_EXPORTS=[\'rt_boot\',\'rt_init\',\'rt_tick\',\'rt_shutdown\']" />
  </target>
')
@:keep
class InjectWasmExports {}

#end