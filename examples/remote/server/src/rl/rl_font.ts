import { ResourceRequestType } from "../resource_protocol";
import { SharedResourceManager } from "../resource_manager";

const rl_font_handles = new Set<number>();
export const RL_FONT_DEFAULT = 0;

export async function rl_font_create(filename: string, font_size: number): Promise<number> {
  const handle = await SharedResourceManager.createResource({
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
  await SharedResourceManager.destroyResource(handle);
}

export function rl_font_get_default(): number {
  return RL_FONT_DEFAULT;
}
