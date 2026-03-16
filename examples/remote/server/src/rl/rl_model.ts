import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

interface rl_model_state_t {
  position_x: number;
  position_y: number;
  position_z: number;
  rotation_x: number;
  rotation_y: number;
  rotation_z: number;
  scale_x: number;
  scale_y: number;
  scale_z: number;
  animation_index: number;
  animation_frame: number;
  animation_speed: number;
  animation_loop: boolean;
}

const rl_model_states = new Map<number, rl_model_state_t>();
let rl_model_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_model_resource_manager = resourceManager;
}

function get_model_state(handle: number): rl_model_state_t | null {
  return rl_model_states.get(handle) ?? null;
}

export async function rl_model_create(filename: string): Promise<number> {
  const handle = await rl_model_resource_manager.createResource({
    type: ResourceRequestType.CREATE_MODEL,
    filename,
  });
  rl_model_states.set(handle, {
    position_x: 0.0,
    position_y: 0.0,
    position_z: 0.0,
    rotation_x: 0.0,
    rotation_y: 0.0,
    rotation_z: 0.0,
    scale_x: 1.0,
    scale_y: 1.0,
    scale_z: 1.0,
    animation_index: -1,
    animation_frame: 0,
    animation_speed: 1.0,
    animation_loop: true,
  });
  return handle;
}

export function rl_model_set_transform(
  handle: number,
  position_x: number,
  position_y: number,
  position_z: number,
  rotation_x: number,
  rotation_y: number,
  rotation_z: number,
  scale_x: number,
  scale_y: number,
  scale_z: number,
): boolean {
  const state = get_model_state(handle);
  const current_frame_command_buffer = get_frame_command_buffer();

  if (state == null) {
    return false;
  }

  state.position_x = position_x;
  state.position_y = position_y;
  state.position_z = position_z;
  state.rotation_x = rotation_x;
  state.rotation_y = rotation_y;
  state.rotation_z = rotation_z;
  state.scale_x = scale_x;
  state.scale_y = scale_y;
  state.scale_z = scale_z;
  if (current_frame_command_buffer != null) {
    rl_frame_commands_append(current_frame_command_buffer, {
      type: CommandType.SET_MODEL_TRANSFORM,
      model: handle,
      positionX: state.position_x,
      positionY: state.position_y,
      positionZ: state.position_z,
      rotationX: state.rotation_x,
      rotationY: state.rotation_y,
      rotationZ: state.rotation_z,
      scaleX: state.scale_x,
      scaleY: state.scale_y,
      scaleZ: state.scale_z,
    });
  }

  return true;
}

export function rl_model_draw(
  handle: number,
  tint: number,
): void {
  const state = get_model_state(handle);

  if (state == null) {
    throw new Error(`Invalid model handle: ${handle}`);
  }

  const current_frame_command_buffer = get_frame_command_buffer();

  if (current_frame_command_buffer == null) {
    return;
  }

  rl_frame_commands_append(current_frame_command_buffer, {
    type: CommandType.DRAW_MODEL,
    model: handle,
    tint,
    animationIndex: state.animation_index,
    animationFrame: state.animation_frame,
  });
}

export function rl_model_is_valid(handle: number): boolean {
  return rl_model_states.has(handle);
}

export function rl_model_is_valid_strict(handle: number): boolean {
  return rl_model_is_valid(handle);
}

export function rl_model_animation_count(handle: number): number {
  return rl_model_is_valid(handle) ? 1 : 0;
}

export function rl_model_animation_frame_count(handle: number, animation_index: number): number {
  if (!rl_model_is_valid(handle) || animation_index < 0) {
    return 0;
  }

  return 60;
}

export function rl_model_animation_update(handle: number, animation_index: number, frame: number): void {
  const state = get_model_state(handle);

  if (state == null) {
    return;
  }

  state.animation_index = animation_index;
  state.animation_frame = frame;
}

export function rl_model_set_animation(handle: number, animation_index: number): boolean {
  const state = get_model_state(handle);

  if (state == null) {
    return false;
  }

  state.animation_index = animation_index;
  return true;
}

export function rl_model_set_animation_speed(handle: number, speed: number): boolean {
  const state = get_model_state(handle);

  if (state == null) {
    return false;
  }

  state.animation_speed = speed;
  return true;
}

export function rl_model_set_animation_loop(handle: number, should_loop: boolean): boolean {
  const state = get_model_state(handle);

  if (state == null) {
    return false;
  }

  state.animation_loop = should_loop;
  return true;
}

export function rl_model_animate(handle: number, delta_seconds: number): boolean {
  const state = get_model_state(handle);

  if (state == null || state.animation_index < 0) {
    return false;
  }

  const next_frame = state.animation_frame + (delta_seconds * 60.0 * state.animation_speed);
  if (state.animation_loop) {
    state.animation_frame = Math.floor(next_frame) % 60;
  } else {
    state.animation_frame = Math.floor(next_frame);
  }
  return true;
}

export async function rl_model_destroy(handle: number): Promise<void> {
  if (!rl_model_is_valid(handle)) {
    return;
  }

  rl_model_states.delete(handle);
  await rl_model_resource_manager.destroyResource(handle);
}
