import { CommandType } from "../types";
import { ResourceRequestType } from "../resource_protocol";
import type { ResourceManager } from "../resource_manager";
import { WorldResources } from "../world_resource_manager";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

interface rl_music_state_t {
  loop: boolean;
  volume: number;
  playing: boolean;
}

const rl_music_states = new Map<number, rl_music_state_t>();
let rl_music_resource_manager: ResourceManager = WorldResources;

export function set_resource_manager(resourceManager: ResourceManager): void {
  rl_music_resource_manager = resourceManager;
}

export async function rl_music_create(filename: string): Promise<number> {
  const handle = await rl_music_resource_manager.createResource({
    type: ResourceRequestType.CREATE_MUSIC,
    filename,
  });
  rl_music_states.set(handle, {
    loop: false,
    volume: 1.0,
    playing: false,
  });
  return handle;
}

export async function rl_music_destroy(handle: number): Promise<void> {
  if (!rl_music_states.has(handle)) {
    return;
  }

  rl_music_states.delete(handle);
  await rl_music_resource_manager.destroyResource(handle);
}

export function rl_music_play(handle: number): boolean {
  const state = rl_music_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();

  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.playing = true;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.PLAY_MUSIC,
    music: handle,
  });
  return true;
}

export function rl_music_pause(handle: number): boolean {
  const state = rl_music_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();

  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.playing = false;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.PAUSE_MUSIC,
    music: handle,
  });
  return true;
}

export function rl_music_stop(handle: number): boolean {
  const state = rl_music_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();

  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.playing = false;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.STOP_MUSIC,
    music: handle,
  });
  return true;
}

export function rl_music_set_loop(handle: number, loop: boolean): boolean {
  const state = rl_music_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();

  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.loop = loop;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.SET_MUSIC_LOOP,
    music: handle,
    loop,
  });
  return true;
}

export function rl_music_set_volume(handle: number, volume: number): boolean {
  const state = rl_music_states.get(handle);
  const frame_command_buffer = get_frame_command_buffer();

  if (state == null || frame_command_buffer == null) {
    return false;
  }

  state.volume = volume;
  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.SET_MUSIC_VOLUME,
    music: handle,
    volume,
  });
  return true;
}

export function rl_music_is_playing(handle: number): boolean {
  return rl_music_states.get(handle)?.playing ?? false;
}
