import { ResourceRequestType } from "../resource_protocol";
import { SharedResourceManager } from "../resource_manager";

const rl_music_handles = new Set<number>();

export async function rl_music_create(filename: string): Promise<number> {
  const handle = await SharedResourceManager.createResource({
    type: ResourceRequestType.CREATE_MUSIC,
    filename,
  });
  rl_music_handles.add(handle);
  return handle;
}

export async function rl_music_destroy(handle: number): Promise<void> {
  if (!rl_music_handles.has(handle)) {
    return;
  }

  rl_music_handles.delete(handle);
  await SharedResourceManager.destroyResource(handle);
}
