import { _rt_boot, _rt_init, _rt_tick, _rt_shutdown } from "../out/js/testjs.js";

await _rt_boot();
await _rt_init();
_rt_tick(0.016);
await _rt_shutdown();
