interface WebAssembly {
  Suspending?: new (module: WebAssembly.Module) => WebAssembly.Instance;
  promising?: <T extends (...args: never[]) => unknown>(fn: T) => T;
}
