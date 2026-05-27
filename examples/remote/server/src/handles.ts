// Pre-defined handle constants that match librl's built-in resources
// Layout (MSB → LSB): kind (6) | generation (10) | index (16)
// RL_HANDLE_MAKE(kind, index, generation)

const RL_KIND_COLOR = 1;
const RL_KIND_CAMERA3D = 2;
const RL_KIND_FONT = 3;

const RL_HANDLE_MAKE = (kind: number, index: number, generation: number): number => {
  return ((kind & 0x3f) << 26) | ((generation & 0x3ff) << 16) | (index & 0xffff);
};

export const BUILTIN_HANDLES = {
  // Colors - from rl_color.c (all use generation 1, kind RL_KIND_COLOR)
  COLOR_DEFAULT: RL_HANDLE_MAKE(RL_KIND_COLOR, 1, 1),
  COLOR_LIGHTGRAY: RL_HANDLE_MAKE(RL_KIND_COLOR, 2, 1),
  COLOR_GRAY: RL_HANDLE_MAKE(RL_KIND_COLOR, 3, 1),
  COLOR_DARKGRAY: RL_HANDLE_MAKE(RL_KIND_COLOR, 4, 1),
  COLOR_YELLOW: RL_HANDLE_MAKE(RL_KIND_COLOR, 5, 1),
  COLOR_GOLD: RL_HANDLE_MAKE(RL_KIND_COLOR, 6, 1),
  COLOR_ORANGE: RL_HANDLE_MAKE(RL_KIND_COLOR, 7, 1),
  COLOR_PINK: RL_HANDLE_MAKE(RL_KIND_COLOR, 8, 1),
  COLOR_RED: RL_HANDLE_MAKE(RL_KIND_COLOR, 9, 1),
  COLOR_MAROON: RL_HANDLE_MAKE(RL_KIND_COLOR, 10, 1),
  COLOR_GREEN: RL_HANDLE_MAKE(RL_KIND_COLOR, 11, 1),
  COLOR_LIME: RL_HANDLE_MAKE(RL_KIND_COLOR, 12, 1),
  COLOR_DARKGREEN: RL_HANDLE_MAKE(RL_KIND_COLOR, 13, 1),
  COLOR_SKYBLUE: RL_HANDLE_MAKE(RL_KIND_COLOR, 14, 1),
  COLOR_BLUE: RL_HANDLE_MAKE(RL_KIND_COLOR, 15, 1),
  COLOR_DARKBLUE: RL_HANDLE_MAKE(RL_KIND_COLOR, 16, 1),
  COLOR_PURPLE: RL_HANDLE_MAKE(RL_KIND_COLOR, 17, 1),
  COLOR_VIOLET: RL_HANDLE_MAKE(RL_KIND_COLOR, 18, 1),
  COLOR_DARKPURPLE: RL_HANDLE_MAKE(RL_KIND_COLOR, 19, 1),
  COLOR_BEIGE: RL_HANDLE_MAKE(RL_KIND_COLOR, 20, 1),
  COLOR_BROWN: RL_HANDLE_MAKE(RL_KIND_COLOR, 21, 1),
  COLOR_DARKBROWN: RL_HANDLE_MAKE(RL_KIND_COLOR, 22, 1),
  COLOR_WHITE: RL_HANDLE_MAKE(RL_KIND_COLOR, 23, 1),
  COLOR_BLACK: RL_HANDLE_MAKE(RL_KIND_COLOR, 24, 1),
  COLOR_BLANK: RL_HANDLE_MAKE(RL_KIND_COLOR, 25, 1),
  COLOR_MAGENTA: RL_HANDLE_MAKE(RL_KIND_COLOR, 26, 1),
  COLOR_RAYWHITE: RL_HANDLE_MAKE(RL_KIND_COLOR, 27, 1),

  // Fonts - from rl_font.c (index 1, generation 1)
  FONT_DEFAULT: RL_HANDLE_MAKE(RL_KIND_FONT, 1, 1),

  // Cameras - from rl_camera3d.c (index 1, generation 1)
  CAMERA3D_DEFAULT: RL_HANDLE_MAKE(RL_KIND_CAMERA3D, 1, 1),
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
