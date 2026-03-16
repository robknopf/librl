import type { ResourceManager } from "./resource_manager";
import {
  rl_music_create,
  rl_music_destroy,
  rl_music_pause,
  rl_music_play,
  rl_music_set_loop,
  rl_music_set_volume,
  rl_music_stop,
  set_resource_manager as set_music_resource_manager,
} from "./rl/rl_music";

type MusicAction = "none" | "play" | "pause" | "stop";

export class Music {
  handle: number | null = null;
  private _loop = false;
  private _volume = 1.0;
  private settingsDirty = false;
  private pendingAction: MusicAction = "none";

  constructor(
    public readonly path: string,
    private readonly resourceManager: ResourceManager,
  ) {}

  static async load(resourceManager: ResourceManager, path: string): Promise<Music> {
    const music = new Music(path, resourceManager);
    set_music_resource_manager(resourceManager);
    music.handle = await rl_music_create(path);
    return music;
  }

  play(): void {
    if (this.handle == null) {
      return;
    }
    this.pendingAction = "play";
  }

  pause(): void {
    if (this.handle == null) {
      return;
    }
    this.pendingAction = "pause";
  }

  stop(): void {
    if (this.handle == null) {
      return;
    }
    this.pendingAction = "stop";
  }

  sync(): boolean {
    if (this.handle == null) {
      return false;
    }

    let changed = false;

    if (this.settingsDirty) {
      changed = rl_music_set_loop(this.handle, this._loop) || changed;
      changed = rl_music_set_volume(this.handle, this._volume) || changed;
      this.settingsDirty = false;
    }

    switch (this.pendingAction) {
      case "play":
        changed = rl_music_play(this.handle) || changed;
        break;
      case "pause":
        changed = rl_music_pause(this.handle) || changed;
        break;
      case "stop":
        changed = rl_music_stop(this.handle) || changed;
        break;
      default:
        break;
    }

    this.pendingAction = "none";
    return changed;
  }

  async destroy(): Promise<void> {
    if (this.handle == null) {
      return;
    }

    set_music_resource_manager(this.resourceManager);
    await rl_music_destroy(this.handle);
    this.handle = 0;
    this.pendingAction = "none";
    this.settingsDirty = false;
  }

  get loop(): boolean { return this._loop; }
  set loop(value: boolean) {
    if (this._loop === value) {
      return;
    }
    this._loop = value;
    this.settingsDirty = true;
  }

  get volume(): number { return this._volume; }
  set volume(value: number) {
    if (this._volume === value) {
      return;
    }
    this._volume = value;
    this.settingsDirty = true;
  }
}
