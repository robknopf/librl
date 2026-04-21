import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";
import { rl_texture_create } from "./rl_texture";

const rl_sprite2d_handles = new Set<number>();
let rl_sprite2d_resource_manager: ResourceManager = WorldResources;
interface rl_sprite2d_state_t {
  x: number;
  y: number;
  scale: number;
  rotation: number;
}
const rl_sprite2d_states = new Map<number, rl_sprite2d_state_t>();

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_sprite2d_resource_manager = resourceManager;
}

export async function rl_sprite2d_create(filename: string): Promise<number> {
  const handle = await rl_sprite2d_resource_manager.createResource({
    type: ResourceRequestType.CREATE_SPRITE2D,
    filename,
  });
  rl_sprite2d_handles.add(handle);
  rl_sprite2d_states.set(handle, {
    x: 0.0,
    y: 0.0,
    scale: 1.0,
    rotation: 0.0,
  });
  return handle;
}

export async function rl_sprite2d_create_from_texture(texture: number): Promise<number> {
  const handle = await rl_texture_create(`sprite2d-from-texture:${texture}`);
  rl_sprite2d_handles.add(handle);
  rl_sprite2d_states.set(handle, {
    x: 0.0,
    y: 0.0,
    scale: 1.0,
    rotation: 0.0,
  });
  return handle;
}

export function rl_sprite2d_set_transform(
  handle: number,
  x: number,
  y: number,
  scale: number,
  rotation: number,
): boolean {
  const frame_command_buffer = get_frame_command_buffer();
  const state = rl_sprite2d_states.get(handle);
  if (state == null) {
    return false;
  }

  state.x = x;
  state.y = y;
  state.scale = scale;
  state.rotation = rotation;
  if (frame_command_buffer != null) {
    rl_frame_commands_append(frame_command_buffer, {
      type: CommandType.SET_SPRITE2D_TRANSFORM,
      sprite: handle,
      x: state.x,
      y: state.y,
      scale: state.scale,
      rotation: state.rotation,
    });
  }

  return true;
}

export function rl_sprite2d_draw(
  handle: number,
  tint: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null || !rl_sprite2d_states.has(handle)) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_SPRITE2D,
    sprite: handle,
    tint,
  });
}

export async function rl_sprite2d_destroy(handle: number): Promise<void> {
  if (!rl_sprite2d_handles.has(handle)) {
    return;
  }

  rl_sprite2d_handles.delete(handle);
  rl_sprite2d_states.delete(handle);
  await rl_sprite2d_resource_manager.destroyResource(handle);
}
