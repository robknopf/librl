import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";

const rl_color_handles = new Set<number>();
let rl_color_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_color_resource_manager = resourceManager;
}

export async function rl_color_create(r: number, g: number, b: number, a: number): Promise<number> {
  const handle = await rl_color_resource_manager.createResource({
    type: ResourceRequestType.CREATE_COLOR,
    r,
    g,
    b,
    a,
  });
  rl_color_handles.add(handle);
  return handle;
}

export async function rl_color_destroy(handle: number): Promise<void> {
  if (!rl_color_handles.has(handle)) {
    return;
  }

  rl_color_handles.delete(handle);
  await rl_color_resource_manager.destroyResource(handle);
}
