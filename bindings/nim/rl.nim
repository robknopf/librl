import rl_async
export rl_async

when defined(js):
  include impl/rl_js
else:
  include impl/rl_native
