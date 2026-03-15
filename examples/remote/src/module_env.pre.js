if (Module['env']) {
  Module['preRun'] = Module['preRun'] || [];
  Module['preRun'].push(function () {
    for (var key in Module['env']) {
      if (Object.prototype.hasOwnProperty.call(Module['env'], key)) {
        ENV[key] = Module['env'][key];
      }
    }
  });
}
