import { ResourceRequestType } from "../resource_protocol";
import { SharedResourceManager } from "../resource_manager";

const rl_color_handles = new Set<number>();

export async function rl_color_create(r: number, g: number, b: number, a: number): Promise<number> {
  const handle = await SharedResourceManager.createResource({
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
  await SharedResourceManager.destroyResource(handle);
}
