import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";

const rl_font_handles = new Set<number>();
export const RL_FONT_DEFAULT = 0;
let rl_font_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_font_resource_manager = resourceManager;
}

export async function rl_font_create(filename: string, font_size: number): Promise<number> {
  const handle = await rl_font_resource_manager.createResource({
    type: ResourceRequestType.CREATE_FONT,
    filename,
    fontSize: font_size,
  });
  rl_font_handles.add(handle);
  return handle;
}

export async function rl_font_destroy(handle: number): Promise<void> {
  if (!rl_font_handles.has(handle)) {
    return;
  }

  rl_font_handles.delete(handle);
  await rl_font_resource_manager.destroyResource(handle);
}

export function rl_font_get_default(): number {
  return RL_FONT_DEFAULT;
}
