package;

/**
	Example-local wasm exports for the browser launcher.

	These are not librl binding exports; they are the small app ABI used by
	`examples/www/public/js/haxe_example.js` to schedule this example.
**/
@:buildXml('
  <target id="haxe" if="emscripten">
    <flag value="-s" />
    <flag value="EXPORTED_FUNCTIONS=[\'_main\',\'_example_init\',\'_example_frame\',\'_example_shutdown\']" />
    <flag value="-s" />
    <flag value="JSPI=1" />
    <flag value="-s" />
    <flag value="JSPI_EXPORTS=[\'example_init\',\'example_frame\',\'example_shutdown\']" />
  </target>
')
@:keep
class ExampleWasmExports {}
