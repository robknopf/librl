import type { ResourceManager } from "./resource_manager";
import {
  rl_sound_create,
  rl_sound_destroy,
  rl_sound_play,
  set_resource_manager as set_sound_resource_manager,
} from "./rl/rl_sound";

export class Sound {
  handle: number | null = null;
  private dirty = false;

  constructor(
    public readonly path: string,
    private readonly resourceManager: ResourceManager,
  ) {}

  static async load(resourceManager: ResourceManager, path: string): Promise<Sound> {
    const sound = new Sound(path, resourceManager);
    set_sound_resource_manager(resourceManager);
    sound.handle = await rl_sound_create(path);
    return sound;
  }

  play(): void {
    if (this.handle == null) {
      return;
    }

    this.dirty = true;
  }

  sync(): boolean {
    if (this.handle == null || !this.dirty) {
      return false;
    }

    const ok = rl_sound_play(this.handle);
    if (ok) {
      this.dirty = false;
    }

    return ok;
  }

  async destroy(): Promise<void> {
    if (this.handle == null) {
      return;
    }

    set_sound_resource_manager(this.resourceManager);
    await rl_sound_destroy(this.handle);
    this.handle = 0;
    this.dirty = false;
  }
}
