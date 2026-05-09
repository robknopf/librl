# Haxe Runtime ABI Example

This preserves the host/runtime ABI experiment for Haxe.

The `rt_boot`, `rt_init`, `rt_tick`, and `rt_shutdown` exports are not librl APIs.
They are an embedding contract between a host and a runtime module. The ABI macro
used to generate hxcpp C exports lives in this example so the concept does not
bleed into the librl Haxe binding.
