import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

const rl_texture_handles = new Set<number>();
let rl_texture_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_texture_resource_manager = resourceManager;
}

export async function rl_texture_create(filename: string): Promise<number> {
  const handle = await rl_texture_resource_manager.createResource({
    type: ResourceRequestType.CREATE_TEXTURE,
    filename,
  });
  rl_texture_handles.add(handle);
  return handle;
}

export async function rl_texture_destroy(handle: number): Promise<void> {
  if (!rl_texture_handles.has(handle)) {
    return;
  }

  rl_texture_handles.delete(handle);
  await rl_texture_resource_manager.destroyResource(handle);
}

export function rl_texture_draw_ex(
  texture: number,
  x: number,
  y: number,
  scale: number,
  rotation: number,
  tint: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_TEXTURE,
    texture,
    tint,
    x,
    y,
    scale,
    rotation,
  });
}

export function rl_texture_draw_ground(
  texture: number,
  position_x: number,
  position_y: number,
  position_z: number,
  width: number,
  length: number,
  tint: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_GROUND_TEXTURE,
    texture,
    tint,
    x: position_x,
    y: position_y,
    z: position_z,
    width,
    length,
  });
}
