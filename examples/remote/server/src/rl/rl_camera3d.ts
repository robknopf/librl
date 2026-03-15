import { ResourceRequestType } from "../resource_protocol";
import { SharedResourceManager } from "../resource_manager";
import { CommandType } from "../types";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

interface rl_camera3d_state_t {
  position_x: number;
  position_y: number;
  position_z: number;
  target_x: number;
  target_y: number;
  target_z: number;
  up_x: number;
  up_y: number;
  up_z: number;
  fovy: number;
  projection: number;
}

const rl_camera3d_states = new Map<number, rl_camera3d_state_t>();
let rl_camera3d_active = 0;

export const RL_CAMERA3D_DEFAULT = 0;

export async function rl_camera3d_create(
  position_x: number,
  position_y: number,
  position_z: number,
  target_x: number,
  target_y: number,
  target_z: number,
  up_x: number,
  up_y: number,
  up_z: number,
  fovy: number,
  projection: number,
): Promise<number> {
  const handle = await SharedResourceManager.createResource({
    type: ResourceRequestType.CREATE_CAMERA3D,
    posX: position_x,
    posY: position_y,
    posZ: position_z,
    targetX: target_x,
    targetY: target_y,
    targetZ: target_z,
    upX: up_x,
    upY: up_y,
    upZ: up_z,
    fovy,
    projection,
  });

  rl_camera3d_states.set(handle, {
    position_x,
    position_y,
    position_z,
    target_x,
    target_y,
    target_z,
    up_x,
    up_y,
    up_z,
    fovy,
    projection,
  });
  return handle;
}

export function rl_camera3d_get_default(): number {
  return RL_CAMERA3D_DEFAULT;
}

export function rl_camera3d_set(
  handle: number,
  position_x: number,
  position_y: number,
  position_z: number,
  target_x: number,
  target_y: number,
  target_z: number,
  up_x: number,
  up_y: number,
  up_z: number,
  fovy: number,
  projection: number,
): boolean {
  const state = rl_camera3d_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();
  if (state == null) {
    return false;
  }

  state.position_x = position_x;
  state.position_y = position_y;
  state.position_z = position_z;
  state.target_x = target_x;
  state.target_y = target_y;
  state.target_z = target_z;
  state.up_x = up_x;
  state.up_y = up_y;
  state.up_z = up_z;
  state.fovy = fovy;
  state.projection = projection;
  if (frame_command_buffer != null) {
    rl_frame_commands_append(frame_command_buffer, {
      type: CommandType.SET_CAMERA3D,
      camera: handle,
      positionX: state.position_x,
      positionY: state.position_y,
      positionZ: state.position_z,
      targetX: state.target_x,
      targetY: state.target_y,
      targetZ: state.target_z,
      upX: state.up_x,
      upY: state.up_y,
      upZ: state.up_z,
      fovy: state.fovy,
      projection: state.projection,
    });
  }
  return true;
}

export function rl_camera3d_set_active(handle: number): boolean {
  if (!rl_camera3d_states.has(handle) && handle !== RL_CAMERA3D_DEFAULT) {
    return false;
  }

  rl_camera3d_active = handle;
  return true;
}

export function rl_camera3d_get_active(): number {
  return rl_camera3d_active;
}

export async function rl_camera3d_destroy(handle: number): Promise<void> {
  if (!rl_camera3d_states.has(handle)) {
    return;
  }

  rl_camera3d_states.delete(handle);
  if (rl_camera3d_active === handle) {
    rl_camera3d_active = RL_CAMERA3D_DEFAULT;
  }
  await SharedResourceManager.destroyResource(handle);
}
