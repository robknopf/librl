// Pre-defined handle constants that match librl's built-in resources
// Handles are created with RL_HANDLE_MAKE(index, generation)
// RL_HANDLE_MAKE(idx, gen) = ((gen << 16) | idx)
// So for generation 1: handle = (1 << 16) | index = 65536 + index

const RL_HANDLE_MAKE = (index: number, generation: number): number => {
  return (generation << 16) | index;
};

export const BUILTIN_HANDLES = {
  // Colors - from rl_color.c (all use generation 1)
  COLOR_DEFAULT: RL_HANDLE_MAKE(1, 1),      // 65537
  COLOR_LIGHTGRAY: RL_HANDLE_MAKE(2, 1),    // 65538
  COLOR_GRAY: RL_HANDLE_MAKE(3, 1),         // 65539
  COLOR_DARKGRAY: RL_HANDLE_MAKE(4, 1),     // 65540
  COLOR_YELLOW: RL_HANDLE_MAKE(5, 1),       // 65541
  COLOR_GOLD: RL_HANDLE_MAKE(6, 1),         // 65542
  COLOR_ORANGE: RL_HANDLE_MAKE(7, 1),       // 65543
  COLOR_PINK: RL_HANDLE_MAKE(8, 1),         // 65544
  COLOR_RED: RL_HANDLE_MAKE(9, 1),          // 65545
  COLOR_MAROON: RL_HANDLE_MAKE(10, 1),      // 65546
  COLOR_GREEN: RL_HANDLE_MAKE(11, 1),       // 65547
  COLOR_LIME: RL_HANDLE_MAKE(12, 1),        // 65548
  COLOR_DARKGREEN: RL_HANDLE_MAKE(13, 1),   // 65549
  COLOR_SKYBLUE: RL_HANDLE_MAKE(14, 1),     // 65550
  COLOR_BLUE: RL_HANDLE_MAKE(15, 1),        // 65551
  COLOR_DARKBLUE: RL_HANDLE_MAKE(16, 1),    // 65552
  COLOR_PURPLE: RL_HANDLE_MAKE(17, 1),      // 65553
  COLOR_VIOLET: RL_HANDLE_MAKE(18, 1),      // 65554
  COLOR_DARKPURPLE: RL_HANDLE_MAKE(19, 1),  // 65555
  COLOR_BEIGE: RL_HANDLE_MAKE(20, 1),       // 65556
  COLOR_BROWN: RL_HANDLE_MAKE(21, 1),       // 65557
  COLOR_DARKBROWN: RL_HANDLE_MAKE(22, 1),   // 65558
  COLOR_WHITE: RL_HANDLE_MAKE(23, 1),       // 65559
  COLOR_BLACK: RL_HANDLE_MAKE(24, 1),       // 65560
  COLOR_BLANK: RL_HANDLE_MAKE(25, 1),       // 65561
  COLOR_MAGENTA: RL_HANDLE_MAKE(26, 1),     // 65562
  COLOR_RAYWHITE: RL_HANDLE_MAKE(27, 1),    // 65563
  
  // Fonts - from rl_font.c (RL_FONT_DEFAULT_INDEX = 0, generation 1)
  FONT_DEFAULT: RL_HANDLE_MAKE(0, 1),       // 65536
} as const;

// Resource registry for dynamically created resources
// Maps string IDs to handles that will be created on the client
export class ResourceRegistry {
  private resources = new Map<string, number>();
  
  register(id: string, handle: number): void {
    this.resources.set(id, handle);
  }
  
  get(id: string): number | undefined {
    return this.resources.get(id);
  }
  
  has(id: string): boolean {
    return this.resources.has(id);
  }
  
  unregister(id: string): void {
    this.resources.delete(id);
  }
  
  clear(): void {
    this.resources.clear();
  }
}

// Helper to resolve a handle from either built-in or registry
export function resolveHandle(
  idOrHandle: string | number,
  registry?: ResourceRegistry
): number {
  if (typeof idOrHandle === "number") {
    return idOrHandle;
  }
  
  // Check built-in handles first
  const builtinKey = idOrHandle.toUpperCase() as keyof typeof BUILTIN_HANDLES;
  if (builtinKey in BUILTIN_HANDLES) {
    return BUILTIN_HANDLES[builtinKey];
  }
  
  // Check registry
  if (registry) {
    const handle = registry.get(idOrHandle);
    if (handle !== undefined) {
      return handle;
    }
  }
  
  // Default to 0 (invalid handle)
  console.warn(`[Handles] Unknown resource: ${idOrHandle}`);
  return 0;
}
