import { _rt_boot, _rt_init, _rt_tick, _rt_shutdown } from "../out/js/testjs.js";

_rt_boot();
_rt_init();
_rt_tick(0.016);
_rt_shutdown();
