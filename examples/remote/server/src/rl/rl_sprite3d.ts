import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";
import { rl_texture_create } from "./rl_texture";

const rl_sprite3d_handles = new Set<number>();
let rl_sprite3d_resource_manager: ResourceManager = WorldResources;
interface rl_sprite3d_state_t {
  position_x: number;
  position_y: number;
  position_z: number;
  size: number;
}
const rl_sprite3d_states = new Map<number, rl_sprite3d_state_t>();

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_sprite3d_resource_manager = resourceManager;
}

export async function rl_sprite3d_create(filename: string): Promise<number> {
  const handle = await rl_sprite3d_resource_manager.createResource({
    type: ResourceRequestType.CREATE_SPRITE3D,
    filename,
  });
  rl_sprite3d_handles.add(handle);
  rl_sprite3d_states.set(handle, {
    position_x: 0.0,
    position_y: 0.0,
    position_z: 0.0,
    size: 1.0,
  });
  return handle;
}

export async function rl_sprite3d_create_from_texture(texture: number): Promise<number> {
  const handle = await rl_texture_create(`sprite3d-from-texture:${texture}`);
  rl_sprite3d_handles.add(handle);
  rl_sprite3d_states.set(handle, {
    position_x: 0.0,
    position_y: 0.0,
    position_z: 0.0,
    size: 1.0,
  });
  return handle;
}

export function rl_sprite3d_set_transform(
  handle: number,
  position_x: number,
  position_y: number,
  position_z: number,
  size: number,
): boolean {
  const frame_command_buffer = get_frame_command_buffer();
  const state = rl_sprite3d_states.get(handle);
  if (state == null) {
    return false;
  }

  state.position_x = position_x;
  state.position_y = position_y;
  state.position_z = position_z;
  state.size = size;
  if (frame_command_buffer != null) {
    rl_frame_commands_append(frame_command_buffer, {
      type: CommandType.SET_SPRITE3D_TRANSFORM,
      sprite: handle,
      positionX: state.position_x,
      positionY: state.position_y,
      positionZ: state.position_z,
      size: state.size,
    });
  }

  return true;
}

export function rl_sprite3d_draw(
  handle: number,
  tint: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null || !rl_sprite3d_states.has(handle)) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_SPRITE3D,
    sprite: handle,
    tint,
  });
}

export async function rl_sprite3d_destroy(handle: number): Promise<void> {
  if (!rl_sprite3d_handles.has(handle)) {
    return;
  }

  rl_sprite3d_handles.delete(handle);
  rl_sprite3d_states.delete(handle);
  await rl_sprite3d_resource_manager.destroyResource(handle);
}
