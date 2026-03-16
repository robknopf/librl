import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

interface rl_sound_state_t {
  volume: number;
  pitch: number;
  pan: number;
  playing: boolean;
}

const rl_sound_states = new Map<number, rl_sound_state_t>();
let rl_sound_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_sound_resource_manager = resourceManager;
}

export async function rl_sound_create(filename: string): Promise<number> {
  const handle = await rl_sound_resource_manager.createResource({
    type: ResourceRequestType.CREATE_SOUND,
    filename,
  });
  rl_sound_states.set(handle, {
    volume: 1.0,
    pitch: 1.0,
    pan: 0.5,
    playing: false,
  });
  return handle;
}

export async function rl_sound_destroy(handle: number): Promise<void> {
  if (!rl_sound_states.has(handle)) {
    return;
  }

  rl_sound_states.delete(handle);
  await rl_sound_resource_manager.destroyResource(handle);
}

export function rl_sound_play(handle: number): boolean {
  const state = rl_sound_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();
  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.playing = true;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.PLAY_SOUND,
    sound: handle,
    volume: state.volume,
    pitch: state.pitch,
    pan: state.pan,
  });
  return true;
}

export function rl_sound_pause(handle: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.playing = false;
  return true;
}

export function rl_sound_resume(handle: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.playing = true;
  return true;
}

export function rl_sound_stop(handle: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.playing = false;
  return true;
}

export function rl_sound_set_volume(handle: number, volume: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.volume = volume;
  return true;
}

export function rl_sound_set_pitch(handle: number, pitch: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.pitch = pitch;
  return true;
}

export function rl_sound_set_pan(handle: number, pan: number): boolean {
  const state = rl_sound_states.get(handle);
  if (state == null) {
    return false;
  }
  state.pan = pan;
  return true;
}

export function rl_sound_is_playing(handle: number): boolean {
  return rl_sound_states.get(handle)?.playing ?? false;
}
